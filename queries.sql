DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions
(
    InvoiceNo   VARCHAR(20),
    StockCode   VARCHAR(20),
    Description VARCHAR(255),
    Quantity    INT,
    InvoiceDate DATETIME,
    UnitPrice   DECIMAL(10, 2),
    CustomerID  INT,
    Country     VARCHAR(100)
);

-- rfm holds the per-customer output of segmentation.ipynb (Recency,
-- Frequency, Monetary, Segment) — needed for queries 7 and 8 below, which
-- tie the SQL layer back to the clustering result.
DROP TABLE IF EXISTS rfm;
CREATE TABLE rfm
(
    CustomerID INT,
    Recency    INT,
    Frequency  INT,
    Monetary   DECIMAL(12, 2),
    Segment    INT
);


-- 8 Business Problems & Solutions


--1. Build RFM (Recency, Frequency, Monetary) features per customer

WITH snapshot AS (
    SELECT DATE_ADD(MAX(InvoiceDate), INTERVAL 1 DAY) AS snapshot_date
    FROM transactions
),
customer_orders AS (
    SELECT
        CustomerID,
        MAX(InvoiceDate)                    AS last_order,
        COUNT(DISTINCT InvoiceNo)           AS Frequency,
        ROUND(SUM(Quantity * UnitPrice), 2) AS Monetary
    FROM transactions
    GROUP BY CustomerID
)
SELECT
    co.CustomerID,
    DATEDIFF(s.snapshot_date, co.last_order) AS Recency,
    co.Frequency,
    co.Monetary
FROM customer_orders co
CROSS JOIN snapshot s
ORDER BY co.CustomerID;


--2. Monthly revenue trend

SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS month,
    ROUND(SUM(Quantity * UnitPrice), 2) AS revenue,
    COUNT(DISTINCT InvoiceNo) AS orders
FROM transactions
GROUP BY month
ORDER BY month;


--3. Top 10 products by revenue

SELECT
    Description,
    SUM(Quantity) AS units_sold,
    ROUND(SUM(Quantity * UnitPrice), 2) AS revenue
FROM transactions
GROUP BY Description
ORDER BY revenue DESC
LIMIT 10;


--4. Repeat-purchase rate (share of customers with more than one order)

SELECT
    ROUND(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS repeat_customer_pct
FROM (
    SELECT CustomerID, COUNT(DISTINCT InvoiceNo) AS order_count
    FROM transactions
    GROUP BY CustomerID
) AS customer_orders;


--5. Monthly cohort retention — raw counts (audit view)

WITH first_purchase AS (
    SELECT CustomerID, MIN(DATE_FORMAT(InvoiceDate, '%Y-%m')) AS cohort_month
    FROM transactions
    GROUP BY CustomerID
),
activity AS (
    SELECT DISTINCT CustomerID, DATE_FORMAT(InvoiceDate, '%Y-%m') AS order_month
    FROM transactions
)
SELECT
    fp.cohort_month,
    a.order_month,
    COUNT(DISTINCT a.CustomerID) AS active_customers
FROM activity a
JOIN first_purchase fp ON a.CustomerID = fp.CustomerID
GROUP BY fp.cohort_month, a.order_month
ORDER BY fp.cohort_month, a.order_month;


--6. Monthly cohort retention — as percentages, in pure SQL
--   (the notebook does this transform in pandas; here it's done entirely
--   with window functions instead — FIRST_VALUE() OVER (...) picks up each
--   cohort's own Month-0 count to divide by, no self-join needed)

WITH first_purchase AS (
    SELECT CustomerID, MIN(DATE_FORMAT(InvoiceDate, '%Y-%m')) AS cohort_month
    FROM transactions
    GROUP BY CustomerID
),
activity AS (
    SELECT DISTINCT CustomerID, DATE_FORMAT(InvoiceDate, '%Y-%m') AS order_month
    FROM transactions
),
cohort_counts AS (
    SELECT
        fp.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            STR_TO_DATE(CONCAT(fp.cohort_month, '-01'), '%Y-%m-%d'),
            STR_TO_DATE(CONCAT(a.order_month, '-01'), '%Y-%m-%d')
        ) AS month_offset,
        COUNT(DISTINCT a.CustomerID) AS active_customers
    FROM activity a
    JOIN first_purchase fp ON a.CustomerID = fp.CustomerID
    GROUP BY fp.cohort_month, month_offset
)
SELECT
    cohort_month,
    month_offset,
    active_customers,
    ROUND(
        100.0 * active_customers
        / FIRST_VALUE(active_customers) OVER (PARTITION BY cohort_month ORDER BY month_offset),
        1
    ) AS retention_pct
FROM cohort_counts
ORDER BY cohort_month, month_offset;


--7. Segment-level business KPIs (ties SQL directly to the clustering result)

SELECT
    Segment,
    COUNT(DISTINCT CustomerID) AS customers,
    ROUND(SUM(Monetary), 2) AS revenue,
    ROUND(100.0 * SUM(Monetary) / SUM(SUM(Monetary)) OVER (), 2) AS revenue_share_pct,
    ROUND(AVG(Monetary), 2) AS avg_customer_value
FROM rfm
GROUP BY Segment
ORDER BY revenue DESC;


--8. Top 3 highest-spending customers within each RFM segment
--   (window function: the query a marketing team would run to build a
--   "VIP Champions" contact list)

WITH ranked AS (
    SELECT
        CustomerID, Segment, Recency, Frequency, Monetary,
        RANK() OVER (PARTITION BY Segment ORDER BY Monetary DESC) AS rnk
    FROM rfm
)
SELECT CustomerID, Segment, Recency, Frequency, Monetary
FROM ranked
WHERE rnk <= 3
ORDER BY Segment, rnk;
