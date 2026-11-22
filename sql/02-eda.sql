-- 1. Macro baseline (Monthly trends of revenue, gross profit and margin)
SELECT
  strftime(si.InvoiceDate::DATE, '%Y-%m') AS year_month,
  count(DISTINCT si.SalesInvoiceID) AS invoice_count,
  round(sum(sil.LineTotal), 2) AS total_revenue,
  round(sum(sil.Quantity * i.StandardCost), 2) AS total_cogs,
  round(sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost), 2) AS gross_profit,
  round(
          (sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost)) 
          / sum(sil.LineTotal) * 100, 2
      ) AS gross_margin_pct
FROM SalesInvoiceLine sil
JOIN SalesInvoice si ON sil.SalesInvoiceID = si.SalesInvoiceID
JOIN Item i ON sil.ItemID = i.ItemID
GROUP BY year_month
ORDER BY year_month;

-- 2. Product group profitability comparison
SELECT 
    i.ItemGroup,
    count(DISTINCT sil.SalesInvoiceID) AS invoice_occurrences,
    sum(sil.Quantity)                  AS total_units_sold,
    round(sum(sil.LineTotal), 2)       AS total_revenue,
    round(sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost), 2) AS gross_profit,
    round(
        (sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost)) 
        / sum(sil.LineTotal) * 100, 2
    ) AS gross_margin_pct
FROM SalesInvoiceLine sil
JOIN Item i ON sil.ItemID = i.ItemID
GROUP BY i.ItemGroup
ORDER BY total_revenue DESC;

-- 3. Customer segment profitability and growth levers
SELECT 
    c.CustomerSegment,
    count(DISTINCT c.CustomerID)      AS customer_count,
    count(DISTINCT si.SalesInvoiceID) AS invoice_count,
    round(sum(sil.LineTotal), 2)       AS total_revenue,
    round(sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost), 2) AS gross_profit,
    -- Profitability % of the segment:
    round(
        (sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost)) 
        / sum(sil.LineTotal) * 100, 2
    ) AS gross_margin_pct,
    -- Average revenue generated per customer:
    round(sum(sil.LineTotal) / count(DISTINCT c.CustomerID), 2) AS avg_revenue_per_customer
FROM SalesInvoiceLine sil
JOIN SalesInvoice si ON sil.SalesInvoiceID = si.SalesInvoiceID
JOIN Customer c ON si.CustomerID = c.CustomerID
JOIN Item i ON sil.ItemID = i.ItemID
GROUP BY c.CustomerSegment
ORDER BY gross_profit DESC;


-- 4. Check physical order size distribution (units per order)
WITH order_units AS (
    SELECT 
        SalesOrderID,
        sum(Quantity) AS total_units
    FROM SalesOrderLine
    GROUP BY SalesOrderID
)
SELECT 
    min(total_units)                  AS min_units,
    round(avg(total_units), 1)        AS avg_units,
    quantile_cont(total_units, 0.5)   AS median_units,
    quantile_cont(total_units, 0.9)   AS p90_units,
    max(total_units)                  AS max_units
FROM order_units;

-- Query: Physical order size tiers (units ordered), product group mix, and customer segmentation
WITH order_quantities AS (
    -- Step 1: Calculate total physical units ordered per SalesOrderID
    SELECT 
        so.SalesOrderID,
        so.CustomerID,
        sum(sol.Quantity) AS total_units_in_order,
        CASE 
            WHEN sum(sol.Quantity) <= 5 THEN '1. Small (1-5 units)'
            WHEN sum(sol.Quantity) BETWEEN 6 AND 20 THEN '2. Medium (6-20 units)'
            WHEN sum(sol.Quantity) BETWEEN 21 AND 50 THEN '3. Large (21-50 units)'
            ELSE '4. Bulk (> 50 units)'
        END AS quantity_tier
    FROM SalesOrder so
    JOIN SalesOrderLine sol ON so.SalesOrderID = sol.SalesOrderID
    GROUP BY so.SalesOrderID, so.CustomerID, so.OrderTotal
)
-- Step 2: Analyze product groups and customer segments across physical quantity tiers
SELECT 
    oq.quantity_tier,
    c.CustomerSegment,
    i.ItemGroup,
    count(DISTINCT oq.SalesOrderID) AS order_count,
    round(sum(sol.Quantity), 0)    AS total_units_sold,
    round(sum(sol.LineTotal), 2)   AS total_revenue,
    -- Average price per unit in this tier (reveals discounting on volume):
    round(sum(sol.LineTotal) / sum(sol.Quantity), 2) AS avg_price_per_unit
FROM order_quantities oq
JOIN Customer c ON oq.CustomerID = c.CustomerID
JOIN SalesOrderLine sol ON oq.SalesOrderID = sol.SalesOrderID
JOIN Item i ON sol.ItemID = i.ItemID
GROUP BY oq.quantity_tier, c.CustomerSegment, i.ItemGroup
ORDER BY oq.quantity_tier, total_revenue DESC;
