-- Count check (informational)
-- SELECT count(*) FROM inventory_movement;

-- VIEWS & QUERIES
-- Current valid product prices (as of now, by valid time and latest transaction)
CREATE OR REPLACE VIEW current_valid_product_prices AS
SELECT *
FROM product_price
WHERE valid_start <= NOW()
  AND valid_end > NOW()
  AND transaction_end = '9999-12-31 23:59:59';


-- History of price changes for a product (by transaction time)
CREATE OR REPLACE VIEW product_price_history AS
SELECT
    pp_id,
    product_id,
    supplier_id,
    price,
    currency,
    valid_start,
    valid_end,
    transaction_start,
    transaction_end
FROM product_price
ORDER BY product_id, transaction_start;


-- Identify conflicts between transaction time and valid time (late entry/back-dated transaction_start > valid_end)
CREATE OR REPLACE VIEW temporal_conflicts AS
SELECT
    'price' AS obj_type,
    pp_id AS obj_id,
    product_id,
    supplier_id AS party_id,
    valid_start,
    valid_end,
    transaction_start,
    transaction_end
FROM product_price
WHERE transaction_start > valid_end

UNION ALL

SELECT
    'movement' AS obj_type,
    im_id AS obj_id,
    product_id,
    warehouse_id AS party_id,
    valid_start,
    valid_end,
    transaction_start,
    transaction_end
FROM inventory_movement
WHERE transaction_start > valid_end;


-- Show all inventory movements that were valid during a specific period (date range overlap)
DELIMITER $$

CREATE PROCEDURE movements_valid_during(
    IN p_start TIMESTAMP,
    IN p_end TIMESTAMP
)
BEGIN
    SELECT
        im_id,
        product_id,
        warehouse_id,
        quantity,
        movement_type,
        valid_start,
        valid_end,
        transaction_start,
        transaction_end
    FROM inventory_movement
    WHERE valid_start < p_end
      AND valid_end > p_start;
END$$

DELIMITER ;
-- Example call:
CALL movements_valid_during('2025-08-01', '2025-09-05');


-- Records as they were known at a specific transaction time (system-time travel)
DELIMITER $$

CREATE PROCEDURE records_known_at(IN p_t TIMESTAMP)
BEGIN
    -- product_price
    SELECT
        'product_price' AS tbl,
        pp_id AS id,
        product_id,
        supplier_id AS party_id,
        CAST(price AS CHAR) AS amount,
        valid_start,
        valid_end,
        transaction_start,
        transaction_end
    FROM product_price
    WHERE transaction_start <= p_t
      AND transaction_end > p_t;

    -- inventory_movement
    SELECT
        'inventory_movement' AS tbl,
        im_id AS id,
        product_id,
        warehouse_id AS party_id,
        CAST(quantity AS CHAR) AS amount,
        valid_start,
        valid_end,
        transaction_start,
        transaction_end
    FROM inventory_movement
    WHERE transaction_start <= p_t
      AND transaction_end > p_t;
END$$

DELIMITER ;

CALL records_known_at('2025-11-05 00:00:00');
