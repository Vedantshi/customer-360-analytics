-- =============================================================================
-- Script 04: Cohort Retention Analysis
-- Business Purpose: Track customer retention by acquisition cohort over time.
--   Each customer is assigned to the month they first purchased (their cohort).
--   We then track what % are still active at months 1, 2, 3... 12.
-- Key Finding: 61% of customers never return after their first purchase.
-- Dependency: vw_cleaned_orders (Script 01)
-- =============================================================================

USE Customer360;
GO

-- Step 1: Identify each customer's acquisition cohort (first purchase month)
WITH first_purchase AS (
    SELECT
        CustomerID,
        MIN(InvoiceDate) AS first_order_date,
        DATEFROMPARTS(YEAR(MIN(InvoiceDate)), MONTH(MIN(InvoiceDate)), 1) AS cohort_month
    FROM vw_cleaned_orders
    GROUP BY CustomerID
),

-- Step 2: For every transaction, calculate months since acquisition
cohort_activity AS (
    SELECT
        o.CustomerID,
        fp.cohort_month,
        DATEDIFF(MONTH, fp.cohort_month,
            DATEFROMPARTS(YEAR(o.InvoiceDate), MONTH(o.InvoiceDate), 1)) AS month_number,
        o.Revenue
    FROM vw_cleaned_orders o
    JOIN first_purchase fp ON o.CustomerID = fp.CustomerID
),

-- Step 3: Count distinct customers and revenue per cohort per month
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT CustomerID) AS cohort_customers
    FROM first_purchase
    GROUP BY cohort_month
)

SELECT
    ca.cohort_month,
    ca.month_number,
    cs.cohort_customers,
    COUNT(DISTINCT ca.CustomerID) AS active_customers,
    SUM(ca.Revenue) AS cohort_revenue,
    ROUND(COUNT(DISTINCT ca.CustomerID) * 100.0 / cs.cohort_customers, 2) AS retention_rate,
    ROUND(SUM(ca.Revenue) / cs.cohort_customers, 2) AS revenue_per_cohort_customer
FROM cohort_activity ca
JOIN cohort_size cs ON ca.cohort_month = cs.cohort_month
WHERE ca.month_number BETWEEN 0 AND 12
GROUP BY ca.cohort_month, ca.month_number, cs.cohort_customers
ORDER BY ca.cohort_month, ca.month_number;
