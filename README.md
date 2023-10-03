# KPI_ANALYSIS_SQL
The objective of this SQL project is to assess a delivery company's performance using key performance indicators (KPIs). It also calculates bonuses for each delivery outlet based on KPIs.
Disclaimer
Please note that the files used in this project will not be available due to privacy concerns.
SQL KPI Analysis Project README
Overview
The objective of this SQL project is to assess a delivery company's performance using key performance indicators (KPIs). It also calculates bonuses for each delivery outlet based on KPIs.
Requirements
•	Database: PostgreSQL (This project is designed for use with PostgreSQL).
Installation
No specific installation steps are needed for this project.
Usage
This project provides SQL scripts to extract and analyze KPIs. To get started:
1.	Ensure you have PostgreSQL installed and set up with your database.
2.	Open the SQL script in your preferred PostgreSQL environment.
3.	Review and customize the sample queries to match your specific dataset, date ranges, and requirements. Replace the sample data references in the queries with your own data.
4.	Execute the SQL queries to calculate and analyze the KPIs based on your own data.
Query Examples
I've provided sample SQL queries for each KPI. Below are examples of the SQL queries:

Same Day Arrival vs. Collection KPI

-- Measure parcels delivered on the same day they arrived
SELECT
    a.waybill,
    a.arrival_date,
    a.site_name,
    -- Add more fields and calculations as needed
FROM
    arrival a
LEFT JOIN
    signed s ON a.waybill = s.waybill
    AND a.site_name = s.site
-- Add more joins and conditions as needed

Daily Collection Rate (CR) KPI
-- Measure the daily percentage of parcels delivered
SELECT
    d.Waybill,
    d.site,
    d.delivery_date,
    -- Add more fields and calculations as needed
FROM
    delivery d
-- Add more joins and conditions as needed

Open Runsheet (OR) KPI

-- Track the percentage of packages closed on the system
SELECT
    OS.parcel_type,
    OS.site,
    OS.delivery_date,
    -- Add more fields and calculations as needed
FROM
    Openrunsheet_and_SDSC OS
-- Add more joins and conditions as needed

-- Monitor the total number of parcels returned to vendors within SLA
SELECT
    a.waybill,
    a.site_name,
    r.return_date,
    -- Add more fields and calculations as needed
FROM
    arrival a
LEFT JOIN
    return r ON a.waybill = r.waybill
    AND a.site_name = r.site
-- Add more joins and conditions as needed


Testing Queries

    To adapt the queries to your specific data and test them:

1)Replace the sample data references in the queries with your actual table names and column names.

2)Adjust filters, date ranges, and conditions to target the data you want to analyze.

3)Execute the SQL queries in your PostgreSQL environment to obtain KPI results.

## Schema

### Tables

#### Arrival

- `Waybill` (VARCHAR, NOT NULL)
- `Site_Name` (VARCHAR, NOT NULL)
- `Arrival_Date` (DATE, NOT NULL)
- `COD` (FLOAT, NOT NULL)
- `Arrival_Time` (TIMESTAMP, NOT NULL)

#### Sender

- `Waybill` (VARCHAR, NOT NULL)
- `Sender` (VARCHAR, NOT NULL)

#### Return

- `Waybill` (VARCHAR, NOT NULL)
- `Site` (VARCHAR, NOT NULL)
- `Return_Time` (TIMESTAMP, NOT NULL)
- `Return_Date` (DATE, NOT NULL)
- `Pickup_Site` (VARCHAR, NOT NULL)

#### Signed

- `Waybill` (VARCHAR, NOT NULL)
- `Site` (VARCHAR, NOT NULL)
- `Signed_Time` (TIMESTAMP, NOT NULL)
- `Scan_Date` (DATE, NOT NULL)

#### Issue_Parcel

- `Waybill` (VARCHAR, NOT NULL)
- `Site` (VARCHAR, NOT NULL)
- `Type` (VARCHAR, NOT NULL)
- `Scan_Date` (DATE, NOT NULL)

#### Delivery

- `Waybill` (VARCHAR, NOT NULL)
- `Site` (VARCHAR, NOT NULL)
- `Delivery_Date` (DATE, NOT NULL)
- `Delivery_Time` (TIMESTAMP, NOT NULL)

#### Site

- `Site` (VARCHAR, PRIMARY KEY)
- `Type` (VARCHAR)

#### Amount

- `Waybill` (VARCHAR, NOT NULL)
- `COD` (FLOAT)
- (PRIMARY KEY on `Waybill`)

### Relationships
### Relationships

- The `Waybill` column in the `Arrival` table is a foreign key that connects to:
  - The `Waybill` column in the `Sender` table.
  - The `Waybill` column in the `Return` table.
  - The `Waybill` column in the `Signed` table.
  - The `Waybill` column in the `Issue_Parcel` table.

- The `Waybill` column in the `Delivery` table is a foreign key that connects to:
  - The `Waybill` column in the `Signed` table.
  - The `Waybill` column in the `Issue_Parcel` table.

- These relationships illustrate how parcels (identified by the `Waybill` column) are tracked and linked across different stages of the delivery process.

- Additionally, the tables may also be joined based on time-related columns, such as `arrival_date`, `delivery_date`, `scan_date`, and `signed_time`, to further analyze the timing and efficiency of parcel deliveries.


Error Handling

While the SQL script is designed for efficiency, users may encounter errors or issues during query execution. Here are some general tips for error handling:

Syntax Errors: Double-check your SQL syntax for typos or mistakes in your queries. Ensure that all SQL keywords and table/column names are correctly spelled.

Data Availability: Make sure you have the necessary data available in your tables for the specified date ranges or conditions used in the queries.

Data Filtering: Ensure that you set the correct filters and conditions in your queries to target the desired data for KPI analysis.

If you encounter specific errors or issues, consider consulting the documentation of your PostgreSQL environment or seeking assistance from your database administrator.

Contribution

Contributions to this project are welcome. If you have ideas for improvements or additional features, please feel free to contribute by creating a pull request or raising an issue in the project's repository.
