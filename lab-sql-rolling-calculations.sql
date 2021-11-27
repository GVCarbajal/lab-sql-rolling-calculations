use sakila;

-- Get number of monthly active customers.

select date_format(rental_date, "%Y") as year, 
date_format(rental_date, "%M") as month, 
count(customer_id) as active_customers 
from rental
group by month, year;


-- Active users in the previous month.

with monthly_active_customers as (
	select date_format(rental_date, "%Y") as year, 
	date_format(rental_date, "%M") as month, 
	count(customer_id) as active_customers 
	from rental
	group by month, year
    )
select *, lag (active_customers) over () as previous_month_customers from monthly_active_customers;


-- Percentage change in the number of active customers.

create or replace view customer_activity as
with monthly_active_customers as (
	select date_format(rental_date, "%Y") as year, 
	date_format(rental_date, "%M") as month, 
	count(customer_id) as active_customers 
	from rental
	group by month, year
    )
select *, lag (active_customers) over () as previous_month_customers from monthly_active_customers;

select *, round((active_customers - previous_month_customers) / previous_month_customers * 100, 2) as change_percent
from customer_activity;


-- Retained customers every month.

-- step 1: get the unique active users per month

create or replace view sakila.active_customers as
select
	distinct 
	customer_id as active_id,
	date_format(rental_date, "%Y") as activity_year, 
	date_format(rental_date, "%m") as activity_month
from rental
order by active_id, activity_year, activity_month;

select * from active_customers;


-- step 2: self join to find recurrent customers (customers that rented a film this month and also last month)
create or replace view sakila.recurrent_customers as
select a1.active_id, a1.activity_year, a1.activity_month from active_customers a1
join active_customers a2
on a1.activity_year = a2.activity_year -- case when m1.Activity_month = 1 then m1.Activity_year + 1 else m1.Activity_year end
and a1.activity_month = a2.activity_month+1 -- case when m2.Activity_month+1 = 13 then 12 else m2.Activity_month+1 end;
and a1.active_id = a2.active_id -- to get recurrent users
order by a1.active_id, a1.activity_year, a1.activity_month;

select * from recurrent_customers;

-- step 3: count recurrent customers per month 
create or replace view sakila.total_recurrent_customers as
select activity_year, activity_month, count(active_id) as recurrent_customers from recurrent_customers
group by activity_year, activity_month;

select * from total_recurrent_customers;


-- Retained customers every month.

with active_customers as (
	select
		distinct 
		customer_id as active_id,
		date_format(rental_date, "%Y") as activity_year, 
		date_format(rental_date, "%m") as activity_month
	from rental
	order by active_id, activity_year, activity_month
    )
select a1.activity_year, a1.activity_month, count(a1.active_id) as retained_customers from active_customers a1
join active_customers a2
on a1.active_id = a2.active_id -- to get recurrent users
and (a1.activity_month = case when a2.activity_month+1 = 13 then 1 else a2.activity_month+1 end)
and (a1.activity_year = case when a2.activity_month = 1 then a2.activity_year + 1 else a1.activity_year end)
group by activity_year, activity_month;