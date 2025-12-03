 CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    balance DECIMAL(10, 2) DEFAULT 0.00
 );
 CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    shop VARCHAR(100) NOT NULL,
    product VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL
 );-- Insert test data
 INSERT INTO accounts (name, balance) VALUES
    ('Alice', 1000.00),
    ('Bob', 500.00),
    ('Wally', 750.00);
 INSERT INTO products (shop, product, price) VALUES
    ('Joe''s Shop', 'Coke', 2.50),
    ('Joe''s Shop', 'Pepsi', 3.00);

--task1
BEGIN;
UPDATE accounts SET balance=balance-100
WHERE name='Alice';
UPDATE accounts SET balance=balance+100
WHERE name='Bob';
COMMIT;

-- a) Alice = 900, Bob = 600
-- b) Transaction ensures both updates happen together
-- c) If crash happens mid-way → inconsistent balances without a transaction

--task2

BEGIN;
UPDATE accounts SET balance=balance-500
WHERE name = 'Alice';
SELECT * FROM accounts WHERE name = 'Alice';
-- Oops! Wrong amount, let's undo
ROLLBACK;
SELECT * FROM accounts WHERE name = 'Alice';

--a)400
--b)900
--c)Used when an error happens and we must cancel changes

--task3
 BEGIN;
 UPDATE accounts SET balance = balance - 100.00
    WHERE name = 'Alice';
 SAVEPOINT my_savepoint;
UPDATE accounts SET balance = balance + 100.00
    WHERE name = 'Bob';-- Oops, should transfer to Wally instead
 ROLLBACK TO my_savepoint;
 UPDATE accounts SET balance = balance + 100.00
    WHERE name = 'Wally';
 COMMIT;

SELECT * FROM accounts WHERE name = 'Alice';
SELECT * FROM accounts WHERE name = 'Bob';
SELECT * FROM accounts WHERE name = 'Wally';

--a)800 , 600 , 850
--b)Bob's update undone because we rolled back to the savepoint
--c)Savepoints allow partial rollback inside a large transaction

--task4
--scenario a
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM products WHERE shop = 'Joe''s Shop';

BEGIN;
DELETE FROM products WHERE shop = 'Joe''s Shop';
INSERT INTO products (shop, product, price)
VALUES ('Joe''s Shop', 'Fanta', 3.50);
COMMIT;

SELECT * FROM products WHERE shop = 'Joe''s Shop';
COMMIT;

--scenario b
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE ;
SELECT * FROM products WHERE shop = 'Joe''s Shop';

BEGIN;
DELETE FROM products WHERE shop = 'Joe''s Shop';
INSERT INTO products (shop, product, price)
VALUES ('Joe''s Shop', 'Fanta', 3.50);
COMMIT;

SELECT * FROM products WHERE shop = 'Joe''s Shop';
COMMIT;

--a) before - information is unchanged, after - only fanta (phantom)
--b) before - information is unchanged, after - the same information, without changing (no phantom)
--c) in serializable operations are guaranteed to take turns, but in read committed not

--task 5
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT MAX(price), MIN(price) FROM products WHERE shop = 'Joe''s Shop';
BEGIN;
INSERT INTO products (shop, product, price)
VALUES ('Joe''s Shop', 'Sprite', 4.00);
COMMIT;
SELECT MAX(price), MIN(price) FROM products WHERE shop = 'Joe''s Shop';
COMMIT;

--a) no, does not see
--b) A Phantom Read is a situation where, when executing the same query repeatedly, new rows appear (or old ones disappear) inside the same transaction that were not there when it was first executed
--c) Repeatable Read and Serializable

--task6
--terminal 1
BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- Wait for Terminal 2 to UPDATE but NOT commit
SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- Wait for Terminal 2 to ROLLBACK
SELECT * FROM products WHERE shop = 'Joe''s Shop';
COMMIT;
--terminal 2
BEGIN;
UPDATE products SET price = 99.99
WHERE product = 'Fanta';
-- Wait here (don't commit yet)
-- Then:
ROLLBACK;

--a) no, does not
--b) Dirty Read is when one transaction reads the uncommitted ("dirty") changes of another transaction, which can then be rolled back
--c) It's dangerous because it allows you to read data that never existed

