-- Count check (informational)
-- SELECT count(*) FROM inventory_movement;

-- VIEWS & QUERIES
-- Current valid product prices (as of now, by valid time and latest transaction)
CREATE OR REPLACE VIEW current_valid_product_prices AS
SELECT *
FROM product_price
WHERE valid_start <= now() AND valid_end > now();


-- History of price changes for a product (by transaction time)
CREATE OR REPLACE VIEW product_price_history_v AS
SELECT *
FROM product_price_history
ORDER BY product_id, lower(sys_period);


-- Identify conflicts between transaction time and valid time (late entry/back-dated transaction_start > valid_end)
CREATE OR REPLACE VIEW temporal_conflicts AS
SELECT 'price' AS obj_type, pp_id::text AS obj_id, product_id, supplier_id AS party_id, valid_start, valid_end, sys_period
FROM product_price
WHERE lower(sys_period) > valid_end
UNION ALL
SELECT 'movement' AS obj_type, im_id::text AS obj_id, product_id, warehouse_id AS party_id, valid_start, valid_end, sys_period
FROM inventory_movement
WHERE lower(sys_period) > valid_end;


-- Show all inventory movements that were valid during a specific period (date range overlap)
CREATE OR REPLACE FUNCTION movements_valid_during(p_start TIMESTAMP, p_end TIMESTAMP)
RETURNS TABLE(im_id_view UUID, product_id_view INT, warehouse_id_view INT, quantity_view INT, movement_type_view TEXT, valid_start_view TIMESTAMP, valid_end_view TIMESTAMP, sys_period_view tstzrange) AS $$
BEGIN
RETURN QUERY
SELECT im_id, product_id, warehouse_id, quantity, movement_type, valid_start, valid_end, sys_period
FROM inventory_movement
WHERE valid_start < p_end AND valid_end > p_start -- overlap
UNION ALL
SELECT im_id, product_id, warehouse_id, quantity, movement_type, valid_start, valid_end, sys_period
FROM inventory_movement_history
WHERE valid_start < p_end AND valid_end > p_start; -- overlap
END; $$ LANGUAGE plpgsql;


-- Records as they were known at a specific transaction time (system-time travel)
CREATE OR REPLACE FUNCTION records_known_at(p_t TIMESTAMPTZ)
RETURNS TABLE(tbl TEXT, id TEXT, product_id_view INT, party_id INT, amount TEXT, valid_start_view TIMESTAMP, valid_end_view TIMESTAMP, sys_period_view tstzrange) AS $$
BEGIN
RETURN QUERY
SELECT 'product_price'::text, pp_id::text, product_id, supplier_id, price::text, valid_start, valid_end, sys_period
FROM product_price
WHERE lower(sys_period) <= p_t;

RETURN QUERY
SELECT 'product_price_history'::text, pp_id::text, product_id, supplier_id, price::text, valid_start, valid_end, sys_period
FROM product_price
WHERE lower(sys_period) <= p_t AND upper(sys_period) > p_t;

RETURN QUERY
SELECT 'inventory_movement'::text, im_id::text, product_id, warehouse_id, quantity::text, valid_start, valid_end, sys_period
FROM inventory_movement
WHERE lower(sys_period) <= p_t;

RETURN QUERY
SELECT 'inventory_movement_history'::text, im_id::text, product_id, warehouse_id, quantity::text, valid_start, valid_end, sys_period
FROM inventory_movement
WHERE lower(sys_period) <= p_t AND upper(sys_period) > p_t;

END; $$ LANGUAGE plpgsql;