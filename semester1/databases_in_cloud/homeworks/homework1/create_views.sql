-- Count check (informational)
-- SELECT count(*) FROM inventory_movement; -- should be ~56+ versions


-- =========================
-- VIEWS & QUERIES (Temporal Requirements)
-- 1) Current valid stock for a given product at a warehouse
-- "Current valid" = rows with valid period containing NOW() and are the current transaction version
CREATE OR REPLACE VIEW current_valid_stock AS
SELECT product_id, warehouse_id, SUM(quantity) AS qty
FROM inventory_movement
WHERE valid_start <= now() AND valid_end > now() AND transaction_end = 'infinity'::timestamp
GROUP BY product_id, warehouse_id;


-- 2) History of price changes for a product (by transaction time)
CREATE OR REPLACE VIEW product_price_history AS
SELECT pp_id, product_id, supplier_id, price, currency, valid_start, valid_end, transaction_start, transaction_end
FROM product_price
ORDER BY product_id, transaction_start;


-- 3) Identify conflicts between transaction time and valid time (late entry or back-dated transaction_start > valid_end)
CREATE OR REPLACE VIEW temporal_conflicts AS
SELECT 'price' AS obj_type, pp_id::text AS obj_id, product_id, supplier_id AS party_id, valid_start, valid_end, transaction_start, transaction_end
FROM product_price
WHERE transaction_start > valid_end
UNION ALL
SELECT 'movement' AS obj_type, im_id::text AS obj_id, product_id, warehouse_id AS party_id, valid_start, valid_end, transaction_start, transaction_end
FROM inventory_movement
WHERE transaction_start > valid_end;


-- 4) Show all inventory movements that were valid during a specific period (date range overlap)
CREATE OR REPLACE FUNCTION movements_valid_during(p_start TIMESTAMP, p_end TIMESTAMP)
RETURNS TABLE(im_id UUID, product_id INT, warehouse_id INT, quantity INT, movement_type TEXT, valid_start TIMESTAMP, valid_end TIMESTAMP, transaction_start TIMESTAMP, transaction_end TIMESTAMP) AS $$
BEGIN
RETURN QUERY
SELECT im_id, product_id, warehouse_id, quantity, movement_type, valid_start, valid_end, transaction_start, transaction_end
FROM inventory_movement
WHERE valid_start < p_end AND valid_end > p_start; -- overlap
END; $$ LANGUAGE plpgsql;


-- 5) Records as they were known at a specific transaction time (system-time travel)
CREATE OR REPLACE FUNCTION records_known_at(p_t TIMESTAMP)
RETURNS TABLE(tbl TEXT, id TEXT, product_id INT, party_id INT, amount TEXT, valid_start TIMESTAMP, valid_end TIMESTAMP, transaction_start TIMESTAMP, transaction_end TIMESTAMP) AS $$
BEGIN
RETURN QUERY
SELECT 'product_price'::text, pp_id::text, product_id, supplier_id, price::text, valid_start, valid_end, transaction_start, transaction_end
FROM product_price
WHERE transaction_start <= p_t AND transaction_end > p_t;


RETURN QUERY
SELECT 'inventory_movement'::text, im_id::text, product_id, warehouse_id, quantity::text, valid_start, valid_end, transaction_start, transaction_end
FROM inventory_movement
WHERE transaction_start <= p_t AND transaction_end > p_t;
END; $$ LANGUAGE plpgsql;