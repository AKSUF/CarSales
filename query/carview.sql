call basictable('salesbasic','fact_sales','sales_price,total_price');
select * from salesbasic;
-- fiscal year view 
  
CREATE OR REPLACE VIEW vw_fiscal_cumulative_sales AS

WITH fiscal_monthly_sales AS (
    -- Step 1: Monthly aggregation
    SELECT 
        dd.fiscal_year,
        dd.fiscal_quarter,
        dd.fiscal_month,
        
        COUNT(fs.sk_sale) AS monthly_transactions,
        SUM(fs.units_sold) AS monthly_units_sold,
        SUM(fs.total_price) AS monthly_revenue,
        ROUND(AVG(fs.total_price), 2) AS monthly_avg_order_value
        
    FROM fact_sales fs
    INNER JOIN dim_date dd ON fs.fk_date_key = dd.date_key
    GROUP BY dd.fiscal_year, dd.fiscal_quarter, dd.fiscal_month
)

SELECT 
    fiscal_year,
    fiscal_quarter,
    fiscal_month,
    
    -- Monthly Metrics
    monthly_transactions,
    monthly_units_sold,
    monthly_revenue,
    monthly_avg_order_value,
    
    -- CUMULATIVE TOTALS (Year-to-Date)
    SUM(monthly_transactions) OVER (
        PARTITION BY fiscal_year 
        ORDER BY fiscal_month
    ) AS ytd_transactions,
    
    SUM(monthly_units_sold) OVER (
        PARTITION BY fiscal_year 
        ORDER BY fiscal_month
    ) AS ytd_units_sold,
    
    SUM(monthly_revenue) OVER (
        PARTITION BY fiscal_year 
        ORDER BY fiscal_month
    ) AS ytd_revenue,
    
    -- RUNNING AVERAGE
    ROUND(AVG(monthly_revenue) OVER (
        PARTITION BY fiscal_year 
        ORDER BY fiscal_month
    ), 2) AS ytd_avg_monthly_revenue,
    
    -- 3-MONTH MOVING AVERAGE
    ROUND(AVG(monthly_revenue) OVER (
        PARTITION BY fiscal_year 
        ORDER BY fiscal_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3month_avg_revenue,
    
    -- MONTH-OVER-MONTH GROWTH %
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (
            PARTITION BY fiscal_year 
            ORDER BY fiscal_month
        )) * 100.0 / NULLIF(LAG(monthly_revenue) OVER (
            PARTITION BY fiscal_year 
            ORDER BY fiscal_month
        ), 0), 
        2
    ) AS mom_growth_pct,
    
    -- YEAR-OVER-YEAR GROWTH %
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (
            PARTITION BY fiscal_month 
            ORDER BY fiscal_year
        )) * 100.0 / NULLIF(LAG(monthly_revenue) OVER (
            PARTITION BY fiscal_month 
            ORDER BY fiscal_year
        ), 0), 
        2
    ) AS yoy_growth_pct

FROM fiscal_monthly_sales
ORDER BY fiscal_year, fiscal_month;

-- car sold unit with total 
CREATE OR REPLACE VIEW sold_unit AS 
  SELECT fs.fk_sk_car,dc.car_id,dc.model,dc.year_model,dc.car_type,dc.base_price,dc.category,dc.transmission,dc.quantity_in_stock,
         SUM(units_sold) AS Number_of_unit,sum(total_price) as Revenue
  FROM fact_sales fs join dim_car dc on dc.sk_car=fs.fk_sk_car
  GROUP BY fk_sk_car;
  
-- revenue based top car
CREATE OR REPLACE VIEW sold_unit_revenue AS 
  SELECT fs.fk_sk_car,dc.car_id,dc.model,dc.year_model,dc.car_type,dc.base_price,dc.category,dc.transmission,dc.quantity_in_stock,
        sum(total_price) as Revenue
  FROM fact_sales fs join dim_car dc on dc.sk_car=fs.fk_sk_car
  GROUP BY fk_sk_car;
  
-- sold based top customer
CREATE OR REPLACE VIEW sold_based_customer AS
SELECT
  fs.fk_sk_customer,
  dc.sk_customer,
  dc.customer_id,
  dc.customer_name,
  dc.email,
  dc.age_group,
  dc.valid_from,
  dc.valid_to,
  dc.is_active,
  SUM(fs.units_sold) OVER () AS total_units_sold
FROM fact_sales fs
JOIN dim_customer dc ON fs.fk_sk_customer = dc.sk_customer;

