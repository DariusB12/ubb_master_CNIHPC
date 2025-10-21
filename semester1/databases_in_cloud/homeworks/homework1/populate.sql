-- =========================
-- DATA POPULATION
-- 50 products, 5 suppliers, 6 warehouses, ~60 inventory movement records with some updates to create versions
-- =========================


-- Suppliers (5)
INSERT INTO supplier (name, contact_email) VALUES
('Global Supplies Inc.', 'sales@globalsupplies.example'),
('FastParts Ltd.', 'contact@fastparts.example'),
('Quality Goods Co.', 'info@qualitygoods.example'),
('Regional Distributors', 'hello@regional.example'),
('DirectSource', 'orders@directsource.example');


-- Warehouses (6)
INSERT INTO warehouse (name, location) VALUES
('WH-East', 'Bucharest East'),
('WH-West', 'Bucharest West'),
('WH-North', 'Cluj-North'),
('WH-South', 'Craiova-South'),
('WH-Central', 'Timisoara-Central'),
('WH-Overflow', 'Ploiesti');

-- Products (50)
--generate_series (start,stop[,step]) -> generate a series of numbers or timestamps, step by default is 1
INSERT INTO product (sku, name, category)
SELECT 'SKU' || lpad(gs::text,4,'0') AS sku, 'Product ' || gs AS name, (ARRAY['Electronics','Hardware','Apparel','Consumables','Tools'])[ (gs % 5) + 1 ]
FROM generate_series(1,50) gs;


-- Initial product prices for 50 products from different suppliers across time windows
-- Valid ranges: 2024-01-01 to 2024-12-31
-- Transcation time: now() to infinity (by default)
DO $$
DECLARE i INT;
    BEGIN
        FOR i IN 1..50 LOOP
            INSERT INTO product_price (product_id, supplier_id, price, currency, valid_start, valid_end)
            VALUES (i, ((i % 5) + 1), round( (10 + (i % 20))::numeric + random() * 5, 2), 'EUR', '2024-01-01'::timestamp, '2024-12-31'::timestamp);

            -- Reflect realistic changes over time => For some products, create a new price starting 2025-01-01
            -- NEW INSERT (the old price remains, new price is a new row with new valid time)
            IF (i % 7) = 0 THEN
                INSERT INTO product_price (product_id, supplier_id, price, currency, valid_start, valid_end)
                VALUES (i, ((i % 5) + 1), round( (12 + (i % 15))::numeric + random() * 3, 2), 'EUR', '2025-01-01'::timestamp, '2026-12-31'::timestamp);
            END IF;
        END LOOP;
END $$;




-- Inventory movements: create ~60 records across products/warehouses with some updates
-- We'll create receipts for 2024 and shipments, then version some rows to simulate corrections
DO $$
DECLARE gs INT;
    BEGIN
        -- Create 40 initial movements (receipts) for 2024
        FOR gs IN 1..40 LOOP
            INSERT INTO inventory_movement (product_id, warehouse_id, quantity, movement_type, valid_start, valid_end)
            VALUES ((gs % 50) + 1, ((gs % 6) + 1), ((gs % 20) + 5), 'receipt', '2024-09-01'::timestamp, '2024-09-02'::timestamp);
        END LOOP;

        -- Create 10 shipments for Fall 2024
        FOR gs IN 41..50 LOOP
            INSERT INTO inventory_movement (product_id, warehouse_id, quantity, movement_type, valid_start, valid_end)
            VALUES ((gs % 50) + 1, ((gs % 6) + 1), -((gs % 10) + 1), 'shipment', '2024-10-05'::timestamp, '2024-10-05'::timestamp);
        END LOOP;


        -- Create 5 movements for Spring 2025
        FOR gs IN 51..55 LOOP
            INSERT INTO inventory_movement (product_id, warehouse_id, quantity, movement_type, valid_start, valid_end)
            VALUES ((gs % 50) + 1, ((gs % 6) + 1), ((gs % 30) + 1), 'receipt',  '2025-02-10'::timestamp, '2025-02-11'::timestamp);
        END LOOP;


        -- Reflect realistic changes over time 
        -- Manual correction: update one movement (will create a new transaction version)
        UPDATE inventory_movement SET quantity = 100 WHERE im_id IN (SELECT im_id FROM inventory_movement LIMIT 1);

        -- Identifying conflicts between transaction time and valid time:
        -- Late data-entry: insert a movement with transaction_start backdated before its valid date
        -- simulate a real life scenario where data is entered late into the system than the actual (real) event date
        INSERT INTO inventory_movement (im_id, product_id, warehouse_id, quantity, movement_type, valid_start, valid_end, transaction_start, transaction_end)
        VALUES (uuid_generate_v4(), 10, 2, 50, 'receipt', '2024-03-01'::timestamp, '2024-03-02'::timestamp, '2024-12-20'::timestamp, 'infinity'::timestamp);

        -- Reflect realistic changes over time
        -- Further corrections causing versions
        UPDATE inventory_movement SET movement_type = 'adjustment' WHERE im_id IN (SELECT im_id FROM inventory_movement OFFSET 2 LIMIT 1);

END$$;