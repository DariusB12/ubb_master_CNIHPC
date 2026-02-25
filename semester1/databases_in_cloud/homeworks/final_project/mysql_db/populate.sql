-- =========================
-- DATA POPULATION
-- =========================

-- =========================
-- SUPPLIERS (5)
-- =========================
INSERT INTO supplier (name, contact_email) VALUES
('Global Supplies Inc.', 'sales@globalsupplies.example'),
('FastParts Ltd.', 'contact@fastparts.example'),
('Quality Goods Co.', 'info@qualitygoods.example'),
('Regional Distributors', 'hello@regional.example'),
('DirectSource', 'orders@directsource.example');


-- =========================
-- WAREHOUSES (6)
-- =========================
INSERT INTO warehouse (name, location) VALUES
('WH-East', 'Bucharest East'),
('WH-West', 'Bucharest West'),
('WH-North', 'Cluj-North'),
('WH-South', 'Craiova-South'),
('WH-Central', 'Timisoara-Central'),
('WH-Overflow', 'Ploiesti');


-- =========================
-- PRODUCTS (50)
-- =========================
CREATE TEMPORARY TABLE seq_50 (n INT PRIMARY KEY);

INSERT INTO seq_50 (n) VALUES
(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),
(11),(12),(13),(14),(15),(16),(17),(18),(19),(20),
(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),
(31),(32),(33),(34),(35),(36),(37),(38),(39),(40),
(41),(42),(43),(44),(45),(46),(47),(48),(49),(50);

INSERT INTO product (sku, name, category)
SELECT
    CONCAT('SKU', LPAD(n, 4, '0')),
    CONCAT('Product ', n),
    CASE (n % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Hardware'
        WHEN 2 THEN 'Apparel'
        WHEN 3 THEN 'Consumables'
        ELSE 'Tools'
    END
FROM seq_50;

DROP TEMPORARY TABLE seq_50;


-- =========================
-- PRODUCT PRICES (BITEMPORAL, INSERT-ONLY)
-- =========================
-- PRODUCT PRICES (BITEMPORAL, INSERT-ONLY, VALID)
DELIMITER $$

CREATE PROCEDURE populate_product_prices()
BEGIN
    DECLARE i INT DEFAULT 1;

    WHILE i <= 50 DO

        -- Base price (2024)
        INSERT INTO product_price (
            product_id, supplier_id, price, currency,
            valid_start, valid_end
        )
        VALUES (
            i,
            (i % 5) + 1,
            ROUND(10 + (i % 20) + RAND() * 5, 2),
            'EUR',
            '2024-01-01',
            '2024-12-31'
        );

        -- New valid-time price (2025+)
        IF (i % 7 = 0) THEN
            INSERT INTO product_price (
                product_id, supplier_id, price, currency,
                valid_start, valid_end
            )
            VALUES (
                i,
                (i % 5) + 1,
                ROUND(12 + (i % 15) + RAND() * 3, 2),
                'EUR',
                '2025-01-01',
                '2026-12-31'
            );
        END IF;

        -- Transaction-time correction (new version)
        IF (i % 10 = 0) THEN
            INSERT INTO product_price (
                product_id, supplier_id, price, currency,
                valid_start, valid_end,
                transaction_start, transaction_end
            )
            VALUES (
                i,
                (i % 5) + 1,
                100,
                'EUR',
                '2024-01-01',
                '2024-12-31',
                NOW(),
                '9999-12-31 23:59:59'
            );
        END IF;

        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;


CALL populate_product_prices();
DROP PROCEDURE populate_product_prices;


-- =========================
-- INVENTORY MOVEMENTS (BITEMPORAL, INSERT-ONLY)
-- =========================
DELIMITER $$

CREATE PROCEDURE populate_inventory_movements()
BEGIN
    DECLARE gs INT DEFAULT 1;

    -- 40 receipts
    WHILE gs <= 40 DO
        INSERT INTO inventory_movement (
            product_id, warehouse_id, quantity,
            movement_type, valid_start, valid_end
        )
        VALUES (
            (gs % 50) + 1,
            (gs % 6) + 1,
            (gs % 20) + 5,
            'receipt',
            '2025-09-01',
            '2025-09-02'
        );
        SET gs = gs + 1;
    END WHILE;

    -- 10 shipments
    SET gs = 41;
    WHILE gs <= 50 DO
        INSERT INTO inventory_movement (
            product_id, warehouse_id, quantity,
            movement_type, valid_start, valid_end
        )
        VALUES (
            (gs % 50) + 1,
            (gs % 6) + 1,
            -((gs % 10) + 1),
            'shipment',
            '2025-10-05',
            '2025-10-06'
        );
        SET gs = gs + 1;
    END WHILE;

    -- 5 spring receipts
    SET gs = 51;
    WHILE gs <= 55 DO
        INSERT INTO inventory_movement (
            product_id, warehouse_id, quantity,
            movement_type, valid_start, valid_end
        )
        VALUES (
            (gs % 50) + 1,
            (gs % 6) + 1,
            (gs % 30) + 1,
            'receipt',
            '2025-02-10',
            '2025-02-11'
        );
        SET gs = gs + 1;
    END WHILE;

    -- Quantity correction (new transaction version)
    INSERT INTO inventory_movement (
        product_id, warehouse_id, quantity,
        movement_type, valid_start, valid_end
    )
    SELECT
        product_id,
        warehouse_id,
        100,
        movement_type,
        valid_start,
        valid_end
    FROM inventory_movement
    LIMIT 1;

    -- Late data entry (valid < transaction)
    INSERT INTO inventory_movement (
        im_id, product_id, warehouse_id, quantity,
        movement_type, valid_start, valid_end,
        transaction_start, transaction_end
    )
    VALUES (
        UUID(),
        10,
        2,
        50,
        'receipt',
        '2024-03-01',
        '2024-03-02',
        '2024-12-20',
        '9999-12-31 23:59:59'
    );

    -- Movement type correction
    INSERT INTO inventory_movement (
        product_id, warehouse_id, quantity,
        movement_type, valid_start, valid_end
    )
    SELECT
        product_id,
        warehouse_id,
        quantity,
        'adjustment',
        valid_start,
        valid_end
    FROM inventory_movement
    LIMIT 1 OFFSET 2;

END$$

DELIMITER ;

CALL populate_inventory_movements();
DROP PROCEDURE populate_inventory_movements;
