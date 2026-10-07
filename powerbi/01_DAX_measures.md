# DAX Measures

Load three tables from `/output`: `fact_loans.csv`, `review_queue.csv`, `segment_default_rates.csv` (optional).
Create a `_Measures` table (Home → Enter Data → empty table) and keep every measure there.

## Core risk measures

```dax
Loans Evaluated =
CALCULATE ( COUNTROWS ( fact_loans ), fact_loans[has_outcome] = 1 )

Defaults =
CALCULATE ( SUM ( fact_loans[default_flag] ), fact_loans[has_outcome] = 1 )

Default Rate = DIVIDE ( [Defaults], [Loans Evaluated] )

Portfolio Default Rate =
CALCULATE ( [Default Rate], ALL ( fact_loans ) )

Risk Lift = DIVIDE ( [Default Rate], [Portfolio Default Rate] )

Defaulted Amount =
CALCULATE ( SUM ( fact_loans[loan_amount] ), fact_loans[has_outcome] = 1, fact_loans[default_flag] = 1 )

Total Disbursed Amount =
CALCULATE ( SUM ( fact_loans[loan_amount] ), fact_loans[has_outcome] = 1 )

Loss Exposure % = DIVIDE ( [Defaulted Amount], [Total Disbursed Amount] )
```

## Guard against tiny segments (use this one in charts)

```dax
Default Rate (min 100 loans) =
IF ( [Loans Evaluated] < 100, BLANK (), [Default Rate] )
```

## Conditional-formatting helper (Format → Background colour → Field value)

```dax
Risk Colour =
SWITCH (
    TRUE (),
    [Risk Lift] >= 1.5, "#C0392B",   -- high
    [Risk Lift] >= 1.0, "#E6A23C",   -- above average
    "#2E8B57"                        -- below average
)
```

## Review-queue measures (from `review_queue`)

```dax
Pending Applications = COUNTROWS ( review_queue )

Manual Review Count =
CALCULATE ( COUNTROWS ( review_queue ), review_queue[recommended_route] = "Manual Review" )

Manual Review % = DIVIDE ( [Manual Review Count], [Pending Applications] )

Amount Under Manual Review =
CALCULATE ( SUM ( review_queue[loan_amount] ), review_queue[recommended_route] = "Manual Review" )

Avg Segment PD (Manual Review) =
CALCULATE ( AVERAGE ( review_queue[segment_pd] ), review_queue[recommended_route] = "Manual Review" )
```

## Calculated column for the map (disambiguates Indian states)

```dax
Country = "India"
```
Set `state` → Data category = *State or Province*, `Country` → *Country/Region*.

## Optional: Date table

```dax
Date = CALENDAR ( DATE ( 2021, 1, 1 ), DATE ( 2026, 12, 31 ) )
```
Relate `Date[Date]` → `fact_loans[application_date]` (convert the column to Date type in Power Query).
