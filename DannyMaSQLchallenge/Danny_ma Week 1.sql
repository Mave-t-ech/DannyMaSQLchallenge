SELECT * FROM dannys_diner.menu;
SELECT * FROM dannys_diner.sales;
SELECT * FROM dannys_diner.members;

--Question 1 the total amount spent by each customer.
WITH cte_sales as (SELECT customer_id, sales.product_id, SUM(price) AS Amount_spent, menu.product_name
FROM dannys_diner.sales AS sales
LEFT JOIN dannys_diner.menu AS Menu
ON sales.product_id = menu.product_id
GROUP BY customer_id, sales.product_id, menu.product_name
ORDER BY customer_id)
SELECT customer_id, SUM (amount_spent) AS total_spent
FROM cte_sales
GROUP BY customer_id;

--Question 1 method 2. lmaooo
SELECT customer_id, SUM (amount_spent) AS total_spent
FROM (SELECT customer_id, sales.product_id, SUM(price) AS Amount_spent, menu.product_name
FROM dannys_diner.sales AS sales
LEFT JOIN dannys_diner.menu AS Menu
ON sales.product_id = menu.product_id
GROUP BY customer_id, sales.product_id, menu.product_name
ORDER BY customer_id ) AS New_table
GROUP BY customer_id;

-- Q2 What is the number of days each customer visited?
SELECT customer_id, COUNT(DISTINCT order_date) AS no_of_days
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY customer_id;

--Q3 what was the first item on the menu purcahsed by the customer?
SELECT *
FROM (SELECT customer_id, product_name, product_id, order_date,
RANK () OVER (PARTITION BY customer_id ORDER BY order_date) AS rnk,
ROW_NUMBER () OVER (PARTITION BY customer_id ORDER BY order_date) AS rw
FROM (SELECT customer_id, order_date, sales.product_id, SUM(price) AS Amount_spent, menu.product_name
FROM dannys_diner.sales AS sales
LEFT JOIN dannys_diner.menu AS Menu
ON sales.product_id = menu.product_id
GROUP BY customer_id, sales.product_id, menu.product_name, order_date
ORDER BY customer_id) AS new_table) AS old_table
WHERE rw = 1;

-- Q4 
--what is the most purchased item on the menu and how many times was it purchased?
SELECT menu.product_name, COUNT (order_date) AS most_purchased
FROM dannys_diner.sales AS sales
LEFT JOIN  dannys_diner.menu AS Menu
ON sales.product_id = menu.product_id
GROUP BY menu.product_name
ORDER BY COUNT (order_date) DESC
LIMIT 1;

/* Q5 which item is the most popular for each customer? */
SELECT*
FROM (SELECT customer_id, COUNT (order_date), product_name,
ROW_NUMBER () OVER (PARTITION BY customer_id ORDER BY COUNT (order_date)) AS rnk
FROM dannys_diner.sales AS s
LEFT JOIN dannys_diner.menu AS M
ON s.product_id = m.product_id
GROUP BY product_name, s.customer_id
ORDER BY product_name DESC) AS new_new
WHERE rnk = 1;

--Q6 which item was purchased first after they became a member?

WITH cte AS (SELECT customer_id, order_date, m.product_id, join_date, product_name, price,
Row_number () Over (PARTITION by customer_id ORDER BY order_date) AS rnk
FROM (SELECT s.customer_id, order_date, product_id, join_date
FROM dannys_diner.sales AS s
LEFT JOIN dannys_diner.members AS mb
ON s.customer_id = mb.customer_id) AS mem_table
LEFT JOIN dannys_diner.menu AS m
ON mem_table.product_id = m.product_id
WHERE order_date >= join_date)

SELECT *
FROM cte
WHERE rnk = 1;


--Q7 which item was purchased just before they became a member
WITH cte AS (SELECT customer_id, order_date, m.product_id, join_date, product_name, price,
ROW_NUMBER () Over (PARTITION by customer_id ORDER BY order_date desc) AS rwn,
RANK () OVER (PARTITION by customer_id ORDER BY order_date desc) AS rnk
FROM (SELECT s.customer_id, order_date, product_id, join_date
FROM dannys_diner.sales AS s
LEFT JOIN dannys_diner.members AS mb
ON s.customer_id = mb.customer_id) AS mem_table
LEFT JOIN dannys_diner.menu AS m
ON mem_table.product_id = m.product_id
WHERE order_date < join_date)

SELECT customer_id, order_date, product_name, rwn, rnk
FROM cte
WHERE rwn = 1;

--Q8 What is the total items and amount spent for each member before they became a member?
SELECT s.customer_id, COUNT(product_name) AS total_item, SUM(price) AS total_amount_spent
FROM dannys_diner.sales AS s
LEFT JOIN dannys_diner.members AS mb
ON s.customer_id = mb.customer_id
inner join dannys_diner.menu AS m ON s.product_id = m.product_id
WHERE join_date > order_date
GROUP BY s.customer_id;

--Q9 If each $1 spent equates to 10 points and sushi hAS a 2x points multiplier, how many points would each customer have?
WITH CTE AS (SELECT s.customer_id, product_name, price,
CASE
	WHEN product_name = 'sushi' THEN 2*(price * 10)
	ELSE price * 10
	END AS Purchase_points
FROM dannys_diner.sales AS s
LEFT JOIN dannys_diner.members AS mb
ON s.customer_id = mb.customer_id
inner join dannys_diner.menu AS m ON s.product_id = m.product_id)

SELECT customer_id, SUM (purchase_points), COUNT(product_name)
FROM cte
GROUP BY customer_id;

/*Q 10 In the first week after a customer joins the program (including their join date) they earn 2x points 
ON all items, not just sushi - how many points do customer A and B have at the end of January? */

WITH cte AS (SELECT *,
CASE 
WHEN new_date > 1 THEN price * 20
WHEN new_date = 0 THEN price * 20
WHEN new_date > 7 THEN price * 10
WHEN product_name = 'sushi' THEN price * 20
ELSE price * 10
END AS Purchase_points
FROM (SELECT s.customer_id, product_name, order_date, join_date, price, (order_date - join_date) AS new_date
	  FROM dannys_diner.sales AS s
LEFT JOIN dannys_diner.members AS mb
ON s.customer_id = mb.customer_id
inner join dannys_diner.menu AS m ON s.product_id = m.product_id
) AS point_table)

SELECT customer_id, SUM(purchase_points), COUNT (product_name)
FROM cte
WHERE order_date BETWEEN '2021-01-01' AND '2021-01-31'
AND customer_id BETWEEN 'A' AND 'B'
GROUP BY customer_id;