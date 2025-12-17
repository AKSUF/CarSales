select * from fact_sales;
select * from sales;
select min(sale_date),max(sale_date) from fact_sales;
-- Sales identifier analysis
select * from salesbasic;

-- outlier flaggin of price
with sales_price as(
select sk_sale,sales_price , 
(sales_price - avg(sales_price)over ())/ stddev_samp(sales_price) over() as z_score_price 
from fact_sales
)
select sales_price,z_score_price from sales_price where 
abs(z_score_price) <= 1 
order by z_score_price desc ;


-- Step 1: Calculate z-scores and assign price segments for each sale by year
WITH price_zscore AS (
    SELECT 
        fs.sk_sale,
        fs.fk_sk_car,
        dc.car_id,
        dc.model,
        fs.sales_price,
        dd.year,
        
        -- Calculate z-score within each year for year-over-year comparison
        (fs.sales_price - AVG(fs.sales_price) OVER (PARTITION BY dd.year)) / 
        NULLIF(STDDEV_SAMP(fs.sales_price) OVER (PARTITION BY dd.year), 0) AS z_score_year
        
    FROM fact_sales fs
    INNER JOIN dim_date dd ON fs.fk_date_key = dd.date_key
    INNER JOIN dim_car dc ON fs.fk_sk_car = dc.sk_car
),

-- Step 2: Categorize z-scores into segments
price_segments AS (
    SELECT 
        car_id,
        model,
        year,
        sales_price,
        z_score_year,
        CASE 
            WHEN z_score_year < -1.50 THEN '1. Very Low (< -1.50)'
            WHEN z_score_year >= -1.50 AND z_score_year < -1.00 THEN '2. Low (-1.50 to -1.00)'
            WHEN z_score_year >= -1.00 AND z_score_year < -0.50 THEN '3. Below Average (-1.00 to -0.50)'
            WHEN z_score_year >= -0.50 AND z_score_year < 0.50 THEN '4. Average (-0.50 to 0.50)'
            WHEN z_score_year >= 0.50 AND z_score_year < 1.00 THEN '5. Above Average (0.50 to 1.00)'
            WHEN z_score_year >= 1.00 AND z_score_year < 1.50 THEN '6. High (1.00 to 1.50)'
            WHEN z_score_year >= 1.50 THEN '7. Very High (>= 1.50)'
            ELSE '8. Unknown'
        END AS price_segment
    FROM price_zscore
)

-- Step 3: Pivot - Segments as rows, Years as columns
SELECT 
    price_segment AS 'Segment',
    
    -- Count of cars in each segment by year
    SUM(CASE WHEN year = 2022 THEN 1 ELSE 0 END) AS '2022 Number of Transitions',
    SUM(CASE WHEN year = 2023 THEN 1 ELSE 0 END) AS '2023 Number of Transitions',
    SUM(CASE WHEN year = 2024 THEN 1 ELSE 0 END) AS '2024 Number of Transitions',
    SUM(CASE WHEN year = 2025 THEN 1 ELSE 0 END) AS '2025 Number of Transitions',
    
    -- Total across all years
    COUNT(*) AS 'Total Transitions',
    
    -- Average price in this segment
    ROUND(AVG(sales_price), 2) AS 'Avg Price ($)',
    
    -- Percentage distribution
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS 'Overall %';
    
    
    -- yearly which type of car sold together as basket analysis
   select payment_method ,year(sale_date) as sale_date,count(*) from fact_sales group by payment_method,year(sale_date) ;
   
-- payment method used all over the year
   SELECT 
    COALESCE(payment_method, 'TOTAL') AS payment_method,
    SUM(CASE WHEN YEAR(sale_date) = 2022 THEN 1 ELSE 0 END) AS '2022 count of transaction',
    SUM(CASE WHEN YEAR(sale_date) = 2023 THEN 1 ELSE 0 END) AS '2023 count of transaction',
    SUM(CASE WHEN YEAR(sale_date) = 2024 THEN 1 ELSE 0 END) AS '2024 count of transaction',
    SUM(CASE WHEN YEAR(sale_date) = 2025 THEN 1 ELSE 0 END) AS '2025 count of transaction'
