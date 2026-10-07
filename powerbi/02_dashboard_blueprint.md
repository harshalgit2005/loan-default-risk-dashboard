# Dashboard Blueprint (build in this order)

Canvas: 16:9. Theme: import `powerbi/theme.json` (View → Themes → Browse). Font: Segoe UI.
Rule for the whole report: **every visual answers a question; the title says the question.**

## Power Query steps (Transform data)
1. Import the three CSVs.
2. `fact_loans`: set types, `application_date` → Date, `loan_amount` → Whole number, `dti` → Decimal.
3. Leave band columns as text. They start with "1.", "2." so they already sort correctly.
4. Add `Country = "India"` (or the DAX column above).
5. Do not filter out `has_outcome = 0` rows. The measures handle it, and the pending rows are used elsewhere.

## Page 1: Portfolio Overview — "How risky is our book?"
- KPI cards: **Loans Evaluated**, **Default Rate**, **Defaulted Amount**, **Loss Exposure %**, **Pending Applications**
- Line chart: Default Rate by `application_year` (shows vintage stability)
- Column chart: Default Rate by `credit_band`
- Slicers: `loan_type`, `state`, `application_year`

## Page 2: Segment Deep Dive — "Which segments default the most?"
The four cuts you were asked for, one visual each, all using `Default Rate (min 100 loans)`:
| Visual | Axis | Notes |
|---|---|---|
| Clustered bar | `income_bracket` | Add a constant line at `Portfolio Default Rate` |
| Clustered bar | `loan_type` | Sort descending by rate |
| Clustered column | `employment_history_band` + a second chart by `employment_type` | Shows tenure vs job type |
| Filled map (fallback: bar by `state`) | `state` | Colour saturation = Default Rate; tooltip = loans, lift |

Add a **Matrix heatmap**: rows = `income_bracket`, columns = `loan_type`, values = Default Rate,
with conditional-format background (white → red). This is the visual that answers "highest-risk segment" in one glance.
Add a **Decomposition Tree**: Analyze = `Default Rate`; Explain by = `income_bracket`, `employment_type`, `loan_type`, `credit_band`, `state`.

## Page 3: Manual Review Queue — "What should the credit team look at today?"
- Cards: **Manual Review Count**, **Manual Review %**, **Amount Under Manual Review**
- Donut/bar: applications by `recommended_route`
- Table (the main object), filtered to `recommended_route = "Manual Review"`, sorted by `priority_score` desc:
  `loan_id, loan_type, loan_amount, income_bracket, employment_type, credit_score, dti, segment_pd, flag_count`
  - Conditional formatting: data bars on `priority_score`, red font on `credit_score < 620`, red on `dti >= 0.55`
- Slicers: `loan_type`, `state`, `flag_count`

## Page 4 (optional): Methodology
Short text boxes: data source (synthetic), seasoning rule (6 months), segment PD smoothing, routing rules, limitations.
Recruiters like seeing that you know where the analysis stops.

## Interactions to switch on
- Page 2 visuals → cross-filter each other (default).
- Add a **drill-through** page from Page 2 (field: `loan_type`) to a detail table of loans.
- Add **bookmarks** + buttons for "Highest risk view" if you want polish. Not required.

## Screenshots for the repo
Export each page as PNG (File → Export → PDF, or screenshot at 100% zoom) into `/docs/screenshots/`.
