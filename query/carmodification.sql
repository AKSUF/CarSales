create database carsales;
use carsales;
drop database carsales;
CREATE TABLE cars (
    Car_ID VARCHAR(10),
    Brand VARCHAR(50),
    Model VARCHAR(50),
    Year INT,
    Color VARCHAR(30),
    Engine_Type VARCHAR(30),
    Transmission VARCHAR(30),
    Price DECIMAL(10,2),
    Quantity_In_Stock INT,
    Status VARCHAR(20)
);

CREATE TABLE customers (
    Customer_ID VARCHAR(10) ,
    Name VARCHAR(100),
    Gender VARCHAR(10),
    Age INT,
    Phone VARCHAR(30),
    Email VARCHAR(100),
    City VARCHAR(50)
);

CREATE TABLE sales (
    Sale_ID VARCHAR(10) ,
    Customer_ID VARCHAR(10),
    Car_ID VARCHAR(10),
    Sale_Date DATE,
    Quantity INT,
    Sale_Price DECIMAL(10,2),
    Payment_Method VARCHAR(30),
    Salesperson VARCHAR(100)
);

create table fact_sales (
sk_sale int primary key auto_increment,
fk_sk_customer int not null,
fk_sk_car int not null,
fk_date_key int not null,
sale_date date not null,
units_sold int default 1,
sales_price decimal(10,2) not null,
discount_amount decimal(10,2) default 0,
net_revenue decimal(10,2) generated always as (sales_price - discount_amount)stored,
load_timestamp timestamp default current_timestamp,
foreign key(fk_sk_customer) references dim_customer(sk_customer),
foreign key(fk_sk_car)  references dim_car(sk_car),
foreign key(fk_date_key)references dim_date(date_key)
);


alter table fact_sales drop column discount_amount;
select * from fact_sales;
select min(full_date) from dim_date;
select max(full_date) from dim_date;
drop table dim_customer;
select * from dim_customer;

alter table dim_customer drop column location_city ;
-- creaye dim_customer table
create table dim_customer(
sk_customer int primary key auto_increment,
customer_id varchar(50) not null ,
customer_name varchar(100) not null,
email varchar(100),
age_group enum('Young(18-29)','Mid(30-49)','Senior(50+)'),
valid_from datetime default current_timestamp,
valid_to datetime default '9999-12-31',
is_active boolean default true,
unique key uk_customer_id(customer_id)
);

create table dim_car(
sk_car int primary key auto_increment,
car_id varchar (50) not null,
make varchar(50) not null,
model varchar(50) not null,
year_model int,
car_type enum('Sedan','SUV','Truck','Coupe','Other'),
base_price decimal(10,2),
avg_mileage int,
category varchar(30),
unique key uk_car_id(car_id)
);


select * from cars;

-- create date table
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,  -- YYYYMMDD format, e.g., 20231105
    full_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    day INT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    week_of_year INT NOT NULL,
    is_weekend BOOLEAN DEFAULT FALSE
);

INSERT INTO dim_date (
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day,
    day_name,
    week_of_year,
    is_weekend
)
SELECT DISTINCT
    DATE_FORMAT(Sale_Date, '%Y%m%d') AS date_key,
    Sale_Date AS full_date,
    YEAR(Sale_Date) AS year,
    QUARTER(Sale_Date) AS quarter,
    MONTH(Sale_Date) AS month,
    MONTHNAME(Sale_Date) AS month_name,
    DAY(Sale_Date) AS day,
    DAYNAME(Sale_Date) AS day_name,
    WEEK(Sale_Date) AS week_of_year,
    CASE 
        WHEN DAYOFWEEK(Sale_Date) IN (1, 7) THEN 1
        ELSE 0
    END AS is_weekend
FROM Sales
WHERE Sale_Date IS NOT NULL;

select * from dim_customer;
-- insertin into dim_customer
insert into dim_customer(
customer_id,
customer_name,
email,
age_group,
valid_from ,
valid_to,
is_active
)
select 
cast(customer_id as char(50)),
name,
email,
case 
when age<30 then 'Young(18-29)'
when age between 30 and 49 then 'Mid (30-49)'
else 'Senior(50+)'
end,
current_date(),
'9999-12-31',
true from customers where customer_id is not null 
on duplicate key update customer_name = values(customer_name),
is_active = true;

-- insert into dim_car
drop table dim_car;
alter table dim_car drop column make;

