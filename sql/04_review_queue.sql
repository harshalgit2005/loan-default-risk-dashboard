-- 04_review_queue.sql
-- Answers: "Which applications should the credit team manually review?"
--
-- Logic (kept simple and explainable on purpose, credit teams need to defend decisions):
--   1. Estimate a segment-level default probability from historical loans
--      (income bracket x loan type x employment type), smoothed toward the portfolio rate
--      so small segments don't produce extreme numbers.
--   2. Add rule-based red flags on the individual applicant.
--   3. Route each PENDING application: Manual Review / Standard / Fast-Track.

-- ---------- Step 1: smoothed segment PD ----------
DROP VIEW IF EXISTS vw_segment_pd;
CREATE VIEW vw_segment_pd AS
WITH hist AS (
    SELECT * FROM vw_loan_base WHERE has_outcome = 1
),
port AS (
    SELECT 1.0 * SUM(default_flag) / COUNT(*) AS port_rate FROM hist
),
k AS (SELECT 50.0 AS prior_weight)   -- "pretend we've seen 50 extra loans at the portfolio rate"
SELECT
    h.income_bracket, h.loan_type, h.employment_type,
    COUNT(*)                    AS hist_loans,
    SUM(h.default_flag)         AS hist_defaults,
    ROUND((SUM(h.default_flag) + k.prior_weight * p.port_rate) / (COUNT(*) + k.prior_weight), 4) AS segment_pd
FROM hist h CROSS JOIN port p CROSS JOIN k
GROUP BY h.income_bracket, h.loan_type, h.employment_type;

-- ---------- Step 2 + 3: score pending applications ----------
DROP VIEW IF EXISTS vw_review_queue;
CREATE VIEW vw_review_queue AS
WITH port AS (
    SELECT 1.0 * SUM(default_flag) / COUNT(*) AS port_rate FROM vw_loan_base WHERE has_outcome = 1
),
scored AS (
    SELECT
        b.loan_id, b.customer_id, b.application_date, b.loan_type, b.loan_amount,
        b.income_bracket, b.employment_type, b.employment_history_band, b.state, b.city_tier,
        b.credit_score, b.dti, b.prior_delinquencies,
        COALESCE(s.segment_pd, p.port_rate)            AS segment_pd,
        COALESCE(s.segment_pd, p.port_rate) / p.port_rate AS pd_lift,
        -- red flags (1/0)
        CASE WHEN b.credit_score < 620          THEN 1 ELSE 0 END AS flag_low_credit,
        CASE WHEN b.dti >= 0.55                 THEN 1 ELSE 0 END AS flag_high_dti,
        CASE WHEN b.prior_delinquencies >= 2    THEN 1 ELSE 0 END AS flag_prior_delinq,
        CASE WHEN b.years_employed < 2          THEN 1 ELSE 0 END AS flag_thin_history
    FROM vw_loan_base b
    CROSS JOIN port p
    LEFT JOIN vw_segment_pd s
           ON s.income_bracket  = b.income_bracket
          AND s.loan_type       = b.loan_type
          AND s.employment_type = b.employment_type
    WHERE b.loan_status = 'Pending'
),
routed AS (
    SELECT *,
        (flag_low_credit + flag_high_dti + flag_prior_delinq + flag_thin_history) AS flag_count
    FROM scored
)
SELECT
    loan_id, customer_id, application_date, loan_type, loan_amount,
    income_bracket, employment_type, employment_history_band, state, city_tier,
    credit_score, dti, prior_delinquencies,
    ROUND(segment_pd, 4)  AS segment_pd,
    ROUND(pd_lift, 2)     AS pd_lift,
    flag_low_credit, flag_high_dti, flag_prior_delinq, flag_thin_history, flag_count,
    CASE
        WHEN pd_lift >= 1.8 OR flag_count >= 3                     THEN 'Manual Review'
        WHEN flag_count = 2 AND pd_lift >= 1.0                     THEN 'Manual Review'
        WHEN flag_count = 0 AND pd_lift <= 0.8                     THEN 'Fast-Track'
        ELSE                                                            'Standard'
    END AS recommended_route,
    -- reviewer queue ordering: bigger risk x bigger ticket first
    ROUND(segment_pd * loan_amount * (1 + 0.25 * flag_count), 0) AS priority_score
FROM routed;

-- ---------- Outputs ----------
-- Routing summary
SELECT recommended_route, COUNT(*) AS applications,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_queue,
       SUM(loan_amount) AS requested_amount
FROM vw_review_queue GROUP BY recommended_route ORDER BY applications DESC;

-- Top 25 applications for the credit team, highest priority first
SELECT loan_id, loan_type, loan_amount, income_bracket, employment_type,
       credit_score, dti, segment_pd, flag_count, priority_score
FROM vw_review_queue
WHERE recommended_route = 'Manual Review'
ORDER BY priority_score DESC
LIMIT 25;
