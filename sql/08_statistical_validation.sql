-- =============================================================================
-- Script 08: Statistical Validation
-- Business Purpose: Prove that RFM segment differences are statistically
--   significant, not random groupings. Uses chi-square independence test
--   and two-sample t-test with Cohen's d effect size.
-- Dependency: rfm_scores (Script 03), churn_analysis (Script 05)
-- =============================================================================

USE Customer360;
GO

-- =============================================
-- TEST 1: Chi-Square Test of Independence
-- H0: Churn rate is independent of RFM segment
-- H1: Churn rate depends on RFM segment
-- =============================================

-- Observed frequencies: segment x churn status cross-tabulation
WITH observed AS (
    SELECT
        rs.rfm_segment,
        ca.churn_status,
        COUNT(*) AS observed_count
    FROM rfm_scores rs
    JOIN churn_analysis ca ON rs.CustomerID = ca.CustomerID
    GROUP BY rs.rfm_segment, ca.churn_status
),
-- Row and column totals
row_totals AS (
    SELECT rfm_segment, SUM(observed_count) AS row_total
    FROM observed GROUP BY rfm_segment
),
col_totals AS (
    SELECT churn_status, SUM(observed_count) AS col_total
    FROM observed GROUP BY churn_status
),
grand AS (
    SELECT SUM(observed_count) AS grand_total FROM observed
),
-- Expected frequencies under independence assumption
expected AS (
    SELECT
        o.rfm_segment,
        o.churn_status,
        o.observed_count,
        (rt.row_total * ct.col_total * 1.0 / g.grand_total) AS expected_count
    FROM observed o
    JOIN row_totals rt ON o.rfm_segment = rt.rfm_segment
    JOIN col_totals ct ON o.churn_status = ct.churn_status
    CROSS JOIN grand g
)
-- Chi-square statistic
SELECT
    SUM(POWER(observed_count - expected_count, 2) / expected_count) AS chi_square_statistic,
    (SELECT (COUNT(DISTINCT rfm_segment) - 1) * (COUNT(DISTINCT churn_status) - 1)
     FROM observed) AS degrees_of_freedom,
    -- Critical value for df=8 (9 segments - 1) x (2 statuses - 1) at alpha=0.05
    15.507 AS critical_value_005
FROM expected;
-- If chi_square_statistic > 15.507, reject H0 (segments matter)

-- =============================================
-- TEST 2: Two-Sample T-Test (Champion vs At Risk AOV)
-- H0: Mean AOV of Champions = Mean AOV of At Risk
-- H1: Mean AOV of Champions != Mean AOV of At Risk
-- =============================================

WITH champion AS (
    SELECT avg_order_value AS aov FROM rfm_scores WHERE rfm_segment = 'Champion'
),
at_risk AS (
    SELECT avg_order_value AS aov FROM rfm_scores WHERE rfm_segment = 'At Risk'
),
stats AS (
    SELECT
        (SELECT AVG(aov) FROM champion) AS mean_champion,
        (SELECT AVG(aov) FROM at_risk) AS mean_atrisk,
        (SELECT STDEV(aov) FROM champion) AS sd_champion,
        (SELECT STDEV(aov) FROM at_risk) AS sd_atrisk,
        (SELECT COUNT(*) FROM champion) AS n_champion,
        (SELECT COUNT(*) FROM at_risk) AS n_atrisk
)
SELECT
    mean_champion,
    mean_atrisk,
    sd_champion,
    sd_atrisk,
    n_champion,
    n_atrisk,
    -- T-statistic (Welch's t-test)
    (mean_champion - mean_atrisk) /
        SQRT((POWER(sd_champion, 2) / n_champion) + (POWER(sd_atrisk, 2) / n_atrisk))
    AS t_statistic,
    -- Cohen's d (effect size)
    (mean_champion - mean_atrisk) /
        SQRT((POWER(sd_champion, 2) + POWER(sd_atrisk, 2)) / 2)
    AS cohens_d,
    -- Interpretation guides
    CASE
        WHEN ABS((mean_champion - mean_atrisk) /
            SQRT((POWER(sd_champion, 2) / n_champion) + (POWER(sd_atrisk, 2) / n_atrisk)))
            > 1.96 THEN 'Significant at p < 0.05'
        ELSE 'Not significant'
    END AS significance,
    CASE
        WHEN ABS((mean_champion - mean_atrisk) /
            SQRT((POWER(sd_champion, 2) + POWER(sd_atrisk, 2)) / 2)) >= 0.8 THEN 'Large effect'
        WHEN ABS((mean_champion - mean_atrisk) /
            SQRT((POWER(sd_champion, 2) + POWER(sd_atrisk, 2)) / 2)) >= 0.5 THEN 'Medium effect'
        WHEN ABS((mean_champion - mean_atrisk) /
            SQRT((POWER(sd_champion, 2) + POWER(sd_atrisk, 2)) / 2)) >= 0.2 THEN 'Small effect'
        ELSE 'Negligible effect'
    END AS effect_size_interpretation
FROM stats;
