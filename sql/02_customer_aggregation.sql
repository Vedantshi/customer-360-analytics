-- =============================================================================
-- Script 02: Customer-Level Aggregation
-- Business Purpose: Create a single row per customer with key behavioural
--   metrics. This is the foundation of RFM scoring and all customer analytics.
-- =============================================================================

USE Customer360;
GO

DROP TABLE IF EXISTS rfm_base;

DECLARE @reference_date DATE = '2011-12-31';

SELECT
    CustomerID,
    MAX(InvoiceDate) AS last_purchase_date,
    MIN(InvoiceDate) AS first_purchase_date,
    COUNT(DISTINCT InvoiceNo) AS purchase_frequency,
    SUM(Revenue) AS total_monetary_value,
    AVG(Revenue) AS avg_order_value,
    DATEDIFF(DAY, MAX(InvoiceDate), @reference_date) AS recency_days,
    DATEDIFF(DAY, MIN(InvoiceDate), MAX(InvoiceDate)) 
        AS customer_lifespan_days
INTO rfm_base
FROM vw_cleaned_orders  -- FIXED: was online_retail in original
GROUP BY CustomerID;

-- Validation
SELECT COUNT(*) AS customer_count FROM rfm_base;
SELECT TOP 5 CustomerID FROM rfm_base ORDER BY CustomerID;
SELECT
    AVG(recency_days) AS avg_recency,
    AVG(purchase_frequency) AS avg_frequency,
    AVG(total_monetary_value) AS avg_monetary
FROM rfm_base;