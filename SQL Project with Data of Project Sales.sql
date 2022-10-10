
--- imported data from excel and csv files 

--- Creating 'Project' database
CREATE DATABASE Project

USE Project

--- MODIFY DATA AND CONSTRAINT

ALTER TABLE [dbo].[cust_dimen] ALTER COLUMN [Cust_ID] varchar(255) NOT NULL
ALTER TABLE [dbo].[cust_dimen] ADD CONSTRAINT PK_Cust PRIMARY KEY (Cust_ID)

ALTER TABLE [dbo].[shipping_dimen] ALTER COLUMN [Ship_ID] varchar(50) NOT NULL
ALTER TABLE [dbo].[shipping_dimen] ADD CONSTRAINT PK_Ship PRIMARY KEY (Ship_ID)

ALTER TABLE [dbo].[prod_dimen] ALTER COLUMN [Prod_ID] varchar(50) NOT NULL
ALTER TABLE [dbo].[prod_dimen] ADD CONSTRAINT PK_Prod PRIMARY KEY (Prod_ID)

ALTER TABLE [dbo].[orders_dimen] ALTER COLUMN [Ord_ID] varchar(50) NOT NULL
ALTER TABLE [dbo].[orders_dimen] ADD CONSTRAINT PK_Ord PRIMARY KEY (Ord_ID)

ALTER TABLE [dbo].[market_fact] ALTER COLUMN [Ord_ID] varchar(50) NOT NULL
ALTER TABLE [dbo].[market_fact] ALTER COLUMN [Prod_ID] varchar(50) NOT NULL
ALTER TABLE [dbo].[market_fact] ALTER COLUMN [Ship_ID] varchar(50) NOT NULL
ALTER TABLE [dbo].[market_fact] ALTER COLUMN [Cust_ID] varchar(255) NOT NULL

ALTER TABLE [dbo].[market_fact] ADD CONSTRAINT FK_Ord FOREIGN KEY (Ord_ID) REFERENCES [dbo].[orders_dimen] (Ord_ID)
ALTER TABLE [dbo].[market_fact] ADD CONSTRAINT FK_Prod FOREIGN KEY (Prod_ID) REFERENCES [dbo].[prod_dimen] (Prod_ID)
ALTER TABLE [dbo].[market_fact] ADD CONSTRAINT FK_Ship FOREIGN KEY (Ship_ID) REFERENCES [dbo].[shipping_dimen] (Ship_ID)
ALTER TABLE [dbo].[market_fact] ADD CONSTRAINT FK_Cust FOREIGN KEY (Cust_ID) REFERENCES [dbo].[cust_dimen] (Cust_ID)


ALTER TABLE [dbo].[market_fact] ADD PRIMARY KEY (Ord_ID, Prod_ID, Ship_ID, Cust_ID)



-- ANALYZE THE DATA

--1.
-- Using the columns of “market_fact”, “cust_dimen”, “orders_dimen”, “prod_dimen”, “shipping_dimen”, 
-- Create a new table, named as “combined_table”. 



SELECT A.Ord_ID, A.Prod_ID, A.Ship_ID, A.Cust_ID, A.Sales, A.Discount, A.Order_Quantity, A.Product_Base_Margin,
	   B.Order_ID, B.Ship_Date, B.Ship_Mode,
	   C.Customer_Name, C.Province, C.Region, C.Customer_Segment,
	   D.Order_Date, D.Order_Priority,
	   E.Product_Category, E.Product_Sub_Category
INTO combined_table
FROM market_fact A
	LEFT JOIN  shipping_dimen B on A.Ship_ID = B.Ship_ID
	LEFT JOIN  cust_dimen C on A.Cust_ID = C.Cust_ID
	LEFT JOIN  orders_dimen D on A.Ord_ID = D.Ord_ID
	LEFT JOIN  prod_dimen E on A.Prod_ID = E.Prod_ID

SELECT *
FROM combined_table


--2.
-- Find the top 3 customers who have the maximum count of orders.

SELECT DISTINCT TOP(3) Cust_ID, Customer_Name, COUNT(Order_Quantity) OVER(PARTITION BY Cust_ID) as count_of_orders
FROM combined_table
ORDER BY 3 DESC



--3.
-- Create a new column at combined_table as DaysTakenForShipping that contains the date difference of Order_Date and Ship_Date.

ALTER TABLE combined_table ADD DaysTakenForShipping INT NULL

UPDATE combined_table
SET DaysTakenForShipping = DATEDIFF(DAY, Order_Date, Ship_Date)
FROM combined_table

SELECT DaysTakenForShipping
FROM combined_table


--4.
-- Find the customer whose order took the maximum time to get shipping.

SELECT  TOP(1) Cust_ID, Customer_Name, DaysTakenForShipping
FROM combined_table
ORDER BY 3 DESC



--5.
--Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011

