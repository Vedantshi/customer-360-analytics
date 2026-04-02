-- =============================================================================
-- Script 05: Churn & Gap Analysis
-- Business Purpose: Detect customers at risk of churning by measuring the
--   gaps between their purchases. Flags statistically unusual gaps using
--   Z-scores and creates a composite churn risk score (0-100).
-- Dependency: vw_cleaned_orders (Script 01), rfm_scores (Script 03)
-- =============================================================================

USE Customer360;
GO

-- Step 1: Use LEAD() to find each customer's next purchase date
WITH purchase_gaps AS (
    SELECT
        CustomerID,
        InvoiceDate,
        LEAD(InvoiceDate) OVER (PARTITION BY CustomerID ORDER BY InvoiceDate) AS next_purchase_date,
        DATEDIFF(DAY, InvoiceDate,
            LEAD(InvoiceDate) OVER (PARTITION BY CustomerID ORDER BY InvoiceDate)
        ) AS gap_days
    FROM vw_cleaned_orders
),

-- Step 2: Aggregate gap statistics per customer
customer_gaps AS (
    SELECT
        CustomerID,
        AVG(CAST(gap_days AS FLOAT)) AS avg_gap_days,
        MAX(gap_days) AS max_gap_days,
        STDEV(gap_days) AS stddev_gap_days,
        COUNT(*) AS total_purchases
    FROM purchase_gaps
    WHERE gap_days IS NOT NULL
    GROUP BY CustomerID
),

-- Step 3: Calculate Z-scores and churn risk
gap_zscore AS (
    SELECT
        cg.CustomerID,
        cg.avg_gap_days,
        cg.max_gap_days,
        cg.stddev_gap_days,
        cg.total_purchases,
        -- Z-score: how many std deviations is the max gap from the avg?
        CASE
            WHEN cg.stddev_gap_days > 0
            THEN (cg.max_gap_days - cg.avg_gap_days) / cg.stddev_gap_days
            ELSE 0
        END AS gap_zscore,
        rs.recency_days,
        rs.total_monetary_value,
        rs.rfm_segment
    FROM customer_gaps cg
    JOIN rfm_scores rs ON cg.CustomerID = rs.CustomerID
)

SELECT
    *,
    -- Composite churn risk score (0-100)
    -- Weights: Recency 40%, Gap Trend 30%, Value Decline 20%, Z-Score 10%
    CASE
        WHEN (
            (CASE WHEN recency_days > 180 THEN 40
                  WHEN recency_days > 90 THEN 25
                  WHEN recency_days > 30 THEN 10
                  ELSE 0 END)
            +
            (CASE WHEN max_gap_days > avg_gap_days * 2 THEN 30
                  WHEN max_gap_days > avg_gap_days * 1.5 THEN 20
                  WHEN max_gap_days > avg_gap_days THEN 10
                  ELSE 0 END)
            +
            (CASE WHEN total_monetary_value < 100 THEN 20
                  WHEN total_monetary_value < 500 THEN 10
                  ELSE 0 END)
            +
            (CASE WHEN gap_zscore > 2.0 THEN 10
                  WHEN gap_zscore > 1.0 THEN 5
                  ELSE 0 END)
        ) > 100 THEN 100
        ELSE (
            (CASE WHEN recency_days > 180 THEN 40
                  WHEN recency_days > 90 THEN 25
                  WHEN recency_days > 30 THEN 10
                  ELSE 0 END)
            +
            (CASE WHEN max_gap_days > avg_gap_days * 2 THEN 30
                  WHEN max_gap_days > avg_gap_days * 1.5 THEN 20
                  WHEN max_gap_days > avg_gap_days THEN 10
                  ELSE 0 END)
            +
            (CASE WHEN total_monetary_value < 100 THEN 20
                  WHEN total_monetary_value < 500 THEN 10
                  ELSE 0 END)
            +
            (CASE WHEN gap_zscore > 2.0 THEN 10
                  WHEN gap_zscore > 1.0 THEN 5
                  ELSE 0 END)
        )
    END AS churn_risk_score,
    -- Risk tier classification
    CASE
        WHEN recency_days > 90 THEN 'Churned'
        ELSE 'Active'
    END AS churn_status
INTO churn_analysis
FROM gap_zscore;

-- Add risk tier
ALTER TABLE churn_analysis ADD risk_tier VARCHAR(20);
UPDATE churn_analysis SET risk_tier =
    CASE
        WHEN churn_risk_score >= 70 THEN 'High Risk'
        WHEN churn_risk_score >= 40 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END;

-- Validation
SELECT risk_tier, COUNT(*) AS customer_count,
    AVG(churn_risk_score) AS avg_risk_score
FROM churn_analysis
GROUP BY risk_tier;