FROM fact_sales 
GROUP BY payment_method WITH ROLLUP;
   
 -- percetnage of payment method use
 with payment_method as(
 -- payment method used all over the year
   SELECT 
    COALESCE(payment_method, 'TOTAL') AS payment_method,
    SUM(CASE WHEN YEAR(sale_date) = 2022 THEN 1 ELSE 0 END) AS '2022 count of transaction',
    SUM(CASE WHEN YEAR(sale_date) = 2023 THEN 1 ELSE 0 END) AS '2023 count of transaction',
    SUM(CASE WHEN YEAR(sale_date) = 2024 THEN 1 ELSE 0 END) AS '2024 count of transaction',
    SUM(CASE WHEN YEAR(sale_date) = 2025 THEN 1 ELSE 0 END) AS '2025 count of transaction'
FROM fact_sales 
GROUP BY payment_method WITH ROLLUP
 )
select payment_method,
(case when '2022 count of transaction' then (('2022 count of transaction') * 100) /  'TOTAL' else 0 end  ) as percentage_payment_method,
(case when '2023 count of transaction' then (('2023 count of transaction') * 100) /  'TOTAL' else 0 end  ) as percentage_payment_method,
(case when '2024 count of transaction' then (('2024 count of transaction') * 100) /  'TOTAL' else 0 end  ) as percentage_payment_method,
(case when '2025 count of transaction' then (('2025 count of transaction') * 100) /  'TOTAL' else 0 end  ) as percentage_payment_method
 from payment_method;
   
   
   select * from dim_date;
   -- percentage
   -- Percentage of payment method use
WITH payment_method_counts AS (
    -- Payment method used all over the year
    SELECT 
        COALESCE(payment_method, 'TOTAL') AS payment_method,
        SUM(CASE WHEN YEAR(sale_date) = 2022 THEN 1 ELSE 0 END) AS '2022_count',
        SUM(CASE WHEN YEAR(sale_date) = 2023 THEN 1 ELSE 0 END) AS '2023_count',
        SUM(CASE WHEN YEAR(sale_date) = 2024 THEN 1 ELSE 0 END) AS '2024_count',
        SUM(CASE WHEN YEAR(sale_date) = 2025 THEN 1 ELSE 0 END) AS '2025_count'
    FROM fact_sales 
    GROUP BY payment_method WITH ROLLUP
),
totals AS (
    -- Extract the TOTAL row for division
    SELECT 
        `2022_count` AS total_2022,
        `2023_count` AS total_2023,
        `2024_count` AS total_2024,
        `2025_count` AS total_2025
    FROM payment_method_counts
    WHERE payment_method = 'TOTAL'
)
SELECT 
    pm.payment_method,
    pm.`2022_count` AS '2022 Count',
    ROUND((pm.`2022_count` * 100.0) / t.total_2022, 2) AS '2022 %',
    
    pm.`2023_count` AS '2023 Count',
    ROUND((pm.`2023_count` * 100.0) / t.total_2023, 2) AS '2023 %',
    
    pm.`2024_count` AS '2024 Count',
    ROUND((pm.`2024_count` * 100.0) / t.total_2024, 2) AS '2024 %',
    
    pm.`2025_count` AS '2025 Count',
    ROUND((pm.`2025_count` * 100.0) / t.total_2025, 2) AS '2025 %'
FROM payment_method_counts pm
CROSS JOIN totals t
WHERE pm.payment_method != 'TOTAL';


-- fiscal year monthly cumulative 
select * from vw_fiscal_cumulative_sales;
   
   -- cumulative of reveneu
