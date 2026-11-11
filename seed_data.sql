-- =====================================================================
-- Set 1 : Retail Inventory Management
-- File  : seed_data.sql
-- Desc  : At least 10 valid rows per table (run after schema.sql)
-- =====================================================================

USE retail_inventory;

-- ---------------------------------------------------------------- category
INSERT INTO category (category_name, description) VALUES
('Beverages',        'Tea, coffee, juices and soft drinks'),
('Snacks',           'Chips, biscuits and namkeen'),
('Dairy',            'Milk, curd, butter and cheese'),
('Personal Care',    'Soaps, shampoos and toothpaste'),
('Household',        'Detergents and cleaning supplies'),
('Staples',          'Rice, atta, dal and sugar'),
('Frozen Foods',     'Frozen snacks and ice cream'),
('Stationery',       'Notebooks, pens and office items'),
('Electronics',      'Small electronic accessories'),
('Baby Care',        'Diapers, wipes and baby food');

-- ---------------------------------------------------------------- supplier
INSERT INTO supplier (supplier_name, phone, email, city) VALUES
('Sri Lakshmi Traders',     '+91 98450 11223', 'orders@srilakshmi.in',  'Bengaluru'),
('Annapurna Distributors',  '+91 99001 22334', 'sales@annapurna.in',    'Mysuru'),
('Kaveri Dairy Co-op',      '+91 98860 33445', 'supply@kaveridairy.in', 'Mandya'),
('Prakash FMCG Agencies',   '+91 97400 44556', 'prakash@fmcg.in',       'Bengaluru'),
('Deccan Wholesale',        '+91 96320 55667', 'contact@deccanws.in',   'Hubballi'),
('Nandi Agro Foods',        '+91 95910 66778', 'info@nandiagro.in',     'Chikkaballapur'),
('Coastal Cold Chain',      '+91 94480 77889', 'ops@coastalcold.in',    'Mangaluru'),
('Vidya Stationers',        '+91 93430 88990', 'vidya@stationers.in',   'Bengaluru'),
('TechLink Accessories',    '+91 92410 99001', 'b2b@techlink.in',       'Bengaluru'),
('LittleSteps Baby Supply', '+91 91080 10112', 'trade@littlesteps.in',  'Tumakuru');

-- --------------------------------------------------------------- warehouse
INSERT INTO warehouse (warehouse_code, warehouse_name, city, capacity_units) VALUES
('BLR-01', 'Peenya Central DC',       'Bengaluru',  50000),
('BLR-02', 'Whitefield Hub',          'Bengaluru',  30000),
('BLR-03', 'Electronic City Store',   'Bengaluru',  12000),
('MYS-01', 'Hebbal Industrial DC',    'Mysuru',     25000),
('HBL-01', 'Gokul Road Depot',        'Hubballi',   20000),
('MNG-01', 'Baikampady Cold Store',   'Mangaluru',  15000),
('TMK-01', 'Tumakuru Satellite',      'Tumakuru',    8000),
('BGM-01', 'Belagavi Udyambag DC',    'Belagavi',   18000),
('SMG-01', 'Shivamogga Depot',        'Shivamogga', 10000),
('DVG-01', 'Davanagere Cross Dock',   'Davanagere',  9000);

-- ----------------------------------------------------------------- product
INSERT INTO product (sku, product_name, category_id, supplier_id, unit_price, status) VALUES
('SKU-1001', 'Filter Coffee Powder 500g',   1, 1, 260.00, 'ACTIVE'),
('SKU-1002', 'Masala Chai Tea 250g',        1, 4, 145.00, 'ACTIVE'),
('SKU-1003', 'Salted Potato Chips 90g',     2, 4,  30.00, 'ACTIVE'),
('SKU-1004', 'Marie Biscuits 250g',         2, 2,  40.00, 'ACTIVE'),
('SKU-1005', 'Toned Milk 1L',               3, 3,  54.00, 'ACTIVE'),
('SKU-1006', 'Fresh Curd 400g',             3, 3,  35.00, 'ACTIVE'),
('SKU-1007', 'Neem Bath Soap 125g',         4, 5,  42.00, 'ACTIVE'),
('SKU-1008', 'Herbal Shampoo 340ml',        4, 5, 199.00, 'DISCONTINUED'),
('SKU-1009', 'Detergent Powder 1kg',        5, 2, 110.00, 'ACTIVE'),
('SKU-1010', 'Sona Masoori Rice 5kg',       6, 6, 375.00, 'ACTIVE'),
('SKU-1011', 'Frozen Green Peas 500g',      7, 7,  95.00, 'ACTIVE'),
('SKU-1012', 'Long Notebook 172 pages',     8, 8,  60.00, 'ACTIVE'),
('SKU-1013', 'USB-C Cable 1m',              9, 9, 249.00, 'DISCONTINUED'),
('SKU-1014', 'Baby Diapers Medium 20pc',   10,10, 399.00, 'ACTIVE'),
('SKU-1015', 'Ballpoint Pen Pack of 5',     8, 8,  50.00, 'DISCONTINUED');

-- ------------------------------------------------------------------- stock
INSERT INTO stock (warehouse_id, sku, quantity, reorder_level) VALUES
(1, 'SKU-1001', 420,  50),
(1, 'SKU-1003', 900, 150),
(1, 'SKU-1010', 180,  40),
(2, 'SKU-1002', 150,  30),
(2, 'SKU-1004', 600, 100),
(2, 'SKU-1008',  12,  20),
(3, 'SKU-1013',   8,  15),
(3, 'SKU-1012', 300,  60),
(4, 'SKU-1005', 240,  80),
(4, 'SKU-1006',  60,  70),
(5, 'SKU-1009', 210,  50),
(5, 'SKU-1007', 330,  60),
(6, 'SKU-1011', 140,  40),
(7, 'SKU-1014',  25,  30),
(8, 'SKU-1015', 120,  25),
(9, 'SKU-1001',  45,  50),
(10,'SKU-1003', 260,  80);

-- =====================================================================
-- FAILING-INSERT EVIDENCE (each statement below is EXPECTED to fail)
-- In Workbench enable "Continue on SQL Script Error" before running.
-- =====================================================================

-- (1) Duplicate key -> Error 1062
INSERT INTO product (sku, product_name, category_id, supplier_id, unit_price)
VALUES ('SKU-1001', 'Instant Coffee 100g', 1, 1, 180.00);

-- (2) Missing parent (warehouse 99) -> Error 1452
INSERT INTO stock (warehouse_id, sku, quantity, reorder_level)
VALUES (99, 'SKU-1002', 100, 20);

-- (3) Negative quantity -> Error 3819
INSERT INTO stock (warehouse_id, sku, quantity, reorder_level)
VALUES (2, 'SKU-1005', -25, 10);

-- (4) NULL in mandatory column -> Error 1048
INSERT INTO product (sku, product_name, category_id, supplier_id, unit_price)
VALUES ('SKU-1016', NULL, 2, 4, 25.00);
