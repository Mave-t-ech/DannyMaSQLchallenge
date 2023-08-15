SELECT *
FROM public.customer_orders;
SELECT *
FROM public.pizza_names;
SELECT *
FROM public.pizza_recipes;
SELECT *
FROM public.pizza_toppings;
SELECT *
FROM public.runner_orders;
SELECT *
FROM public.runners;

--PIZZA METRICS
-- Question 1 How many pizzas were ordered?
SELECT COUNT(*) AS Total_orders
FROM public.customer_orders;

-- Question 2 How many Unique customer orders were made
SELECT COUNT (DISTINCT order_id) AS Unique_orders
FROM public.customer_orders;

-- Question 3 How many successful orders were delivered by each runner?
SELECT  runner_id, COUNT (order_id) AS suc_orders
FROM public.runner_orders
GROUP BY runner_id;

-- Question 4 How many of each type of pizza was delivered? 
SELECT  pizza_id, COUNT (cuo.order_id) AS dev_orders
FROM public.runner_orders AS ruo
INNER JOIN public.customer_orders AS cuo
ON ruo.order_id = cuo.order_id
WHERE pickup_time IS NOT NULL
GROUP BY pizza_id;

-- Question 5 How many Vegetarian and Meatloafers were ordered by each customers?
SELECT customer_id, pizza_name, count (order_id)
FROM public.customer_orders AS cuo
LEFT JOIN public.pizza_names AS pn
ON cuo.pizza_id = pn.pizza_id
GROUP BY customer_id, pizza_name; 

SELECT customer_id, pizza_name,count (cuo.pizza_id)
FROM public.customer_orders AS cuo
INNER JOIN public.pizza_names AS pn
ON cuo.pizza_id = pn.pizza_id
GROUP BY pizza_name, customer_id; 


--6. What was the maximum number of pizzas delivered in a single order?
WITH cte AS(SELECT order_id, customer_id, pizza_id,
CASE 
	WHEN pizza_id = 1 THEN 1
ELSE 0 END meatlover,
CASE
	WHEN pizza_id = 2 THEN 1
ELSE 0 END vegetarian
FROM public.customer_orders)

SELECT customer_id, SUM(meatlover) meatlover, SUM(vegetarian) vegetarian
FROM cte
GROUP BY  customer_id;

-- Question 6 What was the maximum number of pizzas delivered in a single order?
SELECT  cuo.order_id, COUNT (pizza_id) AS max_orders
FROM public.runner_orders AS ruo
INNER JOIN public.customer_orders AS cuo
ON ruo.order_id = cuo.order_id
WHERE pickup_time IS NOT NULL
GROUP BY cuo.order_id
ORDER BY COUNT (pizza_id)DESC;

-- Question 7 For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select customer_id,
sum (case 
when (exclusions IS NOT NULL AND exclusions <> 'null' AND LENGTH(exclusions)>0) 
OR (extras IS NOT NULL AND extras <> 'null' AND LENGTH (extras)>0)
= TRUE 
THEN 1
ELSE 0
END )AS changes,

SUM (CASE 
WHEN (exclusions IS NOT NULL AND exclusions <> 'null' AND LENGTH(exclusions)>0) 
OR (extras IS NOT NULL AND extras <>'null' AND LENGTH (extras)>0)
 = TRUE 
THEN 0
ELSE 1
END) AS no_changes
FROM public.customer_orders as cuo
INNER JOIN public.runner_orders as ruo
ON cuo.order_id = ruo.order_id
WHERE pickup_time IS NOT NULL
GROUP BY cuo.customer_id;

--Question 8 How many pizzas were delivered that had both exclusions and extras?
with cte AS (select customer_id,
 (case 
when (exclusions IS NOT NULL AND exclusions <> 'null' AND LENGTH(exclusions) >0) 
AND (extras IS NOT NULL AND extras <> 'null' AND LENGTH (extras) >0)
THEN 0
ELSE 1
END )AS del_both
FROM public.customer_orders as cuo
INNER JOIN public.runner_orders as ruo
ON cuo.order_id = ruo.order_id
WHERE pickup_time IS NOT NULL)

select count (*) delivered_with_exclusions_and_extras
from cte
where del_both = 0;

--Question 8 (Method 2)
select  cuo.order_id, customer_id,  count (cuo.order_id) AS delivered_with_exclusions_and_extras
FROM public.customer_orders as cuo
INNER JOIN public.runner_orders as ruo
ON cuo.order_id = ruo.order_id
where pickup_time <> 'null' AND exclusions <> 'null' AND extras <> 'null' AND exclusions <> '' AND extras <> ''
Group by cuo.order_id, customer_id;

