CREATE TABLE dim_customer (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    city VARCHAR(50),
    age_group VARCHAR(20),
    acquisition_channel VARCHAR(50)
);

CREATE TABLE dim_product (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10,2)
);

CREATE TABLE dim_merchant (
    merchant_id SERIAL PRIMARY KEY,
    merchant_name VARCHAR(100),
    city VARCHAR(50),
    category VARCHAR(50)
);

CREATE TABLE dim_date (
    date_id SERIAL PRIMARY KEY,
    date DATE,
    day INT,
    month INT,
    quarter INT,
    year INT,
    is_weekend BOOLEAN
);

CREATE TABLE fact_transactions (
    transaction_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES dim_customer(customer_id),
    product_id INT REFERENCES dim_product(product_id),
    merchant_id INT REFERENCES dim_merchant(merchant_id),
    date_id INT REFERENCES dim_date(date_id),
    amount DECIMAL(10,2),
    payment_method VARCHAR(30),
    status VARCHAR(20)
);

SELECT COUNT(*) FROM fact_transactions;


CREATE VIEW vw_monthly_revenue AS
SELECT 
    d.year,
    d.month,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_transaction_value
FROM fact_transactions t
JOIN dim_date d ON t.date_id = d.date_id
WHERE t.status = 'Success'
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

SELECT * FROM vw_monthly_revenue LIMIT 5;

CREATE VIEW vw_revenue_by_category AS
SELECT 
    p.category,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_order_value,
    ROUND(SUM(t.amount) * 100.0 / SUM(SUM(t.amount)) OVER (), 2) AS revenue_share_pct
FROM fact_transactions t
JOIN dim_product p ON t.product_id = p.product_id
WHERE t.status = 'Success'
GROUP BY p.category
ORDER BY total_revenue DESC;

SELECT * FROM vw_revenue_by_category;

CREATE VIEW vw_top_customers AS
SELECT 
    c.customer_id,
    c.name,
    c.city,
    c.acquisition_channel,
    COUNT(t.transaction_id) AS total_orders,
    SUM(t.amount) AS total_spent,
    AVG(t.amount) AS avg_order_value,
    MIN(d.date) AS first_purchase,
    MAX(d.date) AS last_purchase
FROM fact_transactions t
JOIN dim_customer c ON t.customer_id = c.customer_id
JOIN dim_date d ON t.date_id = d.date_id
WHERE t.status = 'Success'
GROUP BY c.customer_id, c.name, c.city, c.acquisition_channel
ORDER BY total_spent DESC
LIMIT 10;

SELECT * FROM vw_top_customers;

CREATE VIEW vw_churn_segments AS
SELECT 
    c.customer_id,
    c.name,
    c.city,
    MAX(d.date) AS last_purchase_date,
    CURRENT_DATE - MAX(d.date) AS days_since_last_purchase,
    CASE 
        WHEN CURRENT_DATE - MAX(d.date) <= 30 THEN 'Active'
        WHEN CURRENT_DATE - MAX(d.date) <= 90 THEN 'At Risk'
        WHEN CURRENT_DATE - MAX(d.date) <= 180 THEN 'Churning'
        ELSE 'Churned'
    END AS churn_segment
FROM fact_transactions t
JOIN dim_customer c ON t.customer_id = c.customer_id
JOIN dim_date d ON t.date_id = d.date_id
WHERE t.status = 'Success'
GROUP BY c.customer_id, c.name, c.city
ORDER BY days_since_last_purchase ASC;

SELECT churn_segment, COUNT(*) FROM vw_churn_segments GROUP BY churn_segment;


