-- 02_data_quality_and_features.sql
-- Part A: data-quality checks (run these and screenshot the results for your README)
-- Part B: analysis-ready view with business bands

-- ---------- PART A: DATA QUALITY ----------
-- A1. Row counts
SELECT 'customers' AS tbl, COUNT(*) AS n FROM customers
UNION ALL SELECT 'loans', COUNT(*) FROM loans;

-- A2. Orphan loans (should be 0)
SELECT COUNT(*) AS orphan_loans
FROM loans l LEFT JOIN customers c ON c.customer_id = l.customer_id
WHERE c.customer_id IS NULL;

-- A3. Nulls / impossible values (should be 0)
SELECT
    SUM(CASE WHEN annual_income IS NULL OR annual_income <= 0 THEN 1 ELSE 0 END) AS bad_income,
    SUM(CASE WHEN credit_score NOT BETWEEN 300 AND 900            THEN 1 ELSE 0 END) AS bad_score,
    SUM(CASE WHEN age NOT BETWEEN 18 AND 100                      THEN 1 ELSE 0 END) AS bad_age
FROM customers;

-- A4. Status vs flag consistency (should be 0)
SELECT COUNT(*) AS inconsistent
FROM loans
WHERE (loan_status = 'Defaulted' AND default_flag = 0)
   OR (loan_status <> 'Defaulted' AND default_flag = 1);

-- ---------- PART B: ANALYSIS VIEW ----------
DROP VIEW IF EXISTS vw_loan_base;
CREATE VIEW vw_loan_base AS
SELECT
    l.loan_id, l.customer_id, l.loan_type, l.loan_amount, l.tenure_months,
    l.interest_rate, l.emi, l.dti, l.application_date,
    CAST(strftime('%Y', l.application_date) AS INTEGER) AS application_year,
    l.loan_status, l.default_flag,
    c.age, c.state, c.city, c.city_tier, c.employment_type, c.years_employed,
    c.annual_income, c.credit_score, c.prior_delinquencies, c.existing_monthly_emi,

    -- Income bracket (INR per year)
    CASE WHEN c.annual_income <  300000 THEN '1. < 3L'
         WHEN c.annual_income <  600000 THEN '2. 3-6L'
         WHEN c.annual_income < 1000000 THEN '3. 6-10L'
         WHEN c.annual_income < 1800000 THEN '4. 10-18L'
         ELSE                                '5. 18L+' END AS income_bracket,

    -- Employment history band
    CASE WHEN c.years_employed <  2  THEN '1. < 2 yrs'
         WHEN c.years_employed <  5  THEN '2. 2-5 yrs'
         WHEN c.years_employed < 10  THEN '3. 5-10 yrs'
         ELSE                             '4. 10+ yrs' END AS employment_history_band,

    -- Credit score band
    CASE WHEN c.credit_score < 600 THEN '1. < 600 (Poor)'
         WHEN c.credit_score < 680 THEN '2. 600-679 (Fair)'
         WHEN c.credit_score < 750 THEN '3. 680-749 (Good)'
         ELSE                           '4. 750+ (Excellent)' END AS credit_band,

    -- Debt-to-income band
    CASE WHEN l.dti < 0.30 THEN '1. < 30%'
         WHEN l.dti < 0.45 THEN '2. 30-45%'
         WHEN l.dti < 0.60 THEN '3. 45-60%'
         ELSE                   '4. 60%+' END AS dti_band,

    CASE WHEN c.age < 25 THEN '1. < 25' WHEN c.age < 35 THEN '2. 25-34'
         WHEN c.age < 45 THEN '3. 35-44' ELSE '4. 45+' END AS age_band,

    -- Seasoning rule: a loan only counts toward default rates once it is at least 6 months old
    -- (data as of 30-Sep-2026). Without this, recent vintages look artificially safe.
    CASE WHEN l.loan_status = 'Pending' THEN 0
         WHEN l.application_date > date('2026-09-30', '-6 months') THEN 0
         ELSE 1 END AS has_outcome
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id;