--Question 9 What was the total volume of pizzas ordered for each hour of the day?
select DATE_PART('hour', order_time) AS hour, count (pizza_id) pizza_ordered
from public.customer_orders
group by DATE_PART('hour', order_time);

--Question 10 What was the volume of orders for each day of the week?
select DATE_PART('day', order_time) AS day, count (pizza_id) pizza_ordered, TO_CHAR (order_time, 'Day') AS day_of_week
from public.customer_orders
group by DATE_PART('day', order_time), TO_CHAR (order_time, 'Day')
order by DATE_PART('day', order_time);

select EXTRACT (day from order_time) AS day, count (pizza_id) pizza_ordered, TO_CHAR (order_time, 'Day') AS day_of_week
from public.customer_orders
group by EXTRACT (day FROM order_time), TO_CHAR (order_time, 'Day')
order by EXTRACT (day from order_time);


/*Section B
QUESTION 1 How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)*/
SELECT DATE_TRUNC ('week', registration_date) + INTERVAL '4 days' AS week, count (runner_id) as runners
FROM public.runners
GROUP BY DATE_TRUNC ('week', registration_date)+ INTERVAL '4 days';

/*Question 2 What was the average time in minutes it took for each runner to 
arrive at the Pizza Runner HQto pickup the order?

 I did this in 2 ways, first I changed the datatype of the pickup_time column from char var to timestamp.
before i used it in calculating the time difference and i changed it back.*/

ALTER TABLE runner_orders
ALTER COLUMN pickup_time TYPE TIMESTAMP
USING (
  CASE 
    WHEN pickup_time IS NULL THEN NULL::TIMESTAMP
    ELSE to_timestamp(NULLIF(pickup_time, 'null'), 'YYYY-MM-DD HH24:MI:SS')
END);

SELECT runner_id, EXTRACT (minutes from AVG (pickup_time - order_time)) arrive
FROM public.customer_orders AS cuo
INNER JOIN public.runner_orders AS ruo
ON cuo.order_id = ruo.order_id
WHERE pickup_time IS NOT NULL
Group by runner_id;

ALTER TABLE runner_orders
ALTER COLUMN pickup_time TYPE Character Varying;


SELECT runner_id,
EXTRACT (minute from (AVG (pickup_time::TIMESTAMP - order_time))) arrive
FROM runner_orders as ruo
INNER JOIN customer_orders as cuo
ON ruo.order_id = cuo.order_id
WHERE pickup_time IS NOT NULL
GROUP BY runner_id;

--Question 3 Is there any relationship between the number of pizzas and how long the order takes to prepare?
with cte as (SELECT cuo.order_id, COUNT (pizza_id) as num_of_pizzas,
EXTRACT (minute from (MAX (pickup_time::TIMESTAMP - order_time))) prep_time
FROM runner_orders as ruo
INNER JOIN customer_orders as cuo
ON ruo.order_id = cuo.order_id
WHERE pickup_time IS NOT NULL
GROUP BY cuo.order_id)

SELECT num_of_pizzas, AVG (prep_time) as prep_time
FROM cte
GROUP by num_of_pizzas;

--Question 4 What was the average distance travelled for each customer?
UPDATE runner_orders
SET distance = regexp_replace(distance, '[^0-9.]', '', 'g');

SELECT customer_id, ROUND (AVG(distance::numeric), 2) avg_distance
FROM runner_orders as ruo
LEFT JOIN customer_orders as cuo
ON ruo.order_id = cuo.order_id
WHERE distance <> ''
GROUP BY customer_id
ORDER BY customer_id;

--Question 5 What was the difference between the longest and shortest delivery times for all orders?
SELECT *
FROM runner_orders;

UPDATE runner_orders
SET duration = regexp_replace(duration, '[^0-9.]', '', 'g');

SELECT (MAX(duration::numeric)- MIN(duration::numeric)) as diff_dev_times
FROM runner_orders as ruo
LEFT JOIN customer_orders as cuo
ON ruo.order_id = cuo.order_id
WHERE duration <> '';

--Question 6 What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT cuo.order_id, runner_id, ROUND (AVG(distance::numeric/duration::numeric), 2) as avg_speed
FROM runner_orders as ruo
LEFT JOIN customer_orders as cuo
ON ruo.order_id = cuo.order_id
WHERE duration <> '' AND distance <> ''
GROUP BY cuo.order_id, runner_id
ORDER BY runner_id, cuo.order_id;