CREATE VIEW vw_customer_ltv AS
SELECT 
    c.customer_id,
    c.name,
    c.city,
    c.acquisition_channel,
    COUNT(t.transaction_id) AS total_orders,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_order_value,
    MAX(d.date) - MIN(d.date) AS customer_lifespan_days,
    ROUND(SUM(t.amount) / NULLIF(MAX(d.date) - MIN(d.date), 0), 2) AS revenue_per_day,
    CASE
        WHEN SUM(t.amount) >= 50000 THEN 'Platinum'
        WHEN SUM(t.amount) >= 20000 THEN 'Gold'
        WHEN SUM(t.amount) >= 5000 THEN 'Silver'
        ELSE 'Bronze'
    END AS ltv_tier
FROM fact_transactions t
JOIN dim_customer c ON t.customer_id = c.customer_id
JOIN dim_date d ON t.date_id = d.date_id
WHERE t.status = 'Success'
GROUP BY c.customer_id, c.name, c.city, c.acquisition_channel
ORDER BY total_revenue DESC;

SELECT ltv_tier, COUNT(*), 
SUM(total_revenue) FROM vw_customer_ltv GROUP BY ltv_tier ORDER BY SUM(total_revenue) DESC;

CREATE VIEW vw_acquisition_channel AS
SELECT 
    c.acquisition_channel,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.amount) AS total_revenue,
    ROUND(SUM(t.amount) / COUNT(DISTINCT c.customer_id), 2) AS revenue_per_customer,
    ROUND(COUNT(t.transaction_id)::DECIMAL / COUNT(DISTINCT c.customer_id), 2) AS avg_orders_per_customer
FROM fact_transactions t
JOIN dim_customer c ON t.customer_id = c.customer_id
WHERE t.status = 'Success'
GROUP BY c.acquisition_channel
ORDER BY revenue_per_customer DESC;

SELECT * FROM vw_acquisition_channel;

CREATE VIEW vw_payment_analysis AS
SELECT 
    payment_method,
    COUNT(transaction_id) AS total_transactions,
    SUM(amount) AS total_revenue,
    AVG(amount) AS avg_transaction_value,
    ROUND(COUNT(transaction_id) * 100.0 / SUM(COUNT(transaction_id)) OVER (), 2) AS usage_share_pct,
    COUNT(CASE WHEN status = 'Failed' THEN 1 END) AS failed_transactions,
    ROUND(COUNT(CASE WHEN status = 'Failed' THEN 1 END) * 100.0 / COUNT(transaction_id), 2) AS failure_rate_pct
FROM fact_transactions
GROUP BY payment_method
ORDER BY total_transactions DESC;

SELECT * FROM vw_payment_analysis ORDER BY total_revenue DESC;

CREATE VIEW vw_weekend_vs_weekday AS
SELECT 
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_transaction_value,
    ROUND(COUNT(t.transaction_id) * 100.0 / SUM(COUNT(t.transaction_id)) OVER (), 2) AS transaction_share_pct
FROM fact_transactions t
JOIN dim_date d ON t.date_id = d.date_id
WHERE t.status = 'Success'
GROUP BY d.is_weekend
ORDER BY total_revenue DESC;

SELECT * FROM vw_weekend_vs_weekday;

CREATE VIEW vw_top_merchants AS
SELECT 
    m.merchant_id,
    m.merchant_name,
    m.city,
    m.category,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_transaction_value,
    ROUND(SUM(t.amount) * 100.0 / SUM(SUM(t.amount)) OVER (), 2) AS revenue_share_pct,
    COUNT(DISTINCT t.customer_id) AS unique_customers
FROM fact_transactions t
JOIN dim_merchant m ON t.merchant_id = m.merchant_id
WHERE t.status = 'Success'
GROUP BY m.merchant_id, m.merchant_name, m.city, m.category
ORDER BY total_revenue DESC
LIMIT 10;

SELECT * FROM vw_top_merchants;

