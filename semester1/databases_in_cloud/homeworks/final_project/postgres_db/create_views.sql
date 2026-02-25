-- Count check (informational)
-- SELECT count(*) FROM inventory_movement;

-- VIEWS & QUERIES
-- Current valid product prices (as of now, by valid time and latest transaction)
CREATE OR REPLACE VIEW current_valid_product_prices AS
SELECT *
FROM product_price
WHERE valid_start <= now() AND valid_end > now() AND transaction_end = 'infinity'::timestamp;


-- History of price changes for a product (by transaction time)
CREATE OR REPLACE VIEW product_price_history AS
SELECT pp_id, product_id, supplier_id, price, currency, valid_start, valid_end, transaction_start, transaction_end
FROM product_price
ORDER BY product_id, transaction_start;


-- Identify conflicts between transaction time and valid time (late entry/back-dated transaction_start > valid_end)
CREATE OR REPLACE VIEW temporal_conflicts AS
SELECT 'price' AS obj_type, pp_id::text AS obj_id, product_id, supplier_id AS party_id, valid_start, valid_end, transaction_start, transaction_end
FROM product_price
WHERE transaction_start > valid_end
UNION ALL
SELECT 'movement' AS obj_type, im_id::text AS obj_id, product_id, warehouse_id AS party_id, valid_start, valid_end, transaction_start, transaction_end
FROM inventory_movement
WHERE transaction_start > valid_end;


-- Show all inventory movements that were valid during a specific period (date range overlap)
CREATE OR REPLACE FUNCTION movements_valid_during(p_start TIMESTAMP, p_end TIMESTAMP)
RETURNS TABLE(im_id_view UUID, product_id_view INT, warehouse_id_view INT, quantity_view INT, movement_type_view TEXT, valid_start_view TIMESTAMP, valid_end_view TIMESTAMP, transaction_start_view TIMESTAMP, transaction_end_view TIMESTAMP) AS $$
BEGIN
RETURN QUERY
SELECT im_id, product_id, warehouse_id, quantity, movement_type, valid_start, valid_end, transaction_start, transaction_end
FROM inventory_movement
WHERE valid_start < p_end AND valid_end > p_start; -- overlap
END; $$ LANGUAGE plpgsql;


-- Records as they were known at a specific transaction time (system-time travel)
CREATE OR REPLACE FUNCTION records_known_at(p_t TIMESTAMP)
RETURNS TABLE(tbl TEXT, id TEXT, product_id_view INT, party_id INT, amount TEXT, valid_start_view TIMESTAMP, valid_end_view TIMESTAMP, transaction_start_view TIMESTAMP, transaction_end_view TIMESTAMP) AS $$
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