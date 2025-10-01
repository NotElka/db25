-- Part A: Database and Table Setup

CREATE DATABASE advanced_lab;
\c advanced_lab;

CREATE TABLE employees (
    emp_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department VARCHAR(50) DEFAULT 'General',
    salary INTEGER DEFAULT 40000,
    hire_date DATE,
    status VARCHAR(20) DEFAULT 'Active'
);

CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    dept_name VARCHAR(50),
    budget INTEGER,
    manager_id INTEGER
);

CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(50),
    dept_id INTEGER,
    start_date DATE,
    end_date DATE,
    budget INTEGER
);

-- Part B: Advanced INSERT Operations

INSERT INTO employees (emp_id, first_name, last_name, department)
VALUES (1, 'John', 'Doe', 'IT');

INSERT INTO employees (first_name, last_name)
VALUES ('Jane', 'Smith');

INSERT INTO departments (dept_name, budget, manager_id)
VALUES
('IT', 100000, 1),
('HR', 50000, 2),
('Sales', 80000, 3);

INSERT INTO employees (first_name, last_name, department, salary, hire_date)
VALUES ('Mark', 'Brown', 'Finance', 50000 * 1.1, CURRENT_DATE);

CREATE TEMP TABLE temp_employees AS
SELECT * FROM employees WHERE department = 'IT';

-- Part C: Complex UPDATE Operations

UPDATE employees SET salary = salary * 1.10;

UPDATE employees
SET status = 'Senior'
WHERE salary > 60000 AND hire_date < '2020-01-01';

UPDATE employees
SET department = CASE
    WHEN salary > 80000 THEN 'Management'
    WHEN salary BETWEEN 50000 AND 80000 THEN 'Senior'
    ELSE 'Junior'
END;

UPDATE employees
SET department = DEFAULT
WHERE status = 'Inactive';

UPDATE departments d
SET budget = (SELECT AVG(salary) * 1.2 FROM employees e WHERE e.department = d.dept_name);

UPDATE employees
SET salary = salary * 1.15,
    status = 'Promoted'
WHERE department = 'Sales';

-- Part D: Advanced DELETE Operations

DELETE FROM employees WHERE status = 'Terminated';

DELETE FROM employees
WHERE salary < 40000 AND hire_date > '2023-01-01' AND department IS NULL;

DELETE FROM departments
WHERE dept_name NOT IN (
    SELECT DISTINCT department FROM employees WHERE department IS NOT NULL
);

DELETE FROM projects
WHERE end_date < '2023-01-01'
RETURNING *;

-- Part E: Operations with NULL Values

INSERT INTO employees (first_name, last_name, salary, department)
VALUES ('Null', 'Case', NULL, NULL);

UPDATE employees
SET department = 'Unassigned'
WHERE department IS NULL;

DELETE FROM employees
WHERE salary IS NULL OR department IS NULL;

-- Part F: RETURNING Clause Operations

INSERT INTO employees (first_name, last_name)
VALUES ('Alice', 'Wonder')
RETURNING emp_id, first_name || ' ' || last_name AS full_name;

UPDATE employees
SET salary = salary + 5000
WHERE department = 'IT'
RETURNING emp_id, salary - 5000 AS old_salary, salary AS new_salary;

DELETE FROM employees
WHERE hire_date < '2020-01-01'
RETURNING *;

-- Part G: Advanced DML Patterns

INSERT INTO employees (first_name, last_name)
SELECT 'Bob', 'Marley'
WHERE NOT EXISTS (
    SELECT 1 FROM employees WHERE first_name = 'Bob' AND last_name = 'Marley'
);

UPDATE employees e
SET salary = salary * CASE
    WHEN (SELECT budget FROM departments d WHERE d.dept_name = e.department) > 100000
    THEN 1.10 ELSE 1.05 END;

INSERT INTO employees (first_name, last_name, department, salary, hire_date)
VALUES
('Emp1','Test','IT',40000,CURRENT_DATE),
('Emp2','Test','HR',42000,CURRENT_DATE),
('Emp3','Test','Sales',45000,CURRENT_DATE),
('Emp4','Test','Finance',47000,CURRENT_DATE),
('Emp5','Test','Support',43000,CURRENT_DATE);

UPDATE employees
SET salary = salary * 1.10
WHERE last_name = 'Test';

CREATE TABLE employee_archive AS TABLE employees WITH NO DATA;

INSERT INTO employee_archive
SELECT * FROM employees WHERE status = 'Inactive';

DELETE FROM employees WHERE status = 'Inactive';

UPDATE projects
SET end_date = end_date + INTERVAL '30 days'
WHERE budget > 50000
  AND dept_id IN (
    SELECT d.dept_id FROM departments d
    JOIN employees e ON e.department = d.dept_name
    GROUP BY d.dept_id HAVING COUNT(e.emp_id) > 3
);
