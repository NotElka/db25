--Lab5
--Name:Abdrakhmanov Elmurad
--StudentID:24B030966
CREATE DATABASE lab5;
-- TASK 1.1
CREATE TABLE employees (
    employee_id INT,
    first_name TEXT,
    last_name TEXT,
    age INTEGER CHECK (age BETWEEN 18 AND 65),
    salary NUMERIC CHECK (salary > 0)
);

-- TASK 1.2
CREATE TABLE products_catalog (
    product_id INT,
    product_name TEXT,
    regular_price NUMERIC,
    discount_price NUMERIC,
    CONSTRAINT valid_discount CHECK (
        regular_price > 0
        AND discount_price > 0
        AND discount_price < regular_price
    )
);

-- TASK 1.3
CREATE TABLE bookings (
    booking_id INT,
    check_in_date DATE,
    check_out_date DATE,
    num_guests INTEGER CHECK (num_guests BETWEEN 1 AND 10),
    CHECK (check_out_date > check_in_date)
);

-- TASK 1.4
INSERT INTO employees VALUES (1, 'John', 'Smith', 30, 2000);
INSERT INTO employees VALUES (2, 'Anna', 'Lee', 45, 3500);
-- error: age < 18
INSERT INTO employees VALUES (3, 'Mike', 'Brown', 16, 1800);

INSERT INTO products_catalog VALUES (1, 'Laptop', 1000, 800);
INSERT INTO products_catalog VALUES (2, 'Phone', 700, 500);
-- error: regular_price = 0
INSERT INTO products_catalog VALUES (3, 'Tablet', 0, 200);

INSERT INTO bookings VALUES (1, '2025-05-01', '2025-05-05', 2);
INSERT INTO bookings VALUES (2, '2025-07-10', '2025-07-15', 5);
-- error: num_guests out of range
INSERT INTO bookings VALUES (3, '2025-06-01', '2025-06-05', 0);

-- TASK 2.1
CREATE TABLE customers (
    customer_id INT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

-- TASK 2.2
CREATE TABLE inventory (
    item_id INT NOT NULL,
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
    last_updated TIMESTAMP NOT NULL
);

-- TASK 2.3
INSERT INTO customers VALUES (1, 'john@example.com', '555-1234', '2025-01-10');
-- error: NULL in NOT NULL field
INSERT INTO customers VALUES (NULL, 'bob@example.com', '555-6789', '2025-03-20');

INSERT INTO inventory VALUES (1, 'Laptop', 10, 1200.00, '2025-05-01 10:00:00');
-- error: quantity < 0
INSERT INTO inventory VALUES (3, 'Keyboard', -5, 30.00, '2025-05-03 12:00:00');

-- TASK 3.1
CREATE TABLE users (
    user_id INT,
    username TEXT UNIQUE,
    email TEXT UNIQUE,
    created_at TIMESTAMP
);

-- TASK 3.2
CREATE TABLE course_enrollments (
    enrollment_id INT,
    student_id INT,
    course_code TEXT,
    semester TEXT,
    UNIQUE (student_id, course_code, semester)
);

-- TASK 3.3
ALTER TABLE users ADD CONSTRAINT unique_username UNIQUE (username);
ALTER TABLE users ADD CONSTRAINT unique_email UNIQUE (email);

INSERT INTO users VALUES (5, 'mark', 'mark@mail.com', '2025-06-01 12:00:00');
INSERT INTO users VALUES (6, 'kate', 'kate@mail.com', '2025-06-02 13:00:00');
-- error: duplicate username
INSERT INTO users VALUES (7, 'mark', 'mark2@mail.com', '2025-06-03 14:00:00');
-- error: duplicate email
INSERT INTO users VALUES (8, 'alex2', 'kate@mail.com', '2025-06-03 14:00:00');

-- TASK 4.1
CREATE TABLE departments (
    dept_id INT PRIMARY KEY,
    dept_name TEXT NOT NULL,
    location TEXT
);

-- TASK 4.2
CREATE TABLE student_courses (
    student_id INT,
    course_id INT,
    enrollment_date DATE,
    grade TEXT,
    PRIMARY KEY (student_id, course_id)
);

-- TASK 4.3 (short notes)
-- PRIMARY KEY: unique row identifier, cannot be NULL
-- UNIQUE: ensures unique values but allows NULL
-- single vs composite key = one column vs multiple columns

-- TASK 5.1
CREATE TABLE employees_dept (
    emp_id INTEGER PRIMARY KEY,
    emp_name TEXT NOT NULL,
    dept_id INTEGER REFERENCES departments(dept_id),
    hire_date DATE
);

-- TASK 5.2
CREATE TABLE authors (
    author_id INTEGER PRIMARY KEY,
    author_name TEXT NOT NULL,
    country TEXT
);

CREATE TABLE publishers (
    publisher_id INTEGER PRIMARY KEY,
    publisher_name TEXT NOT NULL,
    city TEXT
);

CREATE TABLE books (
    book_id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    author_id INTEGER REFERENCES authors(author_id),
    publisher_id INTEGER REFERENCES publishers(publisher_id),
    publication_year INTEGER,
    isbn TEXT UNIQUE
);

-- TASK 5.3
CREATE TABLE categories (
    category_id INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL
);

CREATE TABLE products_fk (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(category_id) ON DELETE RESTRICT
);

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    order_date DATE NOT NULL
);

