-- This Query seeks to measure the KPI of delivery sites so as to determine efficiency
-- A total of 8 tables will be used for the analysis, and the KPIs are:
-- Same day arrival VS collection (This measures the percentage of parcels arrived on day Y and delivered on day Y)
-- Daily collection rate (This KPI measures the percentage of parcels delivered per day)
-- Open runsheet (This KPI measures the % of packages closed on the system)
-- Vendor parcel return (This KPI measures the total number of parcels returned to vendors within the stipulated SLA)

-- Running Query for same day arrival VS collection KPI And Vendor parcel return

CREATE TEMP TABLE wrong_sorting_table AS
-- This table captures parcels that were sorted to a wrong delivery hub
(
    SELECT
        DISTINCT(waybill || site) AS unique_identifier, -- This helps to capture that only distinct scan by waybill per delivery site
        Waybill,
        site,
        type AS IssueType
    FROM
        issue_parcel ip
    WHERE
        type = 'Wrong Sorting'
);

SELECT
    a.waybill,
    a.arrival_date,
    a.site_name,
    CASE
        WHEN a.cod > 0 THEN 'COD'
        ELSE 'Prepaid'
    END AS parcel_type, -- This helps to determine if the package is cash on delivery (COD) or prepaid
    CASE
        WHEN w.IssueType = 'Wrong Sorting' THEN 1
        ELSE 0
    END AS wrong_sorting_flag, -- This helps to determine if the package was wrongly sorted to the site or not
    CASE
        WHEN si.type = 'D2' AND TO_CHAR(arrival_date, 'dy') <> 'sat' AND -- Since D2 site has a day to carry out delivery and Sunday is not a working day, the delivery SLA elapses by Monday
            s.scan_date - a.arrival_date <= 1 THEN 1
        WHEN si.site = 'D2' AND TO_CHAR(arrival_date, 'dy') = 'sat' AND
            s.scan_date - a.arrival_date <= 2 THEN 1
        WHEN si.site <> 'D2' AND s.scan_date = a.arrival_date THEN 1
        ELSE 0
    END AS SASC, -- This helps to identify if the package delivery met the stipulated SLA
    CASE
        WHEN s.signed_time IS NULL AND r.return_date - a.arrival_date <= 7 THEN 1
        WHEN s.signed_time IS NULL AND r.return_date IS NULL AND '2023-07-31' - r.return_date <= 7 THEN 1 -- Thus measures if the parcel was returned within 7 days
        ELSE 0
    END AS ONTIME_RETURN,
    CASE
        WHEN se.sender IN ('OPAY', 'FAIRMONEY', 'KUDA', 'CARBON', 'OPAY AGENT') THEN 1
        ELSE 0
    END AS sender_flag, -- Parcels by specific sender stay at the hub for 30 days
    CASE
        WHEN a.waybill IS NOT NULL THEN 1
        ELSE 0
    END AS arrived_volume,
    CASE
        WHEN RIGHT(a.waybill, 1) = 'E' OR RIGHT(a.waybill, 2) = 'ES' THEN 'ECONOMY'
        ELSE 'STANDARD'
    END AS shipment_type,
    CASE
        WHEN a.waybill IS NOT NULL AND s.scan_date IS NULL THEN 1
        ELSE 0
    END AS return_vol,
    CASE
        WHEN a.site_name = r.pickup_site THEN 1
        ELSE 0
    END AS pickupsite_flag
FROM
    arrival a
LEFT JOIN
    signed s ON a.waybill = s.waybill
    AND a.site_name = s.site
LEFT JOIN
    wrong_sorting_table w ON a.waybill = w.waybill
    AND a.site_name = w.site
LEFT JOIN
    site si ON a.site_name = si.site
LEFT JOIN
    return r ON a.waybill = r.waybill
    AND a.site_name = r.site
LEFT JOIN
    sender se ON a.waybill = se.waybill;

-- Running Query for Daily collection rate (CR) AND Open runsheet (OR) KPI

WITH issue AS
-- Creating CTE, this Query ensures that only one scan for a waybill is captured per time.
(
    SELECT
        DISTINCT(waybill || scan_date || site) AS Unique_waybill,
        waybill,
        site,
        scan_date
    FROM
        issue_parcel
)
SELECT
    d.Waybill,
    d.site,
    d.delivery_date,
    s.scan_date AS signed_date,
    i.scan_date AS issue_date,
    CASE
        WHEN d.delivery_date = s.scan_date THEN 1
        ELSE 0
    END AS CR,
    CASE
        WHEN d.waybill IS NOT NULL THEN 1
        ELSE 0
    END AS Delivery_Volume,
    CASE
        WHEN s.scan_date IS NOT NULL THEN 1
        ELSE 0
    END AS Volume_collected,
    CASE
        WHEN am.COD <= 0 THEN 'Prepaid'
        ELSE 'COD'
    END AS Parcel_Type,
    CASE
        WHEN RIGHT(d.waybill, 1) = 'E' OR RIGHT(d.waybill, 2) = 'ES' THEN 'ECONOMY'
        ELSE 'STANDARD'
    END AS shipment_type,
    CASE
        WHEN d.delivery_date = s.scan_date THEN 1
        WHEN d.delivery_date = i.scan_date THEN 1
        ELSE 0
    END AS OR
FROM
    delivery d
LEFT JOIN
    issue i ON d.waybill = i.waybill
    AND d.site = i.site
    AND d.delivery_date = i.scan_date
LEFT JOIN
    signed s ON d.waybill = s.waybill
    AND d.site = s.site
    AND d.delivery_date = s.scan_date
LEFT JOIN
    amount am ON d.waybill = am.waybill;