WITH yearly_revenue AS (
    SELECT 
        dd.fiscal_year AS Fiscal_Year,
        SUM(fs.total_price) AS Total_Revenue
    FROM fact_sales fs
    JOIN dim_date dd ON fs.fk_date_key = dd.date_key
    GROUP BY dd.fiscal_year
),
cumulative_revenue AS (
    SELECT 
        Fiscal_Year,
        Total_Revenue,
        SUM(Total_Revenue) OVER (
            ORDER BY Fiscal_Year
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Cumulative_Revenue
    FROM yearly_revenue
)
SELECT 
    Fiscal_Year,
    Total_Revenue,
    Cumulative_Revenue,
    CASE 
        WHEN LAG(Cumulative_Revenue) OVER (ORDER BY Fiscal_Year) IS NULL THEN NULL
        ELSE (Cumulative_Revenue - LAG(Cumulative_Revenue) OVER (ORDER BY Fiscal_Year)) * 100.0 
             / LAG(Cumulative_Revenue) OVER (ORDER BY Fiscal_Year)
    END AS cumulative_growth
FROM cumulative_revenue
ORDER BY Fiscal_Year ASC;

-- revenue in year by month
WITH Revenue AS (
    SELECT 
        dd.fiscal_month,
        COALESCE(dd.month_name, 'Total') AS Month,
        SUM(CASE WHEN dd.fiscal_year = 2022 THEN fs.total_price ELSE 0 END) AS Revenue_2022,
        SUM(CASE WHEN dd.fiscal_year = 2023 THEN fs.total_price ELSE 0 END) AS Revenue_2023,
        SUM(CASE WHEN dd.fiscal_year = 2024 THEN fs.total_price ELSE 0 END) AS Revenue_2024,
        SUM(CASE WHEN dd.fiscal_year = 2025 THEN fs.total_price ELSE 0 END) AS Revenue_2025
    FROM fact_sales fs
    JOIN dim_date dd 
        ON fs.fk_date_key = dd.date_key
    GROUP BY dd.fiscal_month, dd.month_name
    ORDER BY 
        CASE 
            WHEN dd.fiscal_month IS NULL THEN 13  -- places 'Total' at the end
            ELSE dd.fiscal_month
        END
),
Revenue_Year AS (
    SELECT 
        fiscal_month,
        Month,
        Revenue_2022,
        Revenue_2023,
        Revenue_2024,
        Revenue_2025
    FROM Revenue
)
SELECT 
    Month,
    Revenue_2022,
    ROUND((Revenue_2022 - LAG(Revenue_2022) OVER (ORDER BY fiscal_month)) / 
           LAG(Revenue_2022) OVER (ORDER BY fiscal_month) * 100, 2) AS 'Growth_2022 %',
    
    Revenue_2023,
    ROUND((Revenue_2023 - LAG(Revenue_2023) OVER (ORDER BY fiscal_month)) / 
           LAG(Revenue_2023) OVER (ORDER BY fiscal_month) * 100, 2) AS 'Growth_2023 %',
    
    Revenue_2024,
    ROUND((Revenue_2024 - LAG(Revenue_2024) OVER (ORDER BY fiscal_month)) / 
           LAG(Revenue_2024) OVER (ORDER BY fiscal_month) * 100, 2) AS 'Growth_2024 %',
    
    Revenue_2025,
    ROUND((Revenue_2025 - LAG(Revenue_2025) OVER (ORDER BY fiscal_month)) / 
           LAG(Revenue_2025) OVER (ORDER BY fiscal_month) * 100, 2) AS 'Growth_2025 %'
FROM Revenue_Year
ORDER BY fiscal_month;


-- basket analsyis
WITH basket_count AS (
    SELECT 
        dc.car_id,
        dc.model,
        SUM(CASE WHEN fs.units_sold = 3 THEN 1 ELSE 0 END) AS basket_of_3,
        SUM(CASE WHEN fs.units_sold = 2 THEN 1 ELSE 0 END) AS basket_of_2,
        SUM(CASE WHEN fs.units_sold = 1 THEN 1 ELSE 0 END) AS basket_of_1
    FROM fact_sales fs 
    JOIN dim_car dc ON fs.fk_sk_car = dc.sk_car
    GROUP BY dc.car_id, dc.model
)
SELECT 
    model,
    sum(basket_of_3),
   sum( basket_of_2),
   sum( basket_of_1)
FROM basket_count group by   sum( basket_of_1),sum( basket_of_2), sum(basket_of_3)
ORDER BY sum(basket_of_3) DESC,sum( basket_of_2) DESC,  sum( basket_of_1)DESC;

 select * from fact_sales; 
   select * from dim_date;
show tables;
select * from dim_customer;
select * from dim_car;

-- top 10 car by   sold
SELECT tu.model AS model,
       tu.Number_of_unit,
       ROUND((tu.Number_of_unit * 100.0) / SUM(tu.Number_of_unit) OVER (), 2) AS 'pct_sold_units %'
FROM sold_unit tu order by  tu.Number_of_unit desc limit 10;

-- top 10 car by  revenue
SELECT tu.model AS model,
       tu.Revenue,
       ROUND((tu.Revenue * 100.0) / SUM(tu.Revenue) OVER (), 2) AS 'pct_revenue %'
FROM sold_unit_revenue tu order by   tu.Revenue desc limit 10;

-- top 10 customer  by revenue
SELECT
  customer_name,
  total_revenue,
  ROUND((total_revenue * 1000.0) / SUM(total_revenue) OVER (), 2) AS 'pct_revenue %'
FROM revenue_based_customer
ORDER BY total_revenue DESC
LIMIT 10;

-- top 10 customer  by sold
SELECT
  customer_name,
  total_units_sold,
  ROUND((total_units_sold * 1000.0) / SUM(total_units_sold) OVER (), 2) AS 'pct_revenue %'
FROM sold_based_customer
ORDER BY total_units_sold DESC
LIMIT 10;

select * from sold_based_customer;
select * from revenue_based_customer; 
 select * from fact_sales;
 select * from dim_car;
 
 -- top 10 car by revenue
 select fk_sk_car,sum(total_price) from fact_sales
 group by fk_sk_car order by sum(total_price) desc;
 
 
-- top 10 customer by buying 
select fk_sk_customer,sum(units_sold)  from fact_sales
 group by fk_sk_customer order by sum(units_sold) desc ;


-- top 10 customer by reveneu
 select fk_sk_customer,sum(total_price) from fact_sales
 group by fk_sk_customer order by sum(total_price) desc;


-- customer age group year to year
WITH yearly_counts AS (
    SELECT 
        c.age_group,
        SUM(CASE WHEN YEAR(fs.sale_date) = 2022 THEN 1 ELSE 0 END) AS Customer_2022,
        SUM(CASE WHEN YEAR(fs.sale_date) = 2023 THEN 1 ELSE 0 END) AS Customer_2023,
        SUM(CASE WHEN YEAR(fs.sale_date) = 2024 THEN 1 ELSE 0 END) AS Customer_2024,
        SUM(CASE WHEN YEAR(fs.sale_date) = 2025 THEN 1 ELSE 0 END) AS Customer_2025
    FROM fact_sales fs 
    JOIN dim_customer c ON fs.fk_sk_customer = c.sk_customer
    GROUP BY c.age_group
)
SELECT 
    age_group AS Age_Group,
    
    Customer_2025,
    ROUND(100.0 * Customer_2022 / SUM(Customer_2022) OVER (), 2) AS 'Pct_2022%',
    
    Customer_2023,
    ROUND(100.0 * Customer_2023 / SUM(Customer_2023) OVER (), 2) AS'Pct_2023%',
    
    Customer_2024,
    ROUND(100.0 * Customer_2024 / SUM(Customer_2024) OVER (), 2) AS 'Pct_2024%',
    
    Customer_2025,
    ROUND(100.0 * Customer_2025 / SUM(Customer_2025) OVER (), 2) AS 'Pct_2025%'

FROM yearly_counts

UNION ALL

-- Add Total Row
SELECT 
    'Total' AS Age_Group,
    SUM(Customer_2022),
    100.00,
    SUM(Customer_2023),
    100.00,
    SUM(Customer_2024),
    100.00,
    SUM(Customer_2025),
    100.00
FROM yearly_counts;

-- popular car model 
create temporary table model_number  as 
select fk_sk_car ,model ,count(*) as number_of_model
from fact_sales fs join dim_car dc on fs.fk_sk_car = dc.sk_car group by model;

SELECT
  model AS 'Model Name',
  number_of_model AS 'Number Of Model',
  ROUND((number_of_model * 100.0) / SUM(number_of_model) OVER (), 2) AS 'PCT %'
FROM model_number
ORDER BY number_of_model DESC limit 10;

--
create  temporary table car_type_count as
select 
dc.car_type,
sum(case when dd.fiscal_year = 2022 then 1 else 0 end )as count_in_2022,
sum(case when dd.fiscal_year = 2023 then 1 else 0 end )as count_in_2023,
sum(case when dd.fiscal_year = 2024 then 1 else 0 end )as count_in_2024,
sum(case when dd.fiscal_year = 2025 then 1 else 0 end )as count_in_2025
from fact_sales fs 
join dim_car dc on dc.sk_car = fs.fk_sk_car 
join dim_date dd on dd.date_key=fs.fk_date_key group by dc.car_type ;


-- fuel type pattern year to year
select car_type,
count_in_2022,
round(100*count_in_2022 /sum(count_in_2022) over(),2)as 'Pct_2022%',
count_in_2023,
round(100*count_in_2023 /sum(count_in_2023) over(),2)as 'Pct_2023%',
count_in_2024,
round(100*count_in_2024 /sum(count_in_2024) over(),2)as 'Pct_2024%',
count_in_2025,
round(100*count_in_2025 /sum(count_in_2025) over(),2)as 'Pct_2025%'
from car_type_count group by car_type;

-- 
select dc.car_id,dc.model,
 fs.sales_price,
 dc.base_price,
 dd.fiscal_year,
 fs.salesperson
from fact_sales fs
 join dim_car dc on fs.fk_sk_car = dc.sk_car 
 join dim_date dd on dd.date_key = fs.fk_date_key;


-- Margin analysis by price tier
WITH sales_with_tiers AS (
    SELECT 
        dc.model,
        dc.base_price,
        fs.sales_price,
        fs.salesperson,
        
        -- Categorize into price tiers
        CASE 
            WHEN fs.sales_price < dc.base_price * 0.7 THEN 'Deep Discount (>30% off)'
            WHEN fs.sales_price < dc.base_price * 0.9 THEN 'Moderate Discount (10-30% off)'
            WHEN fs.sales_price < dc.base_price * 1.1 THEN 'Near Base Price (±10%)'
            WHEN fs.sales_price < dc.base_price * 1.3 THEN 'Premium (10-30% above)'
            ELSE 'High Premium (>30% above)'
        END AS price_tier
        
    FROM fact_sales fs 
    JOIN dim_car dc ON fs.fk_sk_car = dc.sk_car
)
SELECT 
    model,
    price_tier,
    COUNT(*) AS num_sales,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY model), 2) AS pct_of_model_sales,
    ROUND(AVG(sales_price), 2) AS avg_price_in_tier,
    ROUND(MIN(sales_price), 2) AS min_price,
    ROUND(MAX(sales_price), 2) AS max_price,
    COUNT(DISTINCT salesperson) AS num_salespeople
    