--Question 7 What is the successful delivery percentage for each runner?
SELECT runner_id, CONCAT((ROUND ((sum::numeric/suc_dev::numeric)*100)), '%')as success
FROM (SELECT runner_id,
	SUM(CASE 
		WHEN pickup_time IS NULL THEN 0
		ELSE 1
		END)as sum, COUNT(order_id) as suc_dev
FROM runner_orders
GROUP BY runner_id
ORDER BY runner_id) as new_tab;


/*SECTION C

Question 1 What are the standard ingredients for each pizza?*/
SELECT topping_name, COUNT (DISTINCT pizza_id) as std_ingre
FROM (SELECT *, regexp_SPLIT_TO_TABLE (toppings, ',')::int as split_top_id
FROM pizza_recipes) as pr
LEFT JOIN pizza_toppings as pt
ON pr.split_top_id = pt.topping_id
GROUP BY topping_name
HAVING COUNT (DISTINCT pizza_id) = 2;

--Question 2 What was the most commonly added extra?
WITH CTE AS (SELECT TRIM (each_extra)::int as used_extra, COUNT (pizza_id) as mostly_used
FROM(SELECT *,regexp_SPLIT_TO_TABLE (extras, ',')as each_extra
FROM customer_orders) as cuo
WHERE LENGTH (each_extra) > 0
AND each_extra <> 'null'
GROUP BY each_extra)

SELECT topping_name, mostly_used
FROM CTE as cuo
INNER JOIN pizza_toppings as pt
ON cuo.used_extra = pt.topping_id
ORDER BY mostly_used desc
LIMIT 1;

--QUESTION 3 What was the most common exclusion?
WITH CTE AS (SELECT TRIM (each_exclusion)::int as used_exclusion, COUNT (pizza_id) as mostly_removed
FROM(SELECT *,regexp_SPLIT_TO_TABLE (exclusions, ',')as each_exclusion
FROM customer_orders) as cuo
WHERE LENGTH (each_exclusion) > 0
AND each_exclusion <> 'null'
GROUP BY each_exclusion)

SELECT topping_name, mostly_removed
FROM CTE as cuo
INNER JOIN pizza_toppings as pt
ON cuo.used_exclusion = pt.topping_id
ORDER BY mostly_removed desc
LIMIT 1;

/*Question 5 Generate an order item for each record in the customers_orders table in the format of one of the following:
Meat Lovers
Meat Lovers - Exclude Beef
Meat Lovers - Extra Bacon
Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers*/

WITH EXTRA AS (SELECT EXTRA.order_id, pizza_id, STRING_AGG(topping_name, ', ') as added_extra
	FROM (SELECT cuo.order_id, pizza_id,TRIM (each_extra)::int as used_extra
	FROM(SELECT *,regexp_SPLIT_TO_TABLE (extras, ',')as each_extra
	FROM customer_orders) as cuo
	WHERE LENGTH (each_extra) > 0
	AND each_extra <> 'null'
	)as EXTRA
	INNER JOIN pizza_toppings as pt
	ON EXTRA.used_extra = pt.topping_id
	GROUP BY EXTRA.order_id, pizza_id)

,	EXCLUDED AS (SELECT EXCLUDED.order_id, pizza_id, STRING_AGG(topping_name, ', ') as had_exclusion
	FROM (SELECT cuo.order_id, pizza_id,TRIM (each_exclusion)::int as used_exclusion
	FROM(SELECT *,regexp_SPLIT_TO_TABLE (exclusions, ',')as each_exclusion
	FROM customer_orders) as cuo
	WHERE LENGTH (each_exclusion) > 0
	AND each_exclusion <> 'null'
	)as EXCLUDED
	INNER JOIN pizza_toppings as pt
	ON EXCLUDED.used_exclusion = pt.topping_id
	GROUP BY EXCLUDED.order_id, pizza_id)
	
	SELECT	cuo.order_id, cuo.pizza_id, CONCAT(CASE 
	WHEN pizza_name = 'Meatlovers' THEN 'Meat Lovers'
	ELSE pizza_name END, COALESCE ('- EXTRA ' ||added_extra, '' ), 
	COALESCE('- EXCLUDE ' || had_exclusion, '')) as order_details
	FROM customer_orders as cuo
	LEFT JOIN EXTRA AS ext ON cuo.order_id = ext.order_id AND ext.pizza_id = cuo.pizza_id 
	LEFT JOIN EXCLUDED AS exc ON cuo.order_id = exc.order_id AND exc.pizza_id = cuo.pizza_id 
	INNER JOIN pizza_names as pn ON pn.pizza_id = cuo.pizza_id;

