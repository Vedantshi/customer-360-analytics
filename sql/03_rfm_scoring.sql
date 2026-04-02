-- =============================================================================
-- Script 03: RFM Scoring Engine
-- Business Purpose: Assign every customer a 1-5 score on three dimensions:
--   Recency (how recently they bought), Frequency (how often), and
--   Monetary (how much they spend). Map scores to business segment labels.
-- Dependency: rfm_base (Script 02)
-- =============================================================================

USE Customer360;
GO

DROP TABLE IF EXISTS rfm_scores;

-- Step 1: Apply NTILE(5) scoring
-- NTILE divides customers into 5 equal buckets for each dimension
WITH rfm_ntile AS (
    SELECT
        CustomerID,
        recency_days,
        purchase_frequency,
        total_monetary_value,
        avg_order_value,
        customer_lifespan_days,
        -- Recency: lower days = more recent = HIGHER score
        -- So we order ASC (fewest days first = bucket 5)
        NTILE(5) OVER (ORDER BY recency_days ASC) AS R_Score,
        -- Frequency: higher frequency = HIGHER score
        NTILE(5) OVER (ORDER BY purchase_frequency DESC) AS F_Score,
        -- Monetary: higher spend = HIGHER score
        NTILE(5) OVER (ORDER BY total_monetary_value DESC) AS M_Score
    FROM rfm_base
)

-- Step 2: Create segment labels based on score combinations
SELECT
    *,
    -- Concatenate scores for reference (e.g., '555', '213')
    CAST(R_Score AS VARCHAR) + CAST(F_Score AS VARCHAR) + CAST(M_Score AS VARCHAR) AS rfm_code,
    -- Sum for overall score (range: 3 to 15)
    R_Score + F_Score + M_Score AS rfm_total_score,
    -- Business segment mapping
    CASE
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champion'
        WHEN R_Score <= 2 AND F_Score >= 4 AND M_Score >= 4 THEN 'Cannot Lose'
        WHEN F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customer'
        WHEN R_Score >= 4 AND F_Score = 1 THEN 'New Customer'
        WHEN R_Score >= 3 AND F_Score >= 2 AND M_Score >= 2 THEN 'Potential Loyalist'
        WHEN R_Score = 3 AND F_Score = 2 AND M_Score = 2 THEN 'Needs Attention'
        WHEN R_Score = 2 AND F_Score >= 2 AND M_Score >= 2 THEN 'At Risk'
        WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Hibernating'
        WHEN R_Score = 1 AND F_Score = 1 THEN 'Lost'
        ELSE 'Other'
    END AS rfm_segment
INTO rfm_scores
FROM rfm_ntile;

-- Validation: Segment distribution
SELECT
    rfm_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_monetary_value), 2) AS avg_monetary,
    ROUND(AVG(CAST(recency_days AS FLOAT)), 0) AS avg_recency_days
FROM rfm_scores
GROUP BY rfm_segment
ORDER BY avg_monetary DESC;