--Independent Exercises
--1
DO $$
DECLARE
    bob_balance DECIMAL(12,2);
BEGIN
    SELECT balance INTO bob_balance
    FROM accounts
    WHERE name = 'Bob'
    FOR UPDATE;

    IF bob_balance < 200.00 THEN
        RAISE EXCEPTION 'Unsufficient funds: %', bob_balance;
    END IF;

    UPDATE accounts SET balance = balance - 200 WHERE name = 'Bob';
    UPDATE accounts SET balance = balance + 200 WHERE name = 'Wally';
END $$;

--2
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
INSERT INTO products(shop, product, price) VALUES('sulpak', 'laptop', 1200.00);
SAVEPOINT after_insert;

UPDATE products SET price = 999.99 WHERE product = 'Laptop';
SAVEPOINT after_update;

DELETE FROM products WHERE product = 'Laptop';
ROLLBACK TO SAVEPOINT after_insert;
COMMIT;

--3
BEGIN ISOLATION LEVEL READ COMMITTED;
UPDATE accounts SET balance = balance - 300 WHERE name = 'Alice';
COMMIT;

BEGIN ISOLATION LEVEL READ COMMITTED;
UPDATE accounts SET balance = balance - 300 WHERE name = 'Alice';
COMMIT;


BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE name = 'Alice' FOR UPDATE;
UPDATE accounts SET balance = balance - 300 WHERE name = 'Alice';
COMMIT;

BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE name = 'Alice' FOR UPDATE;
ROLLBACK;


BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT balance FROM accounts WHERE name = 'Alice';
UPDATE accounts SET balance = balance - 300 WHERE name = 'Alice';
COMMIT;

BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT balance FROM accounts WHERE name = 'Alice';
UPDATE accounts SET balance = balance - 300 WHERE name = 'Alice';
COMMIT;


--4
BEGIN ISOLATION LEVEL REPEATABLE READ;

SELECT MAX(price) AS max_price, MIN(price) AS min_price
FROM products
WHERE shop = 'Joe''s Shop';

UPDATE products SET price = 10.00 WHERE product = 'Fanta';
UPDATE products SET price = 1.00  WHERE product = 'Sprite';
COMMIT;

SELECT MAX(price) AS max_price, MIN(price) AS min_price
FROM products
WHERE shop = 'Joe''s Shop';

COMMIT;

--Questions for Self-Assessment

-- 1. Explain each ACID property with a practical example.
-- A: Atomicity – all-or-nothing (money transfer must update both accounts).
-- C: Consistency – DB stays valid (no negative balance after transaction).
-- I: Isolation – transactions do not interfere (parallel transfers do not mix).
-- D: Durability – committed data survives crash (WAL ensures persistence).

-- 2. What is the difference between COMMIT and ROLLBACK?
-- COMMIT saves all changes permanently; ROLLBACK cancels all changes.

-- 3. When would you use a SAVEPOINT instead of a full ROLLBACK?
-- When you want to undo only part of a transaction without losing earlier work.

-- 4. Compare and contrast the four SQL isolation levels.
-- READ UNCOMMITTED – allows dirty, non-repeatable, phantom reads.
-- READ COMMITTED – no dirty reads; others possible.
-- REPEATABLE READ – no dirty or non-repeatable reads; snapshot view.
-- SERIALIZABLE – strict; prevents all anomalies, may abort conflicting tx.

-- 5. What is a dirty read and which isolation level allows it?
-- Reading uncommitted changes of another transaction; allowed only in READ UNCOMMITTED.

-- 6. What is a non-repeatable read? Give an example scenario.
-- Same row returns different values in same transaction (another tx updates/commits between reads).

-- 7. What is a phantom read? Which isolation levels prevent it?
-- New rows appear between two SELECTs; prevented by SERIALIZABLE (and by PostgreSQL REPEATABLE READ via MVCC).

-- 8. Why choose READ COMMITTED over SERIALIZABLE in high-traffic apps?
-- It has fewer conflicts, better performance, avoids frequent serialization failures.

-- 9. How do transactions maintain database consistency during concurrent access?
-- By isolating operations and ensuring atomic, consistent state changes (ACID guarantees).

-- 10. What happens to uncommitted changes if the system crashes?
-- All uncommitted changes are discarded; only committed data is restored.