CREATE VIEW vw_quarterly_growth AS
WITH quarterly_revenue AS (
    SELECT 
        d.year,
        d.quarter,
        SUM(t.amount) AS total_revenue,
        COUNT(t.transaction_id) AS total_transactions
    FROM fact_transactions t
    JOIN dim_date d ON t.date_id = d.date_id
    WHERE t.status = 'Success'
    GROUP BY d.year, d.quarter
)
SELECT 
    year,
    quarter,
    total_revenue,
    total_transactions,
    LAG(total_revenue) OVER (ORDER BY year, quarter) AS prev_quarter_revenue,
    ROUND((total_revenue - LAG(total_revenue) OVER (ORDER BY year, quarter)) * 100.0 / 
    NULLIF(LAG(total_revenue) OVER (ORDER BY year, quarter), 0), 2) AS revenue_growth_pct
FROM quarterly_revenue
ORDER BY year, quarter;

SELECT * FROM vw_quarterly_growth;


CREATE VIEW vw_cohort_retention AS
WITH first_purchase AS (
    SELECT 
        t.customer_id,
        DATE_TRUNC('month', MIN(d.date)) AS cohort_month
    FROM fact_transactions t
    JOIN dim_date d ON t.date_id = d.date_id
    WHERE t.status = 'Success'
    GROUP BY t.customer_id
),
customer_activity AS (
    SELECT 
        t.customer_id,
        DATE_TRUNC('month', d.date) AS activity_month
    FROM fact_transactions t
    JOIN dim_date d ON t.date_id = d.date_id
    WHERE t.status = 'Success'
    GROUP BY t.customer_id, DATE_TRUNC('month', d.date)
)
SELECT 
    fp.cohort_month,
    COUNT(DISTINCT fp.customer_id) AS cohort_size,
    COUNT(DISTINCT ca.customer_id) AS retained_customers,
    ROUND(COUNT(DISTINCT ca.customer_id) * 100.0 / COUNT(DISTINCT fp.customer_id), 2) AS retention_rate_pct
FROM first_purchase fp
LEFT JOIN customer_activity ca ON fp.customer_id = ca.customer_id
AND ca.activity_month > fp.cohort_month
GROUP BY fp.cohort_month
ORDER BY fp.cohort_month;

SELECT * FROM vw_cohort_retention LIMIT 10;


CREATE VIEW vw_city_revenue AS
SELECT 
    c.city,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_transaction_value,
    ROUND(SUM(t.amount) / COUNT(DISTINCT c.customer_id), 2) AS revenue_per_customer,
    ROUND(SUM(t.amount) * 100.0 / SUM(SUM(t.amount)) OVER (), 2) AS city_revenue_share_pct,
    COUNT(CASE WHEN t.status = 'Failed' THEN 1 END) AS failed_transactions,
    ROUND(COUNT(CASE WHEN t.status = 'Failed' THEN 1 END) * 100.0 / 
    COUNT(t.transaction_id), 2) AS failure_rate_pct
FROM fact_transactions t
JOIN dim_customer c ON t.customer_id = c.customer_id
GROUP BY c.city
ORDER BY total_revenue DESC;

SELECT * FROM vw_city_revenue;


CREATE OR REPLACE VIEW vw_churn_segments AS
SELECT 
    c.customer_id,
    c.name,
    c.city,
    MAX(d.date) AS last_purchase_date,
    DATE '2025-01-01' - MAX(d.date) AS days_since_last_purchase,
    CASE 
        WHEN DATE '2025-01-01' - MAX(d.date) <= 30 THEN 'Active'
        WHEN DATE '2025-01-01' - MAX(d.date) <= 90 THEN 'At Risk'
        WHEN DATE '2025-01-01' - MAX(d.date) <= 180 THEN 'Churning'
        ELSE 'Churned'
    END AS churn_segment
FROM fact_transactions t
JOIN dim_customer c ON t.customer_id = c.customer_id
JOIN dim_date d ON t.date_id = d.date_id
WHERE t.status = 'Success'
GROUP BY c.customer_id, c.name, c.city
ORDER BY days_since_last_purchase ASC;