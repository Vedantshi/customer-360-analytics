-- =============================================================================
-- Script 06: Pareto / Revenue Concentration
-- Business Purpose: Identify what % of customers drive 80% of revenue.
--   Uses running SUM window function and RANK().
-- Key Finding: ~18% of customers drive ~79% of revenue.
-- Dependency: vw_cleaned_orders (Script 01)
-- =============================================================================

USE Customer360;
GO

WITH customer_revenue AS (
    SELECT
        CustomerID,
        SUM(Revenue) AS total_revenue
    FROM vw_cleaned_orders
    GROUP BY CustomerID
),
ranked AS (
    SELECT
        CustomerID,
        total_revenue,
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS running_total,
        SUM(total_revenue) OVER () AS grand_total
    FROM customer_revenue
)
SELECT
    *,
    ROUND(running_total * 100.0 / grand_total, 2) AS cumulative_pct,
    ROUND(revenue_rank * 100.0 / (SELECT COUNT(*) FROM customer_revenue), 2) AS customer_pct,
    CASE
        WHEN revenue_rank <= (SELECT COUNT(*) * 0.05 FROM customer_revenue) THEN 'Platinum'
        WHEN revenue_rank <= (SELECT COUNT(*) * 0.20 FROM customer_revenue) THEN 'Gold'
        WHEN revenue_rank <= (SELECT COUNT(*) * 0.50 FROM customer_revenue) THEN 'Silver'
        ELSE 'Bronze'
    END AS value_tier
INTO pareto_analysis
FROM ranked;

-- Find the exact 80% crossover point
SELECT TOP 1 revenue_rank, customer_pct, cumulative_pct
FROM pareto_analysis
WHERE cumulative_pct >= 80
ORDER BY revenue_rank;

-- Tier summary
SELECT value_tier, COUNT(*) AS customers, SUM(total_revenue) AS tier_revenue
FROM pareto_analysis GROUP BY value_tier ORDER BY tier_revenue DESC;