FROM sales_with_tiers
GROUP BY model, price_tier, base_price
ORDER BY model, 
         CASE price_tier
             WHEN 'High Premium (>30% above)' THEN 1
             WHEN 'Premium (10-30% above)' THEN 2
             WHEN 'Near Base Price (±10%)' THEN 3
             WHEN 'Moderate Discount (10-30% off)' THEN 4
             WHEN 'Deep Discount (>30% off)' THEN 5
         END;

-- margin based view
create or replace view margin_price as
select fs.sk_sale,dc.sk_car,dd.date_key,
fs.sales_price ,dc.base_price ,
round((fs.sales_price - dc.base_price ),2)as margin_price
from fact_sales fs 
join dim_car dc on dc.sk_car = fs.fk_sk_car
 join dim_date dd on dd.date_key = fs.fk_date_key;

-- margin category specified 
select * from vw_margin_analysis;


select 
 margin_class,
count(*) as num_sales,
round((100 * count(*)/sum(count(*))over()),2) as  pct_of_sales
from vw_margin_analysis 
group by margin_class
order by margin_class;

-- car model sales by class
select model ,
sum(case when margin_class='A. Premium (30%+ above base)' then units_sold else 0 end)  as 'Premium class',
sum(case when margin_class='B. High Margin (10-30% above)' then units_sold else 0 end) as 'High Margin',
sum(case when margin_class='C. Near Base (±5%)' then units_sold else 0 end) as 'Near Base',
sum(case when margin_class='D. Small Discount (5-20% off)' then units_sold else 0 end) as 'Small Discount',
sum(case when margin_class='E. Moderate Discount (20-40% off)' then units_sold else 0 end) as 'Moderate Discount',
sum(case when margin_class='F. Heavy Discount (40-60% off)' then units_sold else 0 end) as 'Heavy Discount',
sum(case when margin_class='G. Deep Discount (60%+ off)' then units_sold else 0 end) as ' Deep Discount '
from vw_margin_analysis group by model;

