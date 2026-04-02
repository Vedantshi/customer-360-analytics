USE Customer360;
GO

-- Total distinct invoices
DECLARE @total_invoices FLOAT = (
    SELECT COUNT(DISTINCT InvoiceNo) 
    FROM vw_cleaned_orders
);

-- Top 500 products by frequency
WITH top_products AS (
    SELECT TOP 500 Description
    FROM vw_cleaned_orders
    GROUP BY Description
    ORDER BY COUNT(DISTINCT InvoiceNo) DESC
),

-- Product pair frequency (filtered to top products only)
product_pairs AS (
    SELECT
        a.Description AS Product_A,
        b.Description AS Product_B,
        COUNT(DISTINCT a.InvoiceNo) AS times_bought_together
    FROM vw_cleaned_orders a
    JOIN vw_cleaned_orders b
        ON a.InvoiceNo = b.InvoiceNo
        AND a.StockCode < b.StockCode
    JOIN top_products ta ON a.Description = ta.Description
    JOIN top_products tb ON b.Description = tb.Description
    GROUP BY a.Description, b.Description
    HAVING COUNT(DISTINCT a.InvoiceNo) >= 10
),

-- Individual product frequency (only top products)
product_freq AS (
    SELECT Description, COUNT(DISTINCT InvoiceNo) AS product_invoices
    FROM vw_cleaned_orders
    WHERE Description IN (SELECT Description FROM top_products)
    GROUP BY Description
)

SELECT
    pp.Product_A,
    pp.Product_B,
    pp.times_bought_together,
    ROUND(pp.times_bought_together / @total_invoices, 6) AS support,
    ROUND(
        (pp.times_bought_together / @total_invoices) /
        ((pfa.product_invoices / @total_invoices) * (pfb.product_invoices / @total_invoices)),
    2) AS lift
INTO market_basket_pairs
FROM product_pairs pp
JOIN product_freq pfa ON pp.Product_A = pfa.Description
JOIN product_freq pfb ON pp.Product_B = pfb.Description
ORDER BY lift DESC;

-- Top 20 pairs
SELECT TOP 20 * 
FROM market_basket_pairs 
ORDER BY lift DESC;