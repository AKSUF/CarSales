
-- Prenormalization data schema
call AutoDetectColumnCategory('sales');
call AutoDetectColumnCategory('cars');
call AutoDetectColumnCategory('customers');

-- Normalization data schema
call AutoDetectColumnCategory('dim_car');
call AutoDetectColumnCategory('dim_customer');
call AutoDetectColumnCategory('dim_date');
call AutoDetectColumnCategory('fact_sales');

show tables;