/*Question 5 Generate an alphabetically ordered comma separated ingredient list for each pizza order 
from the customer_orders table and add a 2x in front of any relevant ingredients
For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"*/
 
WITH EXTRA AS (SELECT EXTRA.order_id,pt.topping_id, pizza_id, topping_name
	FROM (SELECT cuo.order_id, pizza_id,TRIM (each_extra)::int as used_extra
	FROM(SELECT *,regexp_SPLIT_TO_TABLE (extras, ',')as each_extra
	FROM customer_orders) as cuo
	WHERE LENGTH (each_extra) > 0
	AND each_extra <> 'null'
	)as EXTRA
	INNER JOIN pizza_toppings as pt
	ON EXTRA.used_extra = pt.topping_id)
	
, EXCLUDED AS (SELECT EXCLUDED.order_id, pizza_id, pt.topping_id,topping_name 
	FROM (SELECT cuo.order_id, pizza_id,TRIM (each_exclusion)::int as used_exclusion
	FROM(SELECT *,regexp_SPLIT_TO_TABLE (exclusions, ',')as each_exclusion
	FROM customer_orders) as cuo
	WHERE LENGTH (each_exclusion) > 0
	AND each_exclusion <> 'null'
	)as EXCLUDED
	INNER JOIN pizza_toppings as pt
	ON EXCLUDED.used_exclusion = pt.topping_id)
	
, ORDERS AS (SELECT order_id, pizza_id, topping_id, topping_name
			 FROM  (SELECT cuo.order_id, cuo.pizza_id, toppings, TRIM (regexp_SPLIT_TO_TABLE (toppings, ','))::int as S
					FROM customer_orders as cuo
					INNER JOIN pizza_recipes as pr ON cuo.pizza_id = pr.pizza_id) as co
			INNER JOIN pizza_toppings as pt ON co.s = pt.topping_id
)

, orders_with_ext_and_exc AS (SELECT o.order_id, o.pizza_id, o.topping_id, o.topping_name
FROM ORDERS as o
LEFT JOIN EXCLUDED AS exc on o.order_id = exc.order_id AND o.pizza_id =exc.order_id AND o.topping_id = exc.topping_id
WHERE exc.topping_id IS NULL

UNION ALL 

SELECT order_id, pizza_id, topping_id, topping_name
FROM EXTRA)

, All_together AS (SELECT order_id, pizza_name, topping_name, COUNT(topping_id) as C
FROM orders_with_ext_and_exc as owee
INNER JOIN pizza_names as pn ON owee.pizza_id = pn.pizza_id
GROUP BY order_id,  pizza_name, topping_name
)

, JOINED AS (SELECT order_id, pizza_name,  
STRING_AGG (CASE 
WHEN c > 1 THEN c || 'x' || topping_name
ELSE topping_name
END, ', ') as ingred
FROM All_together
GROUP BY order_id, pizza_name
)

SELECT order_id,
CONCAT ((CASE 
WHEN pizza_name = 'Meatlovers' THEN 'Meat Lovers' ELSE pizza_name 
END), ': ', ingred) as ingredients
FROM JOINED;

--Question 6 What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH EXTRA AS (SELECT EXTRA.order_id,pt.topping_id, pizza_id, topping_name
	FROM (SELECT cuo.order_id, pizza_id,TRIM (each_extra)::int as used_extra
	FROM(SELECT *,regexp_SPLIT_TO_TABLE (extras, ',')as each_extra
	FROM customer_orders) as cuo
	WHERE LENGTH (each_extra) > 0
	AND each_extra <> 'null'
	)as EXTRA
	INNER JOIN pizza_toppings as pt
	ON EXTRA.used_extra = pt.topping_id)
	
, EXCLUDED AS (SELECT EXCLUDED.order_id, pizza_id, pt.topping_id,topping_name 
	FROM (SELECT cuo.order_id, pizza_id,TRIM (each_exclusion)::int as used_exclusion
	FROM(SELECT *,regexp_SPLIT_TO_TABLE (exclusions, ',')as each_exclusion
	FROM customer_orders) as cuo
	WHERE LENGTH (each_exclusion) > 0
	AND each_exclusion <> 'null'
	)as EXCLUDED
	INNER JOIN pizza_toppings as pt
	ON EXCLUDED.used_exclusion = pt.topping_id)
	
