CREATE DATABASE retail_sales_inventory;
USE retail_sales_inventory;

CREATE TABLE categories (
	category_id INT PRIMARY KEY,
    category_name VARCHAR(100)
);

CREATE TABLE brands (
	brand_id INT PRIMARY KEY,
    brand_name VARCHAR(100)
);

CREATE TABLE products (
	product_id INT PRIMARY KEY,
    product_name VARCHAR(500),
    brand_id INT,
    category_id INT,
    model_year INT,
    list_price DECIMAL(10,2),
	FOREIGN KEY (brand_id) 	REFERENCES brands(brand_id),
    FOREIGN KEY (category_id) 	REFERENCES categories(category_id)
);

CREATE TABLE stores (
	store_id INT PRIMARY KEY,
    store_name VARCHAR (200),
    phone VARCHAR (50),
    email VARCHAR (100),
    street VARCHAR (200),
    city VARCHAR (200), 
    state VARCHAR (50),
    zip_code INT
);

--  STAFFS TABLE
-- Step 1: Make sure all relevant columns are INT (same data type) 
ALTER TABLE staffs 
MODIFY COLUMN store_id INT,
MODIFY COLUMN staff_id INT NOT NULL,
MODIFY COLUMN manager_id INT NULL;

-- Step 2: Add the PRIMARY KEY on staff_id
ALTER TABLE staffs 
ADD PRIMARY KEY (staff_id);

-- Step 3: Add the foreign key constraints
ALTER TABLE staffs
ADD CONSTRAINT fk_staff_store
FOREIGN KEY (store_id) REFERENCES stores(store_id),
ADD CONSTRAINT fk_staff_manager
FOREIGN KEY (manager_id) REFERENCES staffs(staff_id);

-- Making sure data is clean
SELECT store_id FROM staffs WHERE store_id NOT IN (SELECT store_id FROM stores);
SELECT manager_id FROM staffs WHERE manager_id IS NOT NULL AND manager_id NOT IN (SELECT staff_id FROM staffs);


CREATE TABLE customers (
	customer_id INT PRIMARY KEY,
    first_name VARCHAR (100),
    last_name VARCHAR (100),
    phone VARCHAR (50),
    email VARCHAR (150),
    street VARCHAR (200),
    city VARCHAR (200),
    state VARCHAR (50),
    zip_code INT
);

CREATE TABLE orders_staging (
	order_id INT,
    customer_id INT,
    order_status VARCHAR (50),
    order_date VARCHAR(15),
    required_date VARCHAR(15),
    shipped_date VARCHAR(15),
    store_id INT,
    staff_id INT
);
DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
	order_id INT PRIMARY KEY,
    customer_id INT,
    order_status VARCHAR (50),
    order_date DATE,
    required_date DATE,	
    shipped_date DATE,
    store_id INT,
    staff_id INT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (staff_id) REFERENCES staffs(staff_id)
);

INSERT INTO orders (
	order_id, customer_id, order_status, order_date,
	required_date, shipped_date, store_id, staff_id
)
SELECT
	order_id,
	customer_id,
	order_status,
    STR_TO_DATE(order_date, '%d-%m-%y'),
	STR_TO_DATE(required_date, '%d-%m-%y'),
	STR_TO_DATE(shipped_date, '%d-%m-%y'),
	store_id,
	staff_id
FROM orders_staging;


CREATE TABLE order_items (
	order_id INT,
    item_id INT,
	product_id INT,
    quantity INT,
    list_price DECIMAL(10,2),
    discount DECIMAL(10,2),
    PRIMARY KEY (order_id, item_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE stocks (
	store_id INT,
    product_id INT,
    quantity INT,
    PRIMARY KEY (store_id, product_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
	FOREIGN KEY (product_id) REFERENCES products(product_id)
);

SELECT COUNT(*) FROM categories;
SELECT COUNT(*) FROM brands;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM stores;
SELECT COUNT(*) FROM staffs;
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM stocks;

-- Query 1: Store-wise and Region-wise Sales
SELECT 
    s.store_name,
    s.city,
    s.state,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_sales_amount
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN stores s ON o.store_id = s.store_id
GROUP BY s.store_name, s.city, s.state
ORDER BY total_sales_amount DESC;

-- Query 2: Product-wise Sales and Inventory Trends
SELECT 
    p.product_name,
    b.brand_name,
    c.category_name,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_revenue,
    st.quantity AS current_stock
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN brands b ON p.brand_id = b.brand_id
JOIN categories c ON p.category_id = c.category_id
JOIN stocks st ON p.product_id = st.product_id
GROUP BY p.product_name, b.brand_name, c.category_name, st.quantity
ORDER BY total_revenue DESC
LIMIT 10;

-- Query 3: Staff Performance Reports
SELECT 
    sf.first_name,
    sf.last_name,
    s.store_name,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_sales
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN staffs sf ON o.staff_id = sf.staff_id
JOIN stores s ON o.store_id = s.store_id
GROUP BY sf.first_name, sf.last_name, s.store_name
ORDER BY total_sales DESC;

-- Query 4: Customer Orders and Frequency
SELECT 
    c.first_name,
    c.last_name,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.first_name, c.last_name
ORDER BY total_spent DESC
LIMIT 5;

-- Query 5: Revenue and Discount Analysis
SELECT 
    ROUND(SUM(oi.quantity * oi.list_price), 2) AS gross_revenue,
    ROUND(SUM(oi.quantity * oi.list_price * oi.discount), 2) AS total_discount,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM order_items oi;

-- Create SQL Views (Reusable Insights)
-- 1. Year Sales Trend
CREATE VIEW vw_yearly_sales AS
SELECT 
    YEAR(o.order_date) AS year,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_sales,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY YEAR(o.order_date)
ORDER BY year;
SELECT * FROM vw_yearly_sales;

-- 2. Low Stock Alert
CREATE VIEW vw_low_stock AS
SELECT 
    p.product_name,
    b.brand_name,
    s.store_name,
    st.quantity AS current_stock
FROM stocks st
JOIN products p ON st.product_id = p.product_id
JOIN brands b ON p.brand_id = b.brand_id
JOIN stores s ON st.store_id = s.store_id
WHERE st.quantity < 20
ORDER BY st.quantity ASC;
SELECT * FROM vw_low_stock;

-- 3. Category Revenue Comparison
CREATE VIEW vw_category_revenue AS
SELECT 
    c.category_name,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY c.category_name
ORDER BY total_revenue DESC;
SELECT * FROM vw_category_revenue;

-- 4. Top Customers by Region
CREATE VIEW vw_top_customers_region AS
SELECT 
    c.first_name,
    c.last_name,
    s.state,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN stores s ON o.store_id = s.store_id
GROUP BY c.first_name, c.last_name, s.state
ORDER BY total_spent DESC
LIMIT 10;
SELECT * FROM vw_top_customers_region;