select * from dim_car;

insert into dim_car (
car_id,
model,
year_model,
car_type,
base_price,
category
)
select cast(car_id as char(50)),
model,
year,
engine_type,
price,
case 
when price <25000 then 'Economy'
when price between 25000 and 45000 then 'Mid_Range'
else 'Luxury'
end 
from cars
where car_id is not null
on duplicate key update
model = values(model);

ALTER TABLE dim_car 
MODIFY car_type VARCHAR(30);

alter table dim_car 
add column transmission varchar(50),
add column quantity_in_stock  varchar(50);

UPDATE dim_car d
JOIN cars c ON d.car_id = c.car_id
SET 
    d.transmission = c.transmission,
    d.quantity_in_stock = c.quantity_in_stock;

select * from fact_sales;
select * from sales;
ALTER TABLE fact_sales DROP COLUMN sales_price;

alter table fact_sales
add column payment_method varchar(50),
add column salesperson varchar(50);

alter table  fact_sales drop column net_revenue;


select * from sales;
select * from fact_sales;

INSERT INTO fact_sales (
    fk_sk_customer,
    fk_sk_car,
    fk_date_key,
    sale_date,
    units_sold,
    sales_price,
    discount_amount,
    load_timestamp,
    payment_method,
    salesperson
)
SELECT
    c.sk_customer AS fk_sk_customer,
    car.sk_car AS fk_sk_car,
    d.date_key AS fk_date_key,
    s.sale_date,
    s.quantity AS units_sold,
    s.sale_price AS sales_price,
    0 AS discount_amount,  -- can keep 0 if needed
    CURRENT_TIMESTAMP() AS load_timestamp,
    s.payment_method,
    s.salesperson
FROM sales s
JOIN dim_customer c ON s.customer_id = c.customer_id
JOIN dim_car car ON s.car_id = car.car_id
JOIN dim_date d ON s.sale_date = d.full_date;


ALTER TABLE fact_sales 
MODIFY net_revenue DECIMAL(12,2);

update dim_product
set avg_mrp = (amazon_mrp +coalesce(myntra_mrp,amazon_mrp)) + (1+case when myntra_mrp is not null then 1 else 0 end);


alter table fact_sales
drop column total_sales;

alter table fact_sales 
add column total_price float(50);

update fact_sales
set total_price = (units_sold * sales_price);

-- adding fiscal year month 
alter table dim_date
add column fiscal_year varchar(10),
add column fiscal_quarter int,
add column fiscal_month int;

UPDATE dim_date
SET
    fiscal_year = CASE
        WHEN month >= 10 THEN CONCAT('FY', year + 1)
        ELSE CONCAT('FY', year)
    END,
    fiscal_month = CASE
        WHEN month >= 10 THEN month - 9       -- Oct=1, Nov=2, Dec=3
        ELSE month + 3                        -- Jan=4 … Sep=12
    END,
    fiscal_quarter = CASE
        WHEN month >= 10 THEN CEIL((month - 9) / 3)
        ELSE CEIL((month + 3) / 3)
    END;


SELECT 
    full_date, 
    year, 
    month_name, 
    fiscal_year, 
    fiscal_month, 
    fiscal_quarter
FROM dim_date
WHERE month IN (9,10,11,12,1)
ORDER BY full_date
LIMIT 15;

select * from dim_date;
show tables;

select min(sale_date), max(sale_date) from fact_sales;

UPDATE dim_date
SET 
    fiscal_year = CASE 
        WHEN MONTH(full_date) >= 10 THEN YEAR(full_date) + 1
        ELSE YEAR(full_date)
    END,
    
    fiscal_month = CASE 
        WHEN MONTH(full_date) >= 10 THEN MONTH(full_date) - 9
        ELSE MONTH(full_date) + 3
    END,
    
    fiscal_quarter = CASE 
        WHEN MONTH(full_date) BETWEEN 10 AND 12 THEN 1
        WHEN MONTH(full_date) BETWEEN 1 AND 3 THEN 2
        WHEN MONTH(full_date) BETWEEN 4 AND 6 THEN 3
        WHEN MONTH(full_date) BETWEEN 7 AND 9 THEN 4
    END
WHERE full_date BETWEEN '2022-10-01' AND '2025-09-30';

select year(fiscal_year) from dim_date group by year(fiscal_year) ;