-- sales in different year
select margin_class,
sum(case when fiscal_year = 2022 then units_sold else 0 end)as '2022 Sales Units',
sum(case when fiscal_year = 2023 then units_sold else 0 end)as '2023 Sales Units',
sum(case when fiscal_year = 2024 then units_sold else 0 end)as '2024 Sales Units',
sum(case when fiscal_year = 2025 then units_sold else 0 end)as '2025 Sales Units'
from vw_margin_analysis group by  margin_class;

create temporary table marginsales as
select salesperson,
sum(case when fiscal_year = 2022 then units_sold else 0 end)as '2022 Sales Units',
sum(case when fiscal_year = 2023 then units_sold else 0 end)as '2023 Sales Units',
sum(case when fiscal_year = 2024 then units_sold else 0 end)as '2024 Sales Units',
sum(case when fiscal_year = 2025 then units_sold else 0 end)as '2025 Sales Units'
from vw_margin_analysis group by  salesperson;

create view email_domain_count as
select email,LOWER(SUBSTRING_INDEX(email, '@', -1)) AS email_domain from dim_customer;

-- top email domin extract
create view email_domain_counts as
select email_domain ,count(*) as 'Number of Email domain' 
 from email_domain_check 
 group by email_domain 
 order by count(*) desc limit 10;

CREATE VIEW email_domain_top10 AS
SELECT 
    LOWER(SUBSTRING_INDEX(email, '@', -1)) AS email_domain,
    COUNT(*) AS Number_of_Email_Domain
FROM dim_customer
GROUP BY email_domain
ORDER BY COUNT(*) DESC
LIMIT 10;


select * from vw_margin_analysis;
select * from vw_stock_analysis;


select model,
sum(case when stock_status = '🟢moderate' then 1 else 0 end) as 'moderate',
sum(case when stock_status = '🔴Out of stock' then 1 else 0 end) as 'Out of stock',
sum(case when stock_status = '🟠critical' then 1 else 0 end) as 'critical',
sum(case when stock_status = '🟢 low' then 1 else 0 end) as 'low',
sum(case when stock_status = '🔵Good' then 1 else 0 end) as 'Good'
from vw_stock_analysis  where fiscal_year= 2025 and fiscal_month = 7 group by model ;






  select * from fact_sales; 
   select * from dim_date;
show tables;
select * from dim_customer;
select * from dim_car;
select * from dim_customer;
    
    
 
    
    
    




