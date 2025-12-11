CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    iin CHAR(12) UNIQUE,
    full_name TEXT,
    phone TEXT,
    email TEXT,
    status TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    daily_limit_kzt NUMERIC
);

CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    account_number TEXT UNIQUE,
    currency TEXT,
    balance NUMERIC,
    is_active BOOLEAN,
    opened_at TIMESTAMP DEFAULT NOW(),
    closed_at TIMESTAMP
);

CREATE TABLE exchange_rates (
    rate_id SERIAL PRIMARY KEY,
    from_currency TEXT,
    to_currency TEXT,
    rate NUMERIC,
    valid_from TIMESTAMP,
    valid_to TIMESTAMP
);

CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INT REFERENCES accounts(account_id),
    to_account_id INT REFERENCES accounts(account_id),
    amount NUMERIC,
    currency TEXT,
    exchange_rate NUMERIC,
    amount_kzt NUMERIC,
    type TEXT,
    status TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    description TEXT
);

CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name TEXT,
    record_id INT,
    action TEXT,
    old_values JSONB,
    new_values JSONB,
    changed_by TEXT,
    changed_at TIMESTAMP DEFAULT NOW(),
    ip_address TEXT
);

INSERT INTO customers (iin, full_name, phone, email, status, daily_limit_kzt)
VALUES
('111111111111','Aruzhan Karim','+7701000001','a1@mail.com','active',5000000),
('222222222222','Nurlan Sadykov','+7701000002','a2@mail.com','active',3000000),
('333333333333','Aydana Uraz','+7701000003','a3@mail.com','active',4000000),
('444444444444','Timur Zhaksylyk','+7701000004','a4@mail.com','blocked',2000000),
('555555555555','Dias Mukan','+7701000005','a5@mail.com','active',6000000),
('666666666666','Dana Serik','+7701000006','a6@mail.com','frozen',3000000),
('777777777777','Alibek Omar','+7701000007','a7@mail.com','active',5000000),
('888888888888','Kamila Askar','+7701000008','a8@mail.com','active',2500000),
('999999999999','Yerbol Ersain','+7701000009','a9@mail.com','active',4000000),
('121212121212','Aruzhan Abai','+7701000010','a10@mail.com','active',4500000);

INSERT INTO accounts (customer_id, account_number, currency, balance, is_active)
VALUES
(1,'KZ001','KZT',900000,TRUE),
(1,'KZ002','USD',1000,TRUE),
(2,'KZ003','KZT',500000,TRUE),
(3,'KZ004','EUR',1500,TRUE),
(4,'KZ005','KZT',200000,TRUE),
(5,'KZ006','USD',400,TRUE),
(6,'KZ007','KZT',350000,TRUE),
(7,'KZ008','RUB',50000,TRUE),
(8,'KZ009','KZT',800000,TRUE),
(9,'KZ010','KZT',650000,TRUE);

INSERT INTO exchange_rates (from_currency,to_currency,rate,valid_from,valid_to)
VALUES
('USD','KZT',500, NOW(), NOW()+INTERVAL '30 days'),
('EUR','KZT',550, NOW(), NOW()+INTERVAL '30 days'),
('RUB','KZT',5.5, NOW(), NOW()+INTERVAL '30 days'),
('KZT','KZT',1, NOW(), NOW()+INTERVAL '30 days'),
('KZT','USD',1/500.0, NOW(), NOW()+INTERVAL '30 days'),
('KZT','EUR',1/550.0, NOW(), NOW()+INTERVAL '30 days'),
('KZT','RUB',1/5.5, NOW(), NOW()+INTERVAL '30 days'),
('USD','EUR',1.1, NOW(), NOW()+INTERVAL '30 days'),
('EUR','USD',0.9, NOW(), NOW()+INTERVAL '30 days'),
('RUB','USD',0.011, NOW(), NOW()+INTERVAL '30 days');

--task1

