select *
from foodie_fi.subscriptions;
/*A. Customer Journey
Based off the 8 sample customers provided in the sample from the subscriptions table,
write a brief description about each customer’s onboarding journey.
Try to keep it as short as possible - you may also want to run some sort of join to-
make your explanations a bit easier!*/

SELECT customer_id, plan_name, p.plan_id, start_date
FROM foodie_fi.plans as p 
INNER JOIN foodie_fi.subscriptions as s 
ON p.plan_id = s.plan_id
WHERE customer_id <= 8;

/*SECTION B 
Question 1 How many customers has Foodie-Fi ever had?*/
SELECT COUNT (DISTINCT customer_id) total_customers
FROM foodie_fi.plans as p 
INNER JOIN foodie_fi.subscriptions as s 
ON p.plan_id = s.plan_id;

/*Question 2 What is the monthly distribution of trial plan start_date values for our dataset - 
use the start of the month as the group by value*/
SELECT COUNT (plan_name), Extract (month from start_date) as start_month, To_char (start_date, 'Month') as month
FROM foodie_fi.plans as p 
INNER JOIN foodie_fi.subscriptions as s 
ON p.plan_id = s.plan_id
where plan_name = 'trial'
GROUP BY To_char (start_date, 'Month'), Extract (month from start_date)
ORDER BY COUNT (plan_name);

SELECT DATE_TRUNC ('month', start_date) as start_month, COUNT(customer_id) as distribution
FROM foodie_fi.subscriptions
where plan_id = 0
GROUP BY DATE_TRUNC ('month', start_date);

/*Question 3 What plan start_date values occur after the year 2020 for our dataset? 
Show the breakdown by count of events for each plan_name*/
SELECT DATE_PART ('year', start_date) as year, COUNT (*) as count_of_events, plan_name
FROM foodie_fi.subscriptions as s
INNER JOIN foodie_fi.plans as p
ON p.plan_id=s.plan_id
WHERE  DATE_PART ('year', start_date) > 2020
GROUP BY DATE_PART ('year', start_date), plan_name;

--Method 2
SELECT EXTRACT (year from start_date) as year, COUNT (*) as count_of_events, plan_name
FROM foodie_fi.subscriptions as s
INNER JOIN foodie_fi.plans as p
ON p.plan_id=s.plan_id
WHERE  EXTRACT (year from start_date) > 2020
GROUP BY EXTRACT (year from start_date), plan_name;

/*Question 4 What is the customer count and percentage of customers who have churned rounded to 1 decimal place?*/
WITH CTE AS (SELECT (SELECT COUNT (DISTINCT customer_id)
FROM foodie_fi.subscriptions) as customer_count, COUNT (DISTINCT customer_id) as churned
FROM foodie_fi.subscriptions
WHERE plan_id = 4)

SELECT CONCAT (ROUND((churned:: numeric/customer_count:: numeric):: numeric * 100,1), '%')  as percentage_churned 
FROM CTE;

/*Question 5 How many customers have churned straight after their initial free trial - 
what percentage is this rounded to the nearest whole number?*/
WITH CTE AS (
	SELECT customer_id, plan_name,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date ASC) as row
FROM foodie_fi.subscriptions as s
INNER JOIN foodie_fi.plans as p
ON p.plan_id = s.plan_id
)

SELECT COUNT (DISTINCT customer_id) AS churned_after_trial,CONCAT (ROUND (COUNT (DISTINCT customer_id):: numeric/
		(SELECT COUNT(DISTINCT customer_id) FROM foodie_fi.subscriptions)::numeric *100,1),'%') as percentage_churn_after_trial
FROM cte
WHERE row = 2
AND plan_name = 'churn';

--Question 6 What is the number and percentage of customer plans after their initial free trial?
WITH CTE AS (
	SELECT customer_id, plan_name,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date ASC) as row
FROM foodie_fi.subscriptions as s
INNER JOIN foodie_fi.plans as p
ON p.plan_id = s.plan_id
)