, ORDERS AS (SELECT order_id, pizza_id, topping_id, topping_name
			 FROM  (SELECT cuo.order_id, cuo.pizza_id, toppings, TRIM (regexp_SPLIT_TO_TABLE (toppings, ','))::int as S
					FROM customer_orders as cuo
					INNER JOIN pizza_recipes as pr ON cuo.pizza_id = pr.pizza_id) as co
			INNER JOIN pizza_toppings as pt ON co.s = pt.topping_id
)

, orders_with_ext_and_exc AS (SELECT o.order_id, o.pizza_id, o.topping_id, o.topping_name
FROM ORDERS as o
LEFT JOIN EXCLUDED AS exc on o.order_id = exc.order_id AND o.pizza_id =exc.order_id AND o.topping_id = exc.topping_id
WHERE exc.topping_id IS NULL

UNION ALL 

SELECT order_id, pizza_id, topping_id, topping_name
FROM EXTRA)

SELECT topping_name, COUNT(topping_id) as quantity
FROM orders_with_ext_and_exc as owee
INNER JOIN runner_orders as ro ON owee.order_id = ro.order_id
WHERE cancellation IS NULL OR cancellation = 'null' OR cancellation = ''
GROUP BY topping_name
ORDER BY COUNT (topping_id) DESC;


/*SECTION D 
Question 1 If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes -
how much money has Pizza Runner made so far if there are no delivery fees?*/

WITH pizza_num AS (SELECT customer_id, pizza_name, count (cuo.pizza_id) :: numeric as num_of_pizza
FROM public.customer_orders AS cuo
LEFT JOIN public.pizza_names AS pn
ON cuo.pizza_id = pn.pizza_id
LEFT JOIN runner_orders as ro ON cuo.order_id = ro.order_id
WHERE pickup_time <> 'null'
GROUP BY customer_id, pizza_name
)

SELECT 
CONCAT ('$', SUM (CASE 
WHEN pizza_name = 'Meatlovers' THEN num_of_pizza * 12
WHEN pizza_name = 'Vegetarian' THEN num_of_pizza * 10
ELSE 0 END)) as Total_Pricing
FROM pizza_num; 

/*Question 2 What if there was an additional $1 charge for any pizza extras?
Add cheese is $1 extra*/

WITH pizza_and_extras AS (
	SELECT customer_id, pizza_name,
	COUNT (cuo.pizza_id) :: numeric as num_of_pizza,
	(CASE WHEN extras IN ('', 'null', NULL) THEN NULL
	WHEN extras IS NULL THEN NULL
	 WHEN extras = '1, 4' THEN '2'
	ELSE extras END)::numeric as new_extras
	FROM public.customer_orders AS cuo
	LEFT JOIN public.pizza_names AS pn
	ON cuo.pizza_id = pn.pizza_id
	LEFT JOIN runner_orders as ro ON cuo.order_id = ro.order_id
	WHERE pickup_time <> 'null' OR pickup_time IS NOT NULL
	GROUP BY customer_id, pizza_name, extras
	)

SELECT CONCAT ('$', (SUM (CASE 
WHEN pizza_name = 'Meatlovers' THEN num_of_pizza * 12
WHEN pizza_name = 'Vegetarian' THEN num_of_pizza * 10
ELSE 0 END)) + (SUM (new_extras)))as total_money
FROM pizza_and_extras;


/*Question 3 If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and 
each runner is paid $0.30 per kilometre traveled - 
how much money does Pizza Runner have left over after these deliveries?*/
WITH pizza_num AS (
SELECT customer_id, (distance:: numeric) * 0.3 as dist_money, pizza_name, count (cuo.pizza_id) :: numeric as num_of_pizza
FROM public.customer_orders AS cuo
LEFT JOIN public.pizza_names AS pn
ON cuo.pizza_id = pn.pizza_id
LEFT JOIN runner_orders as ro ON cuo.order_id = ro.order_id
WHERE pickup_time <> 'null'
GROUP BY customer_id, pizza_name, distance:: numeric
)

SELECT CONCAT ('$', (SUM (CASE 
WHEN pizza_name = 'Meatlovers' THEN num_of_pizza * 12
WHEN pizza_name = 'Vegetarian' THEN num_of_pizza * 10
ELSE 0 END)) - (SUM (dist_money)))as total_money
FROM pizza_num;
