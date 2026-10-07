-- 03_segment_analysis.sql
-- Answers: "Which customer segment has the highest default probability?"
-- Rule: only loans WITH an outcome (not Pending) count toward default rate.

-- ---------- Portfolio baseline ----------
SELECT COUNT(*) AS loans, SUM(default_flag) AS defaults,
       ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM vw_loan_base WHERE has_outcome = 1;

-- ---------- One long table for ALL required cuts (feeds Power BI) ----------
DROP VIEW IF EXISTS vw_segment_default_rates;
CREATE VIEW vw_segment_default_rates AS
WITH base AS (
    SELECT * FROM vw_loan_base WHERE has_outcome = 1
),
portfolio AS (
    SELECT 1.0 * SUM(default_flag) / COUNT(*) AS port_rate FROM base
),
seg AS (
    SELECT 'Income Bracket'      AS dimension, income_bracket AS segment, loan_amount, default_flag FROM base
    UNION ALL SELECT 'Loan Type',          loan_type,               loan_amount, default_flag FROM base
    UNION ALL SELECT 'Employment Type',    employment_type,         loan_amount, default_flag FROM base
    UNION ALL SELECT 'Employment History', employment_history_band, loan_amount, default_flag FROM base
    UNION ALL SELECT 'State',              state,                   loan_amount, default_flag FROM base
    UNION ALL SELECT 'City Tier',          'Tier ' || city_tier,    loan_amount, default_flag FROM base
    UNION ALL SELECT 'Credit Band',        credit_band,             loan_amount, default_flag FROM base
    UNION ALL SELECT 'DTI Band',           dti_band,                loan_amount, default_flag FROM base
)
SELECT
    dimension,
    segment,
    COUNT(*)                                       AS loans,
    SUM(default_flag)                              AS defaults,
    ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct,
    ROUND((1.0 * SUM(default_flag) / COUNT(*)) / (SELECT port_rate FROM portfolio), 2) AS risk_lift,
    SUM(CASE WHEN default_flag = 1 THEN loan_amount END) AS defaulted_amount
FROM seg
GROUP BY dimension, segment;

SELECT * FROM vw_segment_default_rates ORDER BY dimension, segment;

-- ---------- Highest-risk single segments (min 200 loans so tiny groups don't mislead) ----------
SELECT dimension, segment, loans, default_rate_pct, risk_lift
FROM vw_segment_default_rates
WHERE loans >= 200
ORDER BY default_rate_pct DESC
LIMIT 10;

-- ---------- Highest-risk COMBINED segments (income x loan type x employment type) ----------
SELECT income_bracket, loan_type, employment_type,
       COUNT(*) AS loans, SUM(default_flag) AS defaults,
       ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM vw_loan_base
WHERE has_outcome = 1
GROUP BY income_bracket, loan_type, employment_type
HAVING COUNT(*) >= 100
ORDER BY default_rate_pct DESC
LIMIT 15;

-- ---------- Trend by application year (vintage) ----------
SELECT application_year, COUNT(*) AS loans,
       ROUND(100.0 * SUM(default_flag) / COUNT(*), 2) AS default_rate_pct
FROM vw_loan_base WHERE has_outcome = 1
GROUP BY application_year ORDER BY application_year;