-- revenue based top customer
CREATE OR REPLACE VIEW revenue_based_customer AS
SELECT
  fs.fk_sk_customer,
  dc.sk_customer,
  dc.customer_id,
  dc.customer_name,
  dc.email,
  dc.age_group,
  dc.valid_from,
  dc.valid_to,
  dc.is_active,
  SUM(fs.total_price) AS total_revenue
FROM fact_sales fs
JOIN dim_customer dc ON fs.fk_sk_customer = dc.sk_customer
GROUP BY fs.fk_sk_customer, dc.sk_customer, dc.customer_id, dc.customer_name,
         dc.email, dc.age_group, dc.valid_from, dc.valid_to, dc.is_active;


-- sold based top customer
CREATE OR REPLACE VIEW sold_based_customer AS
SELECT
  fs.fk_sk_customer,
  dc.sk_customer,
  dc.customer_id,
  dc.customer_name,
  dc.email,
  dc.age_group,
  dc.valid_from,
  dc.valid_to,
  dc.is_active,
  SUM(fs.units_sold) AS total_units_sold
FROM fact_sales fs
JOIN dim_customer dc ON fs.fk_sk_customer = dc.sk_customer
GROUP BY fs.fk_sk_customer, dc.sk_customer, dc.customer_id, dc.customer_name,
         dc.email, dc.age_group, dc.valid_from, dc.valid_to, dc.is_active;

CREATE OR REPLACE VIEW vw_margin_analysis AS
SELECT 
    fs.sk_sale,
    dc.sk_car,
    dc.car_id,
    dc.model,
    dd.date_key,
    dd.fiscal_year,
    dd.fiscal_quarter,
    fs.salesperson,
    
    -- Prices
    fs.sales_price,
    dc.base_price,
    
    -- Margin calculations
    ROUND(fs.sales_price - dc.base_price, 2) AS margin_amount,
    ROUND(((fs.sales_price - dc.base_price) * 100.0) / NULLIF(dc.base_price, 0), 2) AS margin_pct,
    
    -- Margin classification (handles both positive and negative)
    CASE 
        WHEN fs.sales_price >= dc.base_price * 1.30 THEN 'A. Premium (30%+ above base)'
        WHEN fs.sales_price >= dc.base_price * 1.10 THEN 'B. High Margin (10-30% above)'
        WHEN fs.sales_price >= dc.base_price * 0.95 THEN 'C. Near Base (±5%)'
        WHEN fs.sales_price >= dc.base_price * 0.80 THEN 'D. Small Discount (5-20% off)'
        WHEN fs.sales_price >= dc.base_price * 0.60 THEN 'E. Moderate Discount (20-40% off)'
        WHEN fs.sales_price >= dc.base_price * 0.40 THEN 'F. Heavy Discount (40-60% off)'
        ELSE 'G. Deep Discount (60%+ off)'
    END AS margin_class,
    
    -- Simplified 3-tier classification
    CASE 
        WHEN fs.sales_price >= dc.base_price THEN 'Profitable'
        WHEN fs.sales_price >= dc.base_price * 0.80 THEN 'Acceptable'
        ELSE 'Loss/Heavy Discount'
    END AS margin_tier,
    
    -- Performance flag
    CASE 
        WHEN fs.sales_price >= dc.base_price * 1.10 THEN '✓ Above Target'
        WHEN fs.sales_price >= dc.base_price * 0.90 THEN '○ Within Range'
        ELSE '✗ Below Target'
    END AS performance_flag,
    
    -- Additional context
    fs.payment_method,
    fs.units_sold,
    fs.total_price

FROM fact_sales fs 
JOIN dim_car dc ON dc.sk_car = fs.fk_sk_car
JOIN dim_date dd ON dd.date_key = fs.fk_date_key;


-- stock level analysis view
create or replace view vw_stock_analysis as
select 
dc.sk_car,
dc.car_id,
dc.model,
dc.transmission,
dc.category,
dc.base_price,
dc.quantity_in_stock as current_stock,
dd.fiscal_year,
dd.fiscal_month,
case 
when dc.quantity_in_stock = 0 then '🔴Out of stock'
when dc.quantity_in_stock <= 2 then '🟠critical'
when dc.quantity_in_stock <= 5 then '🟢 low'
when dc.quantity_in_stock <= 10 then '🟢moderate'
when dc.quantity_in_stock <= 20 then '🔵Good' 
else 'Overstock'
end as stock_status
from dim_car dc 
join fact_sales fs on fs.fk_sk_car = dc.sk_car 
join dim_date dd on dd.date_key = fs.fk_date_key ;




select * from fact_sales;
select * from dim_customer;
select * from dim_car;
select * from dim_date;
  select * from sold_unit_revenue;
  show tables;
drop view  salesbasic;