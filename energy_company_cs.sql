USE energy_cs;

SHOW TABLES;

DESC customers;
DESC energy_consumption;
DESC energy_production;
DESC production_plants;
DESC sustainability_initiatives;

/* Write a query to list the top 5 production plants with the highest average carbon emissions
per unit of energy produced (in kg/kWh). Include the plant name, location, and average carbon emissions per kWh.*/
SELECT plant_name,location, AVG(carbon_emission_per_unit) AS average_carbon_emission
FROM(
SELECT PP.plant_name, PP.location, SUM(EP.carbon_emission_kg)/SUM(EP.amount_kwh) AS carbon_emission_per_unit
FROM production_plants PP
JOIN energy_production EP ON EP.production_plant_id = PP.plant_id
GROUP BY PP.plant_name, PP.location
) AS A
GROUP BY plant_name,location
ORDER BY average_carbon_emission DESC
LIMIT 5;

/* Write a query to list the top 3 sustainability initiatives based on the total energy savings achieved.
Include the initiative name, start date, end date, and total energy savings. The resulting table should be in descending order for the total energy savings column.*/
SELECT initiative_name, start_date, end_date, SUM(energy_savings_kwh) AS energy_savings_kwh
FROM sustainability_initiatives
GROUP BY initiative_name, start_date, end_date
ORDER BY energy_savings_kwh DESC
LIMIT 3;

/* Write a query to list all energy production records along with a new column that shows the total energy production amount for each energy_type.
The resulting table should contain production ID, production plant ID, the date of production, energy type,
amount of production and the total amount according to the energy type.*/
SELECT production_id, production_plant_id, date, energy_type, amount_kwh, SUM(amount_kwh) OVER(PARTITION BY energy_type) AS total_energy_by_type
FROM energy_production;

/* Write a SQL query that lists all energy production records and includes a new column for ranking the production amount within each energy type.
The rank should be calculated such that it reflects the relative position of each production record within its respective energy type,
based on the production amount. The resulting output should contain the customer ID, customer name,
total consumption for the customer, and the average monthly consumption.*/
SELECT production_id, production_plant_id, date, energy_type, amount_kwh, RANK() OVER(PARTITION BY energy_type ORDER BY amount_kwh DESC) AS rank_within_type
FROM energy_production;

/*Write a query to list all energy consumption records while also providing a new column that displays the cumulative energy consumption for each customer over time.
The cumulative consumption should be calculated in a way that adds up the energy consumed by each customer up to each record, based on the date of consumption.
The resulting table should contain consumption ID, customer ID, date of consumption, energy type, amount consumed by the customer, and the cumulative consumption.*/
SELECT consumption_id, customer_id, date, energy_type, amount_kwh, SUM(amount_kwh) OVER(PARTITION BY customer_id ORDER BY date) AS cumulative_consumption
FROM energy_consumption;

/*Write a query to list the monthly energy production amounts for each plant along with the previous month's production amount and the next month's production amount
Include columns for the plant ID, month, current month's production amount, previous month's production amount, and next month's production amount.*/
WITH monthly_production AS (
    SELECT production_plant_id AS production_plant_id, DATE_FORMAT(date, '%Y-%m-01') AS month,
    SUM(amount_kwh) AS current_month_production
    FROM energy_production
    GROUP BY production_plant_id, DATE_FORMAT(date, '%Y-%m-01')
)
SELECT production_plant_id, month,current_month_production,
LAG(current_month_production) OVER (PARTITION BY production_plant_id ORDER BY month) AS previous_month_production,
LEAD(current_month_production) OVER (PARTITION BY production_plant_id ORDER BY month) AS next_month_production
FROM monthly_production
ORDER BY production_plant_id, month;

/*Write a query to list the production plant ID, energy type, date, and amount of the top 3 highest energy production records for each energy type.
 Ensure that you assign a unique rank to each record within its energy type category. 
 The resulting table should contain the production plant ID, energy type, date of the production and the amount that the plant has produced.
 The output table should be in ascending order for energy type and the ranking.*/
WITH ranked_productions AS (
    SELECT production_plant_id, energy_type,date,amount_kwh,
    ROW_NUMBER() OVER (PARTITION BY energy_type ORDER BY amount_kwh DESC) AS rn
    FROM energy_production
)
SELECT production_plant_id,energy_type,date,amount_kwh
FROM ranked_productions
WHERE rn <= 3
ORDER BY energy_type, rn;

/*Write a query to rank the production plants based on their average monthly energy production. Include columns for plant ID, month, 
average monthly production, and rank. The resulting table should be in ascending order for the month and the ranking column.*/
WITH Temp AS(
SELECT production_plant_id, DATE_FORMAT(date, '%Y-%m') AS month, AVG(amount_kwh) AS avg_monthly_production
FROM energy_production
GROUP BY production_plant_id, month
)
SELECT production_plant_id, month, avg_monthly_production, RANK () OVER(PARTITION BY month ORDER BY avg_monthly_production DESC) AS ranking
FROM Temp
ORDER BY month, ranking;

