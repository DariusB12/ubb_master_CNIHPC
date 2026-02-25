-- psql -U postgres -h localhost -p 5432
-- \c your_database_name;
-- \i ./bitemporal_schema.sql
-- DROP DATABASE no_temporal_extensions;
-- CREATE DATABASE no_temporal_extensions;
-----------------VIEWS-------------------
-- SELECT * FROM current_valid_product_prices;
-- SELECT * FROM product_price_history;
-- SELECT * FROM temporal_conflicts;
-- SELECT * FROM movements_valid_during('2025-08-01'::timestamp,'2025-09-05'::timestamp);
-- SELECT * FROM records_known_at('2025-11-05'::timestamp);


-- for globally unique primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

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
-- TRANSACTION TIME
transaction_start TIMESTAMP NOT NULL,
transaction_end TIMESTAMP NOT NULL,
CHECK (valid_start < valid_end)
);

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
-- TRANSACTION TIME: when the system recorded the movement
transaction_start TIMESTAMP NOT NULL,
transaction_end TIMESTAMP NOT NULL,
CHECK (valid_start < valid_end)
);

-- PRODUCT_PRICE triggers for trnasaction time management
------------------- TRIGGER FOR INSERT -------------------
CREATE OR REPLACE FUNCTION trg_pp_before_insert()
RETURNS trigger  AS $$ -- RETURNS trigger MARKER for trigger functions
BEGIN
    IF NEW.transaction_start IS NULL THEN NEW.transaction_start := now(); END IF;
    IF NEW.transaction_end IS NULL THEN NEW.transaction_end := 'infinity'::timestamp; END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
-- pl -> procedural language

CREATE TRIGGER pp_before_insert BEFORE INSERT ON product_price FOR EACH ROW EXECUTE FUNCTION trg_pp_before_insert();

------------------- TRIGGER FOR UPDATE -------------------
CREATE OR REPLACE FUNCTION trg_pp_versioning()
RETURNS trigger AS $$
BEGIN
    IF NEW.transaction_end = 'infinity'::timestamp OR NEW.transaction_end IS NULL THEN

        -- close existing row -> set transaction_end to now()
        UPDATE product_price
        SET transaction_end = now()
        WHERE pp_id = OLD.pp_id AND transaction_end = 'infinity'::timestamp;

        -- insert the new version only if the new data doesn;t contain transaction_end time  (for delete we don't need a new version)
        INSERT INTO product_price (
            product_id, supplier_id, price, currency,
            valid_start, valid_end, transaction_start, transaction_end
        )
        VALUES (
            NEW.product_id, NEW.supplier_id, NEW.price, NEW.currency,
            NEW.valid_start, NEW.valid_end, now(), 'infinity'::timestamp
        );
    
        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- RETURN NEW → PostgreSQL will make the normal UPDATE (replace the old row with the new row)
-- RETURN NULL → PostgreSQL won't make the normal update, we handle it ourselves letting the old value remain and inserting a new row instead

CREATE TRIGGER pp_versioning BEFORE UPDATE ON product_price FOR EACH ROW EXECUTE FUNCTION trg_pp_versioning();

-- ------------------- TRIGGER FOR DELETE -------------------
CREATE OR REPLACE FUNCTION trg_pp_delete()
RETURNS trigger AS $$
BEGIN
    UPDATE product_price SET transaction_end = now()
    WHERE pp_id = OLD.pp_id AND transaction_end = 'infinity'::timestamp;
    RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER pp_logical_delete BEFORE DELETE ON product_price FOR EACH ROW EXECUTE FUNCTION trg_pp_delete();








-- INVENTORY_MOVEMENT triggers for trnasaction time management
------------------- TRIGGER FOR INSERT -------------------
CREATE OR REPLACE FUNCTION trg_im_before_insert()
RETURNS trigger AS $$
BEGIN
    IF NEW.transaction_start IS NULL THEN NEW.transaction_start := now(); END IF;
    IF NEW.transaction_end IS NULL THEN NEW.transaction_end := 'infinity'::timestamp; END IF;

    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER im_before_insert BEFORE INSERT ON inventory_movement FOR EACH ROW EXECUTE FUNCTION trg_im_before_insert();


------------------- TRIGGER FOR UPDATE -------------------
CREATE OR REPLACE FUNCTION trg_im_versioning()
RETURNS trigger AS $$
BEGIN
    IF NEW.transaction_end = 'infinity'::timestamp OR NEW.transaction_end IS NULL THEN

        UPDATE inventory_movement SET transaction_end = now()
        WHERE im_id = OLD.im_id AND transaction_end = 'infinity'::timestamp;

        INSERT INTO inventory_movement (product_id, warehouse_id, quantity, movement_type, valid_start, valid_end, transaction_start, transaction_end)
        VALUES (NEW.product_id, NEW.warehouse_id, NEW.quantity, NEW.movement_type, NEW.valid_start, NEW.valid_end, now(), 'infinity'::timestamp);

        RETURN NULL;
    END IF;

    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER im_versioning BEFORE UPDATE ON inventory_movement FOR EACH ROW EXECUTE FUNCTION trg_im_versioning();


------------------- TRIGGER FOR DELETE -------------------
CREATE OR REPLACE FUNCTION trg_im_delete()
RETURNS trigger AS $$
BEGIN
    UPDATE inventory_movement SET transaction_end = now()
    WHERE im_id = OLD.im_id AND transaction_end = 'infinity'::timestamp;
    RETURN NULL;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER im_logical_delete BEFORE DELETE ON inventory_movement FOR EACH ROW EXECUTE FUNCTION trg_im_delete();