CREATE TABLE order_items (
    item_id INTEGER PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products_fk(product_id),
    quantity INTEGER CHECK (quantity > 0)
);

-- TASK 5.4
INSERT INTO categories VALUES (1, 'Electronics');
INSERT INTO categories VALUES (2, 'Books');

INSERT INTO products_fk VALUES (1, 'Laptop', 1);
INSERT INTO products_fk VALUES (2, 'Headphones', 1);
INSERT INTO products_fk VALUES (3, 'Novel', 2);

INSERT INTO orders VALUES (1, '2025-03-01');
INSERT INTO orders VALUES (2, '2025-03-02');

INSERT INTO order_items VALUES (1, 1, 1, 2);
INSERT INTO order_items VALUES (2, 1, 2, 1);
INSERT INTO order_items VALUES (3, 2, 3, 4);

-- error: RESTRICT violation (category still referenced)
DELETE FROM categories WHERE category_id = 1;

-- cascade delete works
DELETE FROM orders WHERE order_id = 1;

-- TASK 6.1 (new data)
DROP TABLE IF EXISTS customers, products, orders, order_details CASCADE;

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id) ON DELETE CASCADE,
    order_date DATE NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'))
);

CREATE TABLE order_details (
    order_detail_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0)
);

-- customer data
INSERT INTO customers (name, email, phone, registration_date) VALUES
('Emily Parker', 'emily.parker@example.com', '+77001112211', '2025-02-05'),
('James Wilson', 'james.wilson@example.com', '+77005554433', '2025-02-20'),
('Sofia Karimova', 'sofia.karimova@example.com', '+77008889977', '2025-03-15'),
('David Chen', 'david.chen@example.com', '+77001235678', '2025-04-10'),
('Laura Kim', 'laura.kim@example.com', '+77007779955', '2025-05-25');

-- products data
INSERT INTO products (name, description, price, stock_quantity) VALUES
('Smartphone X1', '6.5-inch AMOLED, 128GB', 350000.00, 30),
('Gaming Laptop G5', 'RTX 4060, 16GB RAM', 650000.00, 8),
('Bluetooth Headset', 'Noise cancelling', 45000.00, 40),
('Smartwatch Pro', 'Waterproof, Heart Rate Monitor', 80000.00, 20),
('Portable Charger', '10000mAh fast charging', 15000.00, 70);

-- orders data
INSERT INTO orders (customer_id, order_date, total_amount, status) VALUES
(1, '2025-06-02', 365000.00, 'processing'),
(2, '2025-06-08', 695000.00, 'pending'),
(3, '2025-07-03', 95000.00, 'delivered'),
(4, '2025-07-18', 80000.00, 'shipped'),
(5, '2025-08-01', 15000.00, 'cancelled');

-- order details data
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 350000.00),
(1, 5, 1, 15000.00),
(2, 2, 1, 650000.00),
(2, 3, 1, 45000.00),
(3, 3, 2, 45000.00),
(4, 4, 1, 80000.00),
(5, 5, 1, 15000.00);

-- invalid inserts (for testing constraints)
-- negative price
INSERT INTO products (name, description, price, stock_quantity)
VALUES ('Broken Item', 'Test invalid price', -120, 5);

-- zero quantity
INSERT INTO order_details (order_id, product_id, quantity, unit_price)
VALUES (1, 2, 0, 650000.00);

-- invalid status
INSERT INTO orders (customer_id, order_date, total_amount, status)
VALUES (1, '2025-09-01', 1000, 'returned');

-- duplicate email
INSERT INTO customers (name, email, phone, registration_date)
VALUES ('Duplicate', 'emily.parker@example.com', '+77001112211', '2025-09-10');

-- non-existent customer_id
INSERT INTO orders (customer_id, order_date, total_amount, status)
VALUES (99, '2025-09-05', 3000, 'pending');

-- cascade delete test
DELETE FROM customers WHERE customer_id = 2;

-- missing NOT NULL field
INSERT INTO customers (email, phone, registration_date)
VALUES ('no_name@example.com', '+77001230000', '2025-09-12');