/*Write a query to rank the sustainability initiatives based on their total energy savings. The query should include columns for the initiative name,
start date, end date, total energy savings, and their rank based on these savings.*/
WITH Temp AS(
SELECT initiative_name, start_date, end_date, SUM(energy_savings_kwh) AS energy_savings_kwh
FROM sustainability_initiatives
GROUP BY initiative_name, start_date, end_date
)
SELECT initiative_name, start_date, end_date,energy_savings_kwh, RANK() OVER(ORDER BY energy_savings_kwh DESC) AS initiative_rank
FROM Temp;

/*Write a query to list the monthly energy production amounts for each plant along with the previous month's production amount and the next month's production amount.
Include columns for the plant ID, month, current month's production amount, previous month's production amount,and next month's production amount.
The resulting table should be order in ascending order for the production_plant_id and the month column.*/
WITH Temp AS(
SELECT production_plant_id, DATE_FORMAT(date, '%Y-%m') AS month, SUM(amount_kwh) AS current_month_production
FROM energy_production
GROUP BY production_plant_id, month
)
SELECT production_plant_id,month, current_month_production, 
LAG(current_month_production) OVER(PARTITION BY production_plant_id ORDER BY month) AS previous_month_production,
LEAD(current_month_production) OVER(PARTITION BY production_plant_id ORDER BY month) AS next_month_production
FROM Temp;

/*The energy_consumption table contains data on energy usage, including multiple entries per day and across different energy types (e.g., gas, electricity).
Your task is to write a SQL query that will list each customer's ID along with their first and last total daily consumption values in 2023.
Return the resulting table in ascending order by customer ID.*/
WITH daily_totals AS (
SELECT customer_id,date,SUM(amount_kwh) AS total_kwh
FROM energy_consumption
WHERE EXTRACT(YEAR FROM date) = 2023
GROUP BY customer_id, date
),
ranked AS (
SELECT customer_id,
ROUND(FIRST_VALUE(total_kwh) OVER (PARTITION BY customer_id ORDER BY date ASC), 2) AS first_consumption,
ROUND(FIRST_VALUE(total_kwh) OVER (PARTITION BY customer_id ORDER BY date DESC), 2) AS last_consumption
FROM daily_totals
)
SELECT DISTINCT customer_id,first_consumption,last_consumption
FROM ranked
ORDER BY customer_id;

/*Write a query to list each customer's total energy consumption and their average monthly consumption.
The output table should contain the customer_id, name, total consumption, and average monthly energy consumption.
The resulting table should be ordered in ascending order for the customer ID column.*/
WITH MonthlyConsumption AS (
SELECT customer_id,DATE_FORMAT(date, '%Y-%m') AS month_start,SUM(amount_kwh) AS monthly_consumption
FROM Energy_Consumption
GROUP BY customer_id, DATE_FORMAT(date, '%Y-%m')
)
SELECT C.customer_id,C.name,SUM(MC.monthly_consumption) AS total_consumption,
AVG(MC.monthly_consumption) AS avg_monthly_consumption
FROM Customers C
JOIN MonthlyConsumption MC ON C.customer_id = MC.customer_id
GROUP BY C.customer_id, C.name
ORDER BY C.customer_id;

/*Your task is to create a detailed SQL query that analyzes carbon emission data across all production plants. This query should utilize the
energy_production and production_plants tables to calculate both the average and total carbon emissions for each plant. 
The final output should list each production plant's ID, name,average carbon emissions, and total carbon emissions, ordered by the plant ID for easy reference.*/
WITH PlantEmissions AS (
SELECT ep.production_plant_id, pp.plant_name, ep.energy_type, ep.carbon_emission_kg 
FROM energy_production ep 
JOIN production_plants pp ON ep.production_plant_id = pp.plant_id
),
EmissionSummary AS (
SELECT production_plant_id, plant_name, 
AVG(carbon_emission_kg) OVER (PARTITION BY production_plant_id) AS avg_emissions, 
SUM(carbon_emission_kg) OVER (PARTITION BY production_plant_id) AS total_emissions 
FROM PlantEmissions
)
SELECT production_plant_id, plant_name, avg_emissions, total_emissions 
FROM EmissionSummary 
GROUP BY production_plant_id, plant_name, avg_emissions, total_emissions 
ORDER BY production_plant_id;

/*Write a query to list each initiative's total energy savings and the average monthly energy savings. The final output should present the
initiative ID, name, total savings, and average monthly savings, ordered by initiative ID.*/
WITH InitiativeMonths AS (
SELECT initiative_id,initiative_name,energy_savings_kwh,start_date,end_date,
TIMESTAMPDIFF(MONTH, start_date, end_date) AS total_months
FROM Sustainability_Initiatives
)
SELECT initiative_id,initiative_name,energy_savings_kwh AS total_savings,
ROUND(energy_savings_kwh / total_months, 2) AS avg_monthly_savings
FROM InitiativeMonths
ORDER BY initiative_id;