WITH T1 AS
(
SELECT Cust_ID, Customer_Name, DATENAME(Month, order_date) as [Month_Name]
FROM combined_table
WHERE YEAR(Order_Date)=2011 AND Cust_ID IN (SELECT Cust_ID FROM combined_table WHERE DATENAME(Month, order_date)='January' AND YEAR(Order_Date)=2011)
GROUP BY Cust_ID, Customer_Name, DATENAME(Month, order_date)
)
SELECT DISTINCT Month_Name,
		COUNT(Cust_ID) OVER(PARTITION BY Month_Name) as Count_of_Customers
FROM T1



--6.
-- Write a query to return for each user the time elapsed between the first purchasing and the third purchasing, in ascending order by Customer ID.


SELECT  
		DISTINCT Cust_ID,
		Order_Date as Third_Purchansing,
		First_Purchansing,
		DATEDIFF(day, First_Purchansing, Order_Date) Elapsed_Day
FROM	
		(
		SELECT	Cust_ID, Order_Date,
				MIN (Order_Date) OVER (PARTITION BY Cust_ID) First_Purchansing,
				DENSE_RANK () OVER (PARTITION BY Cust_ID ORDER BY Order_Date) dense_number
		FROM	combined_table
		) T1
WHERE	dense_number = 3
Order By Cust_ID ASC;



--7.
--Write a query that returns customers who purchased both product 11 and product 14, 
--as well as the ratio of these products to the total number of products purchased by the customer.


	SELECT DISTINCT Cust_ID,
		CAST (1.0*sum(case when Prod_ID = 'Prod_11' then Order_Quantity else 0  end)/sum(Order_Quantity) AS NUMERIC (3,2)) AS Ratio_P11,
		CAST (1.0*sum(case when Prod_ID = 'Prod_14' then Order_Quantity else 0  end)/sum(Order_Quantity) AS NUMERIC (3,2)) AS Ratio_P14
	
	FROM combined_table
	GROUP BY Cust_ID
	HAVING
		SUM (CASE WHEN Prod_ID = 'Prod_11' THEN Order_Quantity ELSE 0 END) >= 1 AND
		SUM (CASE WHEN Prod_ID = 'Prod_14' THEN Order_Quantity ELSE 0 END) >= 1




------ Customer Segmentation

--1.
-- Create a “view” that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month)

CREATE VIEW visit_log AS
(
	SELECT Cust_ID, YEAR(Order_Date) as year_log, MONTH(Order_Date) as month_log
	FROM combined_table
	GROUP BY Cust_ID, YEAR(Order_Date) , MONTH(Order_Date)
)

SELECT *
FROM visit_log


--2.
-- Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning business)

CREATE VIEW visit_users AS
(
	SELECT Cust_ID, YEAR(Order_Date) as year_visit, MONTH(Order_Date) as month_visit,
	COUNT(Cust_ID) OVER(PARTITION BY Cust_ID ORDER BY Cust_ID) as cnt_logs
	FROM combined_table
);

SELECT *
FROM visit_users


--3.
-- For each visit of customers, created the next month of the visit as a separate column.

CREATE VIEW next_visit_log AS
(
	SELECT *, 
		LEAD(current_month, 1) OVER(PARTITION BY  Cust_ID  ORDER BY current_month) as next_month_visit
	FROM
	(
		SELECT *,  DENSE_RANK() OVER(ORDER BY year_log, month_log) as current_month
		FROM visit_log
		) T1
);

SELECT *
FROM next_visit_log


--4.
-- Calculated the monthly time gap between two consecutive visits by each customer.

CREATE VIEW gap_visit AS
(
	SELECT *, next_month_visit - current_month as cust_gap_visit
	FROM next_visit_log
);

SELECT *
FROM gap_visit


--5.
-- Categorise customers using average time gaps. Choose the most fitted labeling model for you.
--For example:
-----> Labeled as churn if the customer hasn't made another purchase in the months since they made their first purchase.
-----> Labeled as regular if the customer has made a purchase every month.


WITH cat_by_cust AS
(
	SELECT Cust_ID, AVG(cust_gap_visit) as avg_visit_gap
	FROM gap_visit
	GROUP BY Cust_ID
)

SELECT Cust_ID,
		CASE WHEN avg_visit_gap >= 1 THEN 'Regular' ELSE 'Churn' END AS visits
FROM cat_by_cust




-- Month-Wise Retention Rate

--1.
-- Finded month-by-month customer retention rate since the start of the business.


CREATE VIEW current_count AS
(
	SELECT *, 
		COUNT(Cust_ID) OVER(PARTITION BY current_month) as current_count_customer
	FROM gap_visit
	WHERE current_month > 1
);

CREATE VIEW next_count AS
(
	SELECT *,
		COUNT(Cust_ID) OVER(PARTITION BY next_month_visit) as next_count_customer
	FROM gap_visit
	WHERE cust_gap_visit = 1
);



--2.
-- Calculate the month-wise retention rate.

WITH T1 AS(
	SELECT A.Cust_ID, A.next_month_visit, A.current_count_customer, B.next_count_customer
	FROM current_count A, next_count B
	WHERE A.next_month_visit = B.current_month
	and A.cust_gap_visit =  1
)
SELECT DISTINCT CAST(1.0 * next_count_customer/current_count_customer  AS NUMERIC (3,2)) as Month_Wise_Retention_Rate
FROM T1