CREATE OR REPLACE PROCEDURE process_transfer(
    p_from_acc TEXT,
    p_to_acc TEXT,
    p_amount NUMERIC,
    p_currency TEXT,
    p_description TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    from_id INT;
    to_id INT;
    sender_customer INT;
    sender_status TEXT;
    rate NUMERIC;
    amount_kzt NUMERIC;
    today_total NUMERIC;
    daily_limit NUMERIC;
BEGIN
    -- get accounts
    SELECT account_id, customer_id INTO from_id, sender_customer
    FROM accounts WHERE account_number = p_from_acc AND is_active = TRUE FOR UPDATE;

    IF from_id IS NULL THEN
        RAISE EXCEPTION 'FROM account not found or inactive';
    END IF;

    SELECT account_id INTO to_id
    FROM accounts WHERE account_number = p_to_acc AND is_active = TRUE FOR UPDATE;

    IF to_id IS NULL THEN
        RAISE EXCEPTION 'TO account not found or inactive';
    END IF;

    -- sender status
    SELECT status, daily_limit_kzt INTO sender_status, daily_limit
    FROM customers WHERE customer_id = sender_customer;

    IF sender_status <> 'active' THEN
        RAISE EXCEPTION 'Sender customer is not active';
    END IF;

    -- currency conversion
    SELECT rate INTO rate
    FROM exchange_rates
    WHERE from_currency = p_currency AND to_currency = 'KZT'
    ORDER BY valid_from DESC LIMIT 1;

    amount_kzt := p_amount * rate;

    -- check balance
    IF (SELECT balance FROM accounts WHERE account_id = from_id) < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance';
    END IF;

    -- daily limit check
    SELECT COALESCE(SUM(amount_kzt),0) INTO today_total
    FROM transactions
    WHERE from_account_id = from_id
      AND created_at >= CURRENT_DATE;

    IF today_total + amount_kzt > daily_limit THEN
        RAISE EXCEPTION 'Daily limit exceeded';
    END IF;

    -- update balances
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = from_id;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = to_id;

    -- insert transaction
    INSERT INTO transactions(from_account_id,to_account_id,amount,currency,
                             exchange_rate,amount_kzt,type,status,completed_at,description)
    VALUES(from_id,to_id,p_amount,p_currency,rate,amount_kzt,
           'transfer','completed',NOW(),p_description);

    -- log
    INSERT INTO audit_log(table_name,record_id,action,new_values,changed_by,ip_address)
    VALUES('transactions',(SELECT MAX(transaction_id) FROM transactions),
           'INSERT',jsonb_build_object('amount',p_amount),'system','127.0.0.1');

END;
$$;

--Task2

-- 1) customer_balance_summary
CREATE OR REPLACE VIEW customer_balance_summary AS
WITH accounts_kzt AS (
  -- convert each account balance to KZT using latest available rate (if any)
  SELECT
    c.customer_id,
    c.full_name,
    c.daily_limit_kzt,
    a.account_id,
    a.account_number,
    a.currency,
    a.balance,
    COALESCE(r.rate, 1) AS rate,
    a.balance * COALESCE(r.rate, 1) AS balance_kzt
  FROM customers c
  LEFT JOIN accounts a ON a.customer_id = c.customer_id
  LEFT JOIN LATERAL (
    SELECT rate
    FROM exchange_rates
    WHERE from_currency = a.currency
      AND to_currency = 'KZT'
    ORDER BY valid_from DESC
    LIMIT 1
  ) r ON a.account_id IS NOT NULL
),
per_customer AS (
  -- compute total per customer
  SELECT
    customer_id,
    full_name,
    daily_limit_kzt,
    account_id,
    account_number,
    currency,
    balance,
    rate,
    balance_kzt,
    SUM(COALESCE(balance_kzt,0)) OVER (PARTITION BY customer_id) AS total_balance_kzt
  FROM accounts_kzt
)
SELECT
  pc.customer_id,
  pc.full_name,
  pc.account_id,
  pc.account_number,
  pc.currency,
  pc.balance,
  pc.rate,
  pc.balance_kzt,
  pc.total_balance_kzt,
  ROUND(
    pc.total_balance_kzt / NULLIF(pc.daily_limit_kzt,0) * 100,
    2
  ) AS daily_limit_usage_percent,
  RANK() OVER (ORDER BY pc.total_balance_kzt DESC) AS rank_by_balance
