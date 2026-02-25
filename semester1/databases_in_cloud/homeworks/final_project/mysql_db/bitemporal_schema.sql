SET sql_mode = 'STRICT_ALL_TABLES';

-- sudo mysql -u root -p
-- SHOW DATABASES; TO SHOW ALL DB
-- SELECT DATABASE(); TO SHOW CURRENT DB
-- USE no_temporal_extensions;
-- source ./bitemporal_schema.sql;
-- DROP DATABASE no_temporal_extensions;
-- CREATE DATABASE no_temporal_extensions;
-- ---------------VIEWS-------------------
-- SELECT * FROM current_valid_product_prices;
-- SELECT * FROM product_price_history;
-- SELECT * FROM temporal_conflicts;
-- CALL movements_valid_during('2025-08-01 00:00:00', '2025-09-05 00:00:00');
-- CALL records_known_at('2025-11-05 00:00:00');

-- show all the triggers:
-- SELECT TRIGGER_NAME, EVENT_MANIPULATION, EVENT_OBJECT_TABLE, ACTION_TIMING 
-- FROM information_schema.TRIGGERS 
-- WHERE TRIGGER_SCHEMA = 'no_temporal_extensions';

-- =========================
-- TABLES
-- =========================

CREATE TABLE supplier (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    contact_email VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE warehouse (
    warehouse_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    location VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE product (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE product_price (
    pp_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    product_id INT NOT NULL,
    supplier_id INT,
    price DECIMAL(10,2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'USD',

    -- VALID TIME
    valid_start DATETIME NOT NULL,
    valid_end DATETIME NOT NULL,

    -- TRANSACTION TIME
    transaction_start DATETIME NOT NULL,
    transaction_end DATETIME NOT NULL,

    CHECK (valid_start < valid_end),

    CONSTRAINT fk_pp_product
        FOREIGN KEY (product_id) REFERENCES product(product_id),
    CONSTRAINT fk_pp_supplier
        FOREIGN KEY (supplier_id) REFERENCES supplier(supplier_id)
) ENGINE=InnoDB;

CREATE TABLE inventory_movement (
    im_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    product_id INT NOT NULL,
    warehouse_id INT NOT NULL,
    quantity INT NOT NULL,

    movement_type ENUM(
        'receipt',
        'shipment',
        'transfer_in',
        'transfer_out',
        'adjustment'
    ) NOT NULL,

    -- VALID TIME
    valid_start DATETIME NOT NULL,
    valid_end DATETIME NOT NULL,

    -- TRANSACTION TIME
    transaction_start DATETIME NOT NULL,
    transaction_end DATETIME NOT NULL,

    CHECK (valid_start < valid_end),

    CONSTRAINT fk_im_product
        FOREIGN KEY (product_id) REFERENCES product(product_id),
    CONSTRAINT fk_im_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouse(warehouse_id)
) ENGINE=InnoDB;



-- PRODUCT_PRICE triggers for trnasaction time management
-- ----------------- TRIGGER FOR INSERT -------------------

DELIMITER $$

CREATE TRIGGER pp_before_insert
BEFORE INSERT ON product_price
FOR EACH ROW
BEGIN
    IF NEW.transaction_start IS NULL THEN
        SET NEW.transaction_start = NOW();
    END IF;

    IF NEW.transaction_end IS NULL THEN
        SET NEW.transaction_end = '9999-12-31 23:59:59';
    END IF;
END$$

DELIMITER ;


-- ----------------- TRIGGER FOR UPDATE -------------------

DELIMITER $$

CREATE TRIGGER pp_versioning
BEFORE UPDATE ON product_price
FOR EACH ROW
BEGIN
    IF NEW.transaction_end IS NULL
       OR NEW.transaction_end = '9999-12-31 23:59:59' THEN

        UPDATE product_price
        SET transaction_end = NOW()
        WHERE pp_id = OLD.pp_id
          AND transaction_end = '9999-12-31 23:59:59';

        INSERT INTO product_price (
            product_id, supplier_id, price, currency,
            valid_start, valid_end,
            transaction_start, transaction_end
        )
        VALUES (
            NEW.product_id, NEW.supplier_id, NEW.price, NEW.currency,
            NEW.valid_start, NEW.valid_end,
            NOW(), '9999-12-31 23:59:59'
        );

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Versioned update handled by trigger';
    END IF;
END$$

DELIMITER ;


-- ------------------- TRIGGER FOR DELETE -------------------
DELIMITER $$

CREATE TRIGGER pp_logical_delete
BEFORE DELETE ON product_price
FOR EACH ROW
BEGIN
    UPDATE product_price
    SET transaction_end = NOW()
    WHERE pp_id = OLD.pp_id
      AND transaction_end = '9999-12-31 23:59:59';

    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Logical delete handled by trigger';
END$$

DELIMITER ;



-- INVENTORY_MOVEMENT triggers for trnasaction time management
-- ----------------- TRIGGER FOR INSERT -------------------

DELIMITER $$

CREATE TRIGGER im_before_insert
BEFORE INSERT ON inventory_movement
FOR EACH ROW
BEGIN
    IF NEW.transaction_start IS NULL THEN
        SET NEW.transaction_start = NOW();
    END IF;

    IF NEW.transaction_end IS NULL THEN
        SET NEW.transaction_end = '9999-12-31 23:59:59';
    END IF;
END$$

DELIMITER ;


-- ----------------- TRIGGER FOR UPDATE -------------------
DELIMITER $$

CREATE TRIGGER im_versioning
BEFORE UPDATE ON inventory_movement
FOR EACH ROW
BEGIN
    IF NEW.transaction_end IS NULL
       OR NEW.transaction_end = '9999-12-31 23:59:59' THEN

        UPDATE inventory_movement
        SET transaction_end = NOW()
        WHERE im_id = OLD.im_id
          AND transaction_end = '9999-12-31 23:59:59';

        INSERT INTO inventory_movement (
            product_id, warehouse_id, quantity, movement_type,
            valid_start, valid_end,
            transaction_start, transaction_end
        )
        VALUES (
            NEW.product_id, NEW.warehouse_id, NEW.quantity, NEW.movement_type,
            NEW.valid_start, NEW.valid_end,
            NOW(), '9999-12-31 23:59:59'
        );

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Versioned update handled by trigger';
    END IF;
END$$

DELIMITER ;



-- ----------------- TRIGGER FOR DELETE -------------------

DELIMITER $$

CREATE TRIGGER im_logical_delete
BEFORE DELETE ON inventory_movement
FOR EACH ROW
BEGIN
    UPDATE inventory_movement
    SET transaction_end = NOW()
    WHERE im_id = OLD.im_id
      AND transaction_end = '9999-12-31 23:59:59';

    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Logical delete handled by trigger';
END$$

DELIMITER ;