SELECT plan_name, COUNT (customer_id) as count, 
CONCAT (ROUND(COUNT (customer_id)::numeric/(SELECT COUNT(DISTINCT customer_id) FROM foodie_fi.subscriptions)::numeric *100),'%') as percentage
FROM cte
WHERE row = 2
GROUP BY plan_name;

--Question 7 What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH CTE AS (
	SELECT *,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) as row
FROM foodie_fi.subscriptions 
	WHERE start_date <= '2020-12-31'
)

SELECT  plan_name, COUNT (customer_id), 
CONCAT(ROUND (COUNT(customer_id)::numeric/(SELECT COUNT(DISTINCT customer_id) FROM cte)::numeric *100, 1), '%') as customer_percentage
FROM CTE as c
INNER JOIN foodie_fi.plans as p
ON p.plan_id = c.plan_id
WHERE row = 1
GROUP BY plan_name;

--Question 8 How many customers have upgraded to an annual plan in 2020?
WITH BP_Month AS (
SELECT customer_id, start_date
FROM foodie_fi.subscriptions
WHERE start_date <= '2020-12-31'
AND plan_id IN (1,2)
	)
, ANNUAL AS (
SELECT customer_id, start_date
FROM foodie_fi.subscriptions
WHERE start_date <= '2020-12-31'
AND plan_id = 3
	)
SELECT COUNT (DISTINCT A.customer_id) as upgrade
FROM BP_Month as M
INNER JOIN ANNUAL as A
ON M.customer_id = A.customer_id AND 
M.start_date < A.start_date;

-- Question 9 How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH TRIAL AS (
	SELECT customer_id, start_date as trial_date
	FROM foodie_fi.subscriptions 
	WHERE plan_id = 0
)
, ANNUAL AS (
SELECT customer_id, start_date as annual_date
FROM foodie_fi.subscriptions
WHERE plan_id = 3
)
SELECT ROUND(AVG(annual_date - trial_date),1 ) as day_diff
FROM TRIAL as t
INNER JOIN ANNUAL as a
ON t.customer_id = a.customer_id;

--Question 10 Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH TRIAL AS (
	SELECT customer_id, start_date as trial_date
	FROM foodie_fi.subscriptions 
	WHERE plan_id = 0
)
, ANNUAL AS (
SELECT customer_id, start_date as annual_date
FROM foodie_fi.subscriptions
WHERE plan_id = 3
)
SELECT COUNT(a.customer_id) as count_of_customers,
CASE
WHEN annual_date - trial_date <= 30 THEN '0-30 days'
WHEN (annual_date - trial_date) <= 31 THEN '31-60 days'
WHEN (annual_date - trial_date) <= 61 THEN '61-90 days'
WHEN (annual_date - trial_date) <= 91 THEN '91-120 days'
WHEN (annual_date - trial_date) <= 121 THEN '121-150 days'
WHEN (annual_date - trial_date) <= 151 THEN '151-180 days'
WHEN (annual_date - trial_date) <= 181 THEN '181-210 days'
WHEN (annual_date - trial_date) <= 211 THEN '211-240 days'
WHEN (annual_date - trial_date) <= 241 THEN '241-270 days'
WHEN (annual_date - trial_date) <= 271 THEN '271-300 days'
WHEN (annual_date - trial_date) <= 301 THEN '301-330 days'
WHEN (annual_date - trial_date) <= 331 THEN '331-360 days'
WHEN (annual_date - trial_date) <= 361 THEN '361-390 days'
END brkdwn
FROM TRIAL as t
INNER JOIN ANNUAL as a
ON t.customer_id = a.customer_id
GROUP BY 2
ORDER BY 2;

--Question 11 How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH Pro_Month AS (
SELECT customer_id, start_date
FROM foodie_fi.subscriptions
WHERE start_date <= '2020-12-31'
AND plan_id = 2
	)
, BASIC AS (
SELECT customer_id, start_date
FROM foodie_fi.subscriptions
WHERE start_date <= '2020-12-31'
AND plan_id = 1
	)
SELECT COUNT (DISTINCT P.customer_id) as downgrade
FROM Pro_Month as P
INNER JOIN BASIC as B
ON P.customer_id = B.customer_id AND 
P.start_date < B.start_date;