-- 01_schema.sql  |  Loan Default Risk Dashboard
-- Dialect: SQLite (runs anywhere). Notes for SQL Server / PostgreSQL / MySQL are in README.

DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id           INTEGER PRIMARY KEY,
    age                   INTEGER,
    state                 TEXT,
    city                  TEXT,
    city_tier             INTEGER,       -- 1 = metro, 2 = large city, 3 = smaller town
    employment_type       TEXT,          -- Salaried - Govt / Salaried - Private / Self-Employed / Gig/Contract
    years_employed        REAL,          -- employment history
    annual_income         INTEGER,       -- INR
    credit_score          INTEGER,       -- 300-900 (CIBIL-style)
    prior_delinquencies   INTEGER,
    existing_monthly_emi  INTEGER        -- INR, obligations before this loan
);

CREATE TABLE loans (
    loan_id          INTEGER PRIMARY KEY,
    customer_id      INTEGER REFERENCES customers(customer_id),
    loan_type        TEXT,
    loan_amount      INTEGER,
    tenure_months    INTEGER,
    interest_rate    REAL,
    emi              INTEGER,
    dti              REAL,               -- (existing EMI + new EMI) / monthly income
    application_date TEXT,               -- ISO date
    loan_status      TEXT,               -- Active / Closed / Defaulted / Pending
    default_flag     INTEGER             -- 1 = Defaulted, else 0 (Pending has no outcome yet)
);

CREATE INDEX idx_loans_customer ON loans(customer_id);
CREATE INDEX idx_loans_status   ON loans(loan_status);