FROM per_customer pc
ORDER BY pc.total_balance_kzt DESC;


-- 2) daily_transaction_report
CREATE OR REPLACE VIEW daily_transaction_report AS
WITH base AS (
    SELECT
        DATE(created_at) AS day,
        type,
        SUM(amount_kzt) AS total_volume_kzt,
        COUNT(*) AS total_count,
        AVG(amount_kzt) AS avg_amount_kzt
    FROM transactions
    GROUP BY DATE(created_at), type
)
SELECT
    day,
    type,
    total_volume_kzt,
    total_count,
    avg_amount_kzt,
    SUM(total_volume_kzt) OVER (ORDER BY day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_kzt,
    ROUND(
        (total_volume_kzt - LAG(total_volume_kzt) OVER (ORDER BY day))
         / NULLIF(LAG(total_volume_kzt) OVER (ORDER BY day),0) * 100,
        2
    ) AS day_over_day_growth_percent
FROM base
ORDER BY day;


-- 3) suspicious_activity_view (WITH SECURITY BARRIER)
CREATE OR REPLACE VIEW suspicious_activity_view
WITH (security_barrier = true) AS
WITH t AS (
    SELECT
        tr.*,
        COUNT(*) OVER (
            PARTITION BY from_account_id, DATE_TRUNC('hour', created_at)
        ) AS tx_per_hour,
        EXTRACT(EPOCH FROM (
            created_at - LAG(created_at) OVER (
                PARTITION BY from_account_id ORDER BY created_at
            )
        )) AS seconds_since_last
    FROM transactions tr
)
SELECT *
FROM t
WHERE (amount_kzt IS NOT NULL AND amount_kzt > 5000000)
   OR (tx_per_hour IS NOT NULL AND tx_per_hour > 10)
   OR (seconds_since_last IS NOT NULL AND seconds_since_last < 60);

--Task3

-- 1. B-tree index (search by account number)
CREATE INDEX idx_accounts_account_number
ON accounts(account_number);

-- 2. Composite index (status + iin)
CREATE INDEX idx_customers_status_iin
ON customers(status, iin);

-- 3. Partial index (only active accounts)
CREATE INDEX idx_accounts_active_only
ON accounts(customer_id)
WHERE is_active = TRUE;

-- 4. Expression index (case-insensitive email)
CREATE INDEX idx_customers_email_lower
ON customers(LOWER(email));

-- 5. GIN index for JSONB search (audit log)
CREATE INDEX idx_audit_log_new_values_gin
ON audit_log USING GIN (new_values);

-- 6. Hash index (exact match on currency)
CREATE INDEX idx_accounts_currency_hash
ON accounts USING HASH (currency);

-- 7. Covering index (frequent pattern: get balance by account_number)
CREATE INDEX idx_accounts_covering
ON accounts(account_number) INCLUDE (balance);

--explain analyze

--1 composite index
EXPLAIN ANALYZE
SELECT * FROM customers
WHERE status='active' AND iin='111111111111';

--2 partial index
EXPLAIN ANALYZE
SELECT * FROM accounts
WHERE is_active = TRUE AND customer_id = 1;

-- 3 JSONB GIN index
EXPLAIN ANALYZE
SELECT * FROM audit_log
WHERE new_values ? 'amount';

--4 covering index
EXPLAIN ANALYZE
SELECT balance FROM accounts
WHERE account_number='KZ001';

-- 5 expression index
EXPLAIN ANALYZE
SELECT * FROM customers
WHERE LOWER(email)='a1@mail.com';

