-- psql -U postgres -h localhost -p 5432
-- \c your_database_name;
-- \i ./bitemporal_schema.sql
-- DROP DATABASE temporal_extensions;
-- CREATE DATABASE temporal_extensions;
-----------------VIEWS-------------------
-- SELECT * FROM current_valid_product_prices;
-- SELECT * FROM product_price_history_v;
-- SELECT * FROM temporal_conflicts;
-- SELECT * FROM movements_valid_during('2025-08-01'::timestamp,'2025-09-05'::timestamp);
-- SSELECT * FROM records_known_at('2025-11-05'::timestamptz);


-- for globally unique primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- TEMPORAL TABLES EXTENSION for system time management
CREATE EXTENSION IF NOT EXISTS temporal_tables;


-- SERIAL PRIMARY KEY -> creates a sequence and the column value will be the next value from that sequence 
-- Advantages: quicker inserts
-- Disadvantage: not globally unique across tables, unique only within the db context
CREATE TABLE supplier (
supplier_id SERIAL PRIMARY KEY,
name TEXT NOT NULL UNIQUE,
contact_email TEXT
);

CREATE TABLE warehouse (
warehouse_id SERIAL PRIMARY KEY,
name TEXT NOT NULL UNIQUE,
location TEXT
);

CREATE TABLE product (
product_id SERIAL PRIMARY KEY,
--Stock Keeping Unit - unique code for each product, identifies it across systems
sku TEXT NOT NULL UNIQUE,
name TEXT NOT NULL,
category TEXT
);

-- UUID DEFAULT uuid_generate_v4() PRIMARY KEY -> globally unique across tables and dbs
-- Advantages: unique across dbs, better for distributed systems
-- Disadvantages: slightly slower inserts due to UUID generation (128 bits)
CREATE TABLE product_price (
pp_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
product_id INT NOT NULL REFERENCES product(product_id),
supplier_id INT REFERENCES supplier(supplier_id),
price NUMERIC(10,2) NOT NULL,
currency CHAR(3) NOT NULL DEFAULT 'USD',
-- VALID TIME
valid_start TIMESTAMP NOT NULL,
valid_end TIMESTAMP NOT NULL,
-- TRANSACTION TIME - extension will manage this automatically
sys_period tstzrange NOT NULL,
CHECK (valid_start < valid_end)
);

-- THE HISTORY TABLE
CREATE TABLE product_price_history (LIKE product_price);

-- TRIGGER FOR SYSTEM TIME MANAGEMENT
CREATE TRIGGER product_price_versioning_trigger
BEFORE INSERT OR UPDATE OR DELETE ON product_price
FOR EACH ROW EXECUTE PROCEDURE versioning('sys_period',
                                          'product_price_history',
                                          true);


CREATE TABLE inventory_movement (
im_id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
product_id INT NOT NULL REFERENCES product(product_id),
warehouse_id INT NOT NULL REFERENCES warehouse(warehouse_id),
quantity INTEGER NOT NULL, -- positive for in, negative for out
-- receipt: Incoming stock — product received from supplier
-- shipment: Outgoing stock — product sent to customer
-- transfer_in: Stock received from another warehouse
-- transfer_out: Stock sent to another warehouse
-- adjustment: Manual stock correction (e.g found missing item etc.) (positive or negative - quantity adjusted)
movement_type TEXT NOT NULL CHECK (movement_type IN ('receipt','shipment','transfer_in','transfer_out','adjustment')),
-- VALID TIME: when the movement is considered to have occurred in reality
valid_start TIMESTAMP NOT NULL,
valid_end TIMESTAMP NOT NULL,
-- TRANSACTION TIME - extension will manage this automatically
sys_period tstzrange NOT NULL,
CHECK (valid_start < valid_end)
);

-- THE HISTORY TABLE
CREATE TABLE inventory_movement_history (LIKE inventory_movement);

-- TRIGGER FOR SYSTEM TIME MANAGEMENT
CREATE TRIGGER inventory_movement_versioning_trigger
BEFORE INSERT OR UPDATE OR DELETE ON inventory_movement
FOR EACH ROW EXECUTE PROCEDURE versioning('sys_period',
                                          'inventory_movement_history',
                                          true);