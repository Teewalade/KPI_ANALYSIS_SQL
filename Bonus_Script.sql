-- Running Query for Bonus Payable and Rank to Determine the Top 20 performing and Bottom performing site for the month
-- The bonus is determined based on the %KPI met
-- For Same day arrival Vs collection, the Target is 50%, and the amount payable is the number of prepaid parcels achieved * 50
-- For Daily collection rate KPI, the target is 50% for COD parcels and 85% for prepaid parcels. The amount Payable is the number of parcels delivered * 50
-- For Open runsheet KPI, the Target is 98%, and the amount payable is the total number of prepaid parcels delivered (per day * 50)
-- Vendor parcel return the Target for this is 95%, and the amount payable is 50 * the number of parcels returned within SLA


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





-- SASC PAYABLE & Vendor return PAYABLE
WITH Same_day_arrival_vendor_return AS
-- Creating CTE to analyze the payable amount from the previous analysis done
(
    SELECT
        a.waybill,
        a.arrival_date,
        a.site_name,
        s.signed_time,
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
        END AS "SASC", -- This helps to identify if the package delivery met the stipulated SLA
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
        sender se ON a.waybill = se.waybill
),
Openrunsheet_and_SDSC AS
-- CTE2 for the other two KPI
(
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
        amount am ON d.waybill = am.waybill
)
SELECT
    'SASC KPI' AS KPI,
    site_name,
    arrival_date,
    SUM(CASE WHEN parcel_type = 'Prepaid' AND "SASC" = 1 THEN 1 ELSE 0 END) AS "prepaid_VOL", -- This captures the prepaid volume successfully delivered to customers with SLA
    ROUND(SUM(CAST("SASC" AS Numeric)) / SUM(CAST(arrived_volume AS Numeric)), 4) AS percentage_achieved, -- This is the percentage met based on the total volume (both prepaid & COD) successfully delivered with SLA / Volume arrived
    CASE
        WHEN ROUND(SUM(CAST("SASC" AS Numeric)) / SUM(CAST(arrived_volume AS Numeric)), 2) * 100 >= 50.0 THEN CAST(SUM(CASE WHEN parcel_type = 'Prepaid' AND "SASC" = 1 THEN 1 ELSE 0 END) AS NUMERIC) * 50
        ELSE 0
    END AS "Payable_SASC"
FROM
    Same_day_arrival_vendor_return
WHERE
    wrong_sorting_flag <> 1 AND shipment_type = 'STANDARD' AND pickupsite_flag <> 1
GROUP BY
    1, 2, 3

UNION ALL

SELECT -- Query for vendor return KPI payable
    'Vendor return KPI' AS KPI,
    site_name,
    arrival_date,
    SUM(CASE WHEN parcel_type = 'Prepaid' AND ONTIME_RETURN = 1 THEN 1 ELSE 0 END) AS "prepaid_VOL", -- This captures the prepaid volume successfully delivered to customers with SLA
    ROUND(SUM(CAST(ONTIME_RETURN AS Numeric)) / SUM(CAST(arrived_volume AS Numeric)), 4) AS percentage_achieved, -- This is the percentage met based on the total volume (both prepaid & COD) successfully delivered with SLA / Volume arrived
    CASE
        WHEN ROUND(SUM(CAST(ONTIME_RETURN AS Numeric)) / SUM(CAST(arrived_volume AS Numeric)), 2) * 100 >= 95.0 THEN CAST(SUM(CASE WHEN parcel_type = 'Prepaid' AND ONTIME_RETURN = 1 THEN 1 ELSE 0 END) AS NUMERIC) * 50
        ELSE 0
    END AS Payable_vendor_return
FROM
    Same_day_arrival_vendor_return
WHERE
    shipment_type <> 'ECONOMY' AND sender_flag <> 1 AND signed_time IS NULL
GROUP BY
    1, 2, 3

UNION ALL

SELECT
    OS.parcel_type,
    OS.site,
    OS.delivery_date,
    CAST(SUM(CR) AS NUMERIC) AS "Collected_VOL",
    ROUND(CAST(SUM(CR) AS NUMERIC) / CAST(SUM(Delivery_Volume) AS NUMERIC), 4) AS percentage_achieved,
    CASE
        WHEN ROUND(CAST(SUM(CR) AS NUMERIC) / CAST(SUM(Delivery_Volume) AS NUMERIC), 2) * 100 >= 50.0 AND -- This sums up the number of parcels delivered * 70 when the KPI has been met for COD parcels
             OS.Parcel_Type = 'COD' THEN CAST(SUM(CR) AS NUMERIC) * 70
        WHEN ROUND(CAST(SUM(CR) AS NUMERIC) / CAST(SUM(Delivery_Volume) AS NUMERIC), 2) * 100 >= 85.0 AND -- This sums up the number of parcels delivered * 50 when the KPI has been met for Prepaid parcels
             OS.Parcel_Type = 'Prepaid' THEN CAST(SUM(CR) AS NUMERIC) * 50
        ELSE 0
    END AS "Payable_SDSC"
FROM
    Openrunsheet_and_SDSC OS
WHERE
    shipment_type = 'STANDARD'
GROUP BY
    1, 2, 3

UNION ALL

SELECT
    'Open Runsheet',
    OS.site,
    OS.delivery_date,
    Sum_SD AS "Collected_VOL",
    ROUND(CAST(SUM(OS.OR) AS NUMERIC) / CAST(SUM(Delivery_Volume) AS NUMERIC), 4) AS Percentage_achieved,
    CASE
        WHEN ROUND(CAST(SUM(OS.OR) AS NUMERIC) / CAST(SUM(Delivery_Volume) AS NUMERIC), 2) * 100 >= 98.0 THEN Sum_SD * 50
        ELSE 0
    END AS Payable
FROM
    Openrunsheet_and_SDSC OS
LEFT JOIN (
    -- Joins with a subquery to isolate the vol_prepaid parcels delivered for that day
    SELECT
        OS.site AS site,
        OS.delivery_date AS delivery_date,
        SUM(CR) AS Sum_SD
    FROM
        Openrunsheet_and_SDSC OS
    WHERE
        OS.parcel_type = 'Prepaid' AND shipment_type = 'STANDARD'
    GROUP BY
        1, 2
) AS CP ON OS.site = CP.site AND OS.delivery_date = CP.delivery_date
GROUP BY
    1, 2, 3, 4;