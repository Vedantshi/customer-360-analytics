-- =============================================================================
-- Script 01: Data Cleaning & Base Table
-- Business Purpose: Create a clean, validated base table that all downstream
--   analysis queries will reference. Documents every data quality decision.
-- Input: online_retail (raw import from cleaned CSV)
-- Output: VIEW vw_cleaned_orders
-- =============================================================================

USE Customer360;
GO

-- Audit: Count rows before cleaning
SELECT COUNT(*) AS raw_row_count FROM online_retail;
-- Expected: ~800,000 (already pre-cleaned by Python)

-- Create the cleaned orders view
-- Using a VIEW (not a table) so it always reflects the latest data
GO
CREATE OR ALTER VIEW vw_cleaned_orders AS
SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    CAST(InvoiceDate AS DATE) AS InvoiceDate,
    UnitPrice,
    CAST(CustomerID AS INT) AS CustomerID,
    Country,
    Quantity * UnitPrice AS Revenue
FROM online_retail
WHERE CustomerID IS NOT NULL          -- Remove null customer IDs
    AND InvoiceNo NOT LIKE 'C%'       -- Remove cancellations
    AND Quantity > 0                   -- Remove returns (negative qty)
    AND UnitPrice > 0;                -- Remove free samples / errors
GO

-- Validation: Count cleaned rows
SELECT COUNT(*) AS cleaned_row_count FROM vw_cleaned_orders;
SELECT COUNT(DISTINCT CustomerID) AS unique_customers FROM vw_cleaned_orders;
SELECT COUNT(DISTINCT InvoiceNo) AS unique_invoices FROM vw_cleaned_orders;
SELECT MIN(InvoiceDate) AS earliest, MAX(InvoiceDate) AS latest FROM vw_cleaned_orders;