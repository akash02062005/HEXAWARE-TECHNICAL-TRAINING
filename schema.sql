-- =====================================================================
-- Set 1 : Retail Inventory Management
-- File  : schema.sql
-- Desc  : 3NF schema (InnoDB) with PK, FK, UNIQUE, CHECK, DEFAULT and
--         referential actions ON DELETE RESTRICT / ON UPDATE CASCADE
-- Target: MySQL 8.0.16+ (CHECK constraints are enforced from 8.0.16)
-- =====================================================================

DROP DATABASE IF EXISTS retail_inventory;
CREATE DATABASE retail_inventory
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE retail_inventory;

-- ---------------------------------------------------------------------
-- 1. category  : one row per product category
-- ---------------------------------------------------------------------
CREATE TABLE category (
    category_id    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    category_name  VARCHAR(50)   NOT NULL,
    description    VARCHAR(255)  NULL,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_category       PRIMARY KEY (category_id),
    CONSTRAINT uq_category_name  UNIQUE (category_name)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 2. supplier  : supplier name & phone stored ONCE (removes update anomaly)
-- ---------------------------------------------------------------------
CREATE TABLE supplier (
    supplier_id    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    supplier_name  VARCHAR(100)  NOT NULL,
    phone          VARCHAR(20)   NOT NULL,
    email          VARCHAR(100)  NULL,
    city           VARCHAR(50)   NOT NULL DEFAULT 'Bengaluru',
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_supplier        PRIMARY KEY (supplier_id),
    CONSTRAINT uq_supplier_name   UNIQUE (supplier_name),
    CONSTRAINT uq_supplier_phone  UNIQUE (phone),
    CONSTRAINT chk_supplier_phone CHECK (phone REGEXP '^[+0-9 -]{8,20}$')
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 3. warehouse : physical storage locations
-- ---------------------------------------------------------------------
CREATE TABLE warehouse (
    warehouse_id    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    warehouse_code  CHAR(6)       NOT NULL,
    warehouse_name  VARCHAR(80)   NOT NULL,
    city            VARCHAR(50)   NOT NULL,
    capacity_units  INT UNSIGNED  NOT NULL DEFAULT 10000,
    CONSTRAINT pk_warehouse       PRIMARY KEY (warehouse_id),
    CONSTRAINT uq_warehouse_code  UNIQUE (warehouse_code),
    CONSTRAINT chk_wh_capacity    CHECK (capacity_units > 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 4. product   : SKU master; depends on category and supplier
-- ---------------------------------------------------------------------
CREATE TABLE product (
    sku            VARCHAR(12)    NOT NULL,
    product_name   VARCHAR(120)   NOT NULL,
    category_id    INT UNSIGNED   NOT NULL,
    supplier_id    INT UNSIGNED   NOT NULL,
    unit_price     DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    status         ENUM('ACTIVE','DISCONTINUED') NOT NULL DEFAULT 'ACTIVE',
    created_at     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product          PRIMARY KEY (sku),
    CONSTRAINT uq_product_name     UNIQUE (product_name),
    CONSTRAINT chk_product_price   CHECK (unit_price >= 0),
    CONSTRAINT fk_product_category FOREIGN KEY (category_id)
        REFERENCES category (category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_product_supplier FOREIGN KEY (supplier_id)
        REFERENCES supplier (supplier_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 5. stock     : quantity of a SKU held in a warehouse (M:N resolver)
-- ---------------------------------------------------------------------
CREATE TABLE stock (
    warehouse_id   INT UNSIGNED  NOT NULL,
    sku            VARCHAR(12)   NOT NULL,
    quantity       INT           NOT NULL DEFAULT 0,
    reorder_level  INT           NOT NULL DEFAULT 10,
    last_updated   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_stock              PRIMARY KEY (warehouse_id, sku),
    CONSTRAINT chk_stock_quantity    CHECK (quantity >= 0),
    CONSTRAINT chk_stock_reorder     CHECK (reorder_level >= 0),
    CONSTRAINT fk_stock_warehouse    FOREIGN KEY (warehouse_id)
        REFERENCES warehouse (warehouse_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_stock_product      FOREIGN KEY (sku)
        REFERENCES product (sku)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE INDEX idx_stock_sku ON stock (sku);

-- Helper view: items at or below their reorder level
CREATE OR REPLACE VIEW v_reorder_alert AS
SELECT s.sku, p.product_name, w.warehouse_code,
       s.quantity, s.reorder_level, sp.supplier_name, sp.phone
FROM   stock s
JOIN   product   p  ON p.sku = s.sku
JOIN   warehouse w  ON w.warehouse_id = s.warehouse_id
JOIN   supplier  sp ON sp.supplier_id = p.supplier_id
WHERE  s.quantity <= s.reorder_level;