--Task4
CREATE OR REPLACE PROCEDURE process_salary_batch(
    p_company_acc TEXT,
    p_payments JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    company_acc_id INT;
    company_balance NUMERIC;
    lock_key BIGINT;
    total_batch NUMERIC := 0;
    total_success NUMERIC := 0;

    elem JSONB;
    emp_iin TEXT;
    emp_amount NUMERIC;
    emp_desc TEXT;

    target_customer INT;
    target_acc INT;

    success_count INT := 0;
    fail_count INT := 0;
    fail_list JSONB := '[]'::jsonb;
BEGIN
    -- advisory lock
    lock_key := ('x' || substr(md5(p_company_acc),1,16))::bit(64)::bigint;
    PERFORM pg_advisory_lock(lock_key);

    -- get company account
    BEGIN
        SELECT account_id, balance
        INTO company_acc_id, company_balance
        FROM accounts
        WHERE account_number = p_company_acc
          AND is_active = TRUE
        FOR UPDATE;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        PERFORM pg_advisory_unlock(lock_key);
        RAISE EXCEPTION 'Company account not found';
    END;

    -- calculate total batch
    SELECT COALESCE(SUM( (elem->>'amount')::numeric ),0)
    INTO total_batch
    FROM jsonb_array_elements(p_payments) elem;

    IF company_balance < total_batch THEN
        PERFORM pg_advisory_unlock(lock_key);
        RAISE EXCEPTION 'Insufficient funds: need %, have %', total_batch, company_balance;
    END IF;

    -- process each payment
    FOR elem IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        emp_iin := elem->>'iin';
        emp_amount := (elem->>'amount')::numeric;
        emp_desc := elem->>'description';

        BEGIN
            -- find customer
            SELECT customer_id INTO target_customer
            FROM customers
            WHERE iin = emp_iin;

            IF target_customer IS NULL THEN
                RAISE EXCEPTION 'Customer with IIN % not found', emp_iin;
            END IF;

            -- get employee account
            SELECT account_id INTO target_acc
            FROM accounts
            WHERE customer_id = target_customer
              AND currency = 'KZT'
              AND is_active = TRUE
            ORDER BY account_id
            LIMIT 1
            FOR UPDATE;

            IF target_acc IS NULL THEN
                RAISE EXCEPTION 'No active KZT account for IIN %', emp_iin;
            END IF;

            -- credit employee
            UPDATE accounts
            SET balance = balance + emp_amount
            WHERE account_id = target_acc;

            -- record transaction
            INSERT INTO transactions(
                from_account_id, to_account_id, amount, currency,
                exchange_rate, amount_kzt, type, status, completed_at, description
            )
            VALUES (
                company_acc_id, target_acc, emp_amount, 'KZT',
                1, emp_amount, 'salary_batch', 'completed', NOW(), emp_desc
            );

            success_count := success_count + 1;
            total_success := total_success + emp_amount;

        EXCEPTION WHEN OTHERS THEN
            fail_count := fail_count + 1;
            fail_list := fail_list || jsonb_build_object(
                'iin', emp_iin,
                'amount', emp_amount,
                'error', SQLERRM
            );
            -- no rollback, just continue
        END;
    END LOOP;

    -- subtract only successful payments
    UPDATE accounts
    SET balance = balance - total_success
    WHERE account_id = company_acc_id;

    PERFORM pg_advisory_unlock(lock_key);

    RAISE NOTICE 'Success: %, Failed: %', success_count, fail_count;
    RAISE NOTICE 'Fail list: %', fail_list;

END;
$$;

--MATERIALIZED VIEW
CREATE MATERIALIZED VIEW salary_batch_summary AS
SELECT
    DATE(created_at) AS day,
    COUNT(*) AS total_payments,
    SUM(amount_kzt) AS total_amount
FROM transactions
WHERE type = 'salary_batch'
GROUP BY DATE(created_at);

