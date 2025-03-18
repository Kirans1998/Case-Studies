CREATE DATABASE IF NOT EXISTS dannys_diner;
USE dannys_diner;


CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', 1),
  ('A', '2021-01-01', 2),
  ('A', '2021-01-07', 2),
  ('A', '2021-01-10', 3),
  ('A', '2021-01-11', 3),
  ('A', '2021-01-11', 3),
  ('B', '2021-01-01', 2),
  ('B', '2021-01-02', 2),
  ('B', '2021-01-04', 1),
  ('B', '2021-01-11', 1),
  ('B', '2021-01-16', 3),
  ('B', '2021-02-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-07', 3);
 

CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  (1, 'sushi', 10),
  (2, 'curry', 15),
  (3, 'ramen', 12);
  

CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

-- 1)What is the total amount each customer spent at the restaurant?

SELECT sales.customer_id, 
       SUM(menu.price) AS total_spent
FROM sales
JOIN menu 
ON sales.product_id = menu.product_id
GROUP BY sales.customer_id;


-- 2) How many days has each customer visited the restaurant?
SELECT customer_id ,COUNT(DISTINCT order_date) AS days_visited FROM sales
GROUP BY customer_id;
 
-- 3) What was the first item from the menu purchased by each customer?
WITH FirstPurchase AS(
    SELECT sales.customer_id, sales.order_date,menu.product_name,
	ROW_NUMBER() OVER (PARTITION BY sales.customer_id ORDER BY order_date ) AS rn
	FROM sales
    JOIN menu ON sales.product_id = menu.product_id
)
SELECT customer_id,product_name,order_date
FROM FirstPurchase
WHERE rn=1;


-- 4) What is the most purchased item on the menu and how many times was it purchased by all customers?

    SELECT menu.product_name, COUNT(sales.product_id) AS purchase_count
	FROM sales
    JOIN menu ON sales.product_id = menu.product_id
    GROUP BY menu.product_name
    ORDER BY purchase_count DESC
    LIMIT 1;
    
 -- 5)   Which item was the most popular for each customer?
WITH ItemRank AS (
    SELECT 
        sales.customer_id, 
        menu.product_name, 
        COUNT(sales.product_id) AS purchase_count,
        RANK() OVER (PARTITION BY sales.customer_id ORDER BY COUNT(sales.product_id) DESC) AS rn
    FROM sales     
    JOIN menu ON sales.product_id = menu.product_id
    GROUP BY sales.customer_id, menu.product_name
)
SELECT customer_id, product_name, purchase_count
FROM ItemRank
WHERE rn = 1;

-- 6) Which item was purchased first by the customer after they became a member?

WITH FirstPurchase AS(
  SELECT sales.customer_id, sales.order_date,menu.product_name,
  RANK() OVER (PARTITION BY customer_id ORDER BY order_date) AS rnk
  FROM sales
  JOIN menu ON sales.product_id = menu.product_id 
  JOIN members ON sales.customer_id = members.customer_id
  WHERE order_date >= join_date
)
SELECT customer_id, order_date,product_name
FROM FirstPurchase
WHERE rnk = 1;

-- 7) Which item was purchased just before the customer became a member?
 SELECT s.customer_id, s.order_date, m.product_name
FROM sales s
JOIN menu m ON s.product_id = m.product_id
JOIN members mb ON s.customer_id = mb.customer_id
WHERE s.order_date < mb.join_date
AND s.order_date = (
    SELECT MAX(s2.order_date)
    FROM sales s2
    WHERE s2.customer_id = s.customer_id
    AND s2.order_date < mb.join_date
);


-- 8) What is the total items and amount spent for each member before they became a member?

 SELECT s.customer_id, COUNT(m.product_name)AS total_item,SUM(m.price) AS total_amount
FROM sales s
JOIN menu m ON s.product_id = m.product_id
JOIN members mb ON s.customer_id = mb.customer_id
WHERE s.order_date < mb.join_date
GROUP BY s.customer_id;

-- 9) If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT sales.customer_id,
 SUM(
      CASE 
          WHEN menu.product_name = 'sushi' THEN menu.price*10*2
          ELSE menu.price * 10
          END
          )AS total_amount
    FROM sales
    JOIN menu ON sales.product_id = menu.product_id
    GROUP BY customer_id
    ORDER BY total_amount DESC;
    
    
    
  SELECT sales.customer_id,
 SUM(
      CASE 
         WHEN sales.order_date  BETWEEN members.join_date AND DATE_ADD(members.join_date, INTERVAL 6 DAY)
         THEN menu.price *10 *2
          WHEN menu.product_name = 'sushi' THEN menu.price*10*2
          ELSE menu.price * 10
          END
          )AS total_points
    FROM sales
    JOIN menu ON sales.product_id = menu.product_id
    JOIN members ON sales.customer_id = members.customer_id
    WHERE sales.order_date <= '2021-01-31'
    GROUP BY customer_id
    ORDER BY total_points DESC;  
    
    
  SELECT sales.customer_id , sales.order_date, menu.product_name,menu.price,
    CASE
         WHEN sales.order_date >= members.join_date THEN 'Yes'
         ELSE 'No'
    END AS members,
    CASE
       WHEN sales.order_date >= members.join_date 
       THEN DENSE_RANK() OVER (PARTITION BY sales.customer_id,members ORDER BY sales.ORDER_DATE)
       ELSE null
       END AS Ranking
       
    FROM sales
    JOIN menu ON sales.product_id = menu.product_id
    LEFT JOIN members ON sales.customer_id = members.customer_id;
    
    
    
WITH RankedOrders AS (
    SELECT 
        s.customer_id, 
        s.order_date, 
        m.product_name, 
        m.price, 
        CASE 
            WHEN mb.join_date IS NULL OR s.order_date < mb.join_date THEN 'N' 
            ELSE 'Y' 
        END AS member_status,
        CASE 
            WHEN mb.join_date IS NULL OR s.order_date < mb.join_date THEN NULL
            ELSE DENSE_RANK() OVER (
                PARTITION BY s.customer_id, mb.customer_id 
                ORDER BY s.order_date
            )
        END AS ranking
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
    LEFT JOIN members mb ON s.customer_id = mb.customer_id
)
SELECT * FROM RankedOrders
ORDER BY customer_id, order_date;



    
