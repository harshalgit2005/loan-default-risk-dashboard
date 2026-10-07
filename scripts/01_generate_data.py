"""
Generate a SYNTHETIC Indian retail-lending dataset (customers + loans).

Why synthetic: real bank data is confidential. The relationships below are
built to behave like real credit risk (low credit score, high DTI, thin
employment history -> higher default), so the analysis is realistic,
but the numbers are NOT real market statistics. Say this in your README.

Swap in a real dataset (e.g. Kaggle "Loan Default Prediction", LendingClub)
later by loading it into the same two tables.
"""
import numpy as np
import pandas as pd
from pathlib import Path

rng = np.random.default_rng(42)
OUT = Path(__file__).resolve().parent.parent / "data"
OUT.mkdir(exist_ok=True)

N_CUST, N_LOAN = 20_000, 24_000

# ---------------- Geography ----------------
geo = pd.DataFrame(
    [
        # state, city, tier, weight, risk_shift
        ("Maharashtra", "Mumbai", 1, 9, 0.00), ("Maharashtra", "Pune", 1, 7, -0.05),
        ("Maharashtra", "Nagpur", 2, 3, 0.05), ("Karnataka", "Bengaluru", 1, 8, -0.10),
        ("Karnataka", "Mysuru", 2, 2, 0.00), ("Delhi", "New Delhi", 1, 8, 0.05),
        ("Tamil Nadu", "Chennai", 1, 6, -0.05), ("Tamil Nadu", "Coimbatore", 2, 3, 0.00),
        ("Telangana", "Hyderabad", 1, 6, -0.05), ("Gujarat", "Ahmedabad", 1, 5, -0.05),
        ("Gujarat", "Surat", 2, 3, 0.00), ("West Bengal", "Kolkata", 1, 5, 0.15),
        ("Uttar Pradesh", "Lucknow", 2, 4, 0.25), ("Uttar Pradesh", "Kanpur", 3, 3, 0.35),
        ("Bihar", "Patna", 2, 3, 0.40), ("Rajasthan", "Jaipur", 2, 4, 0.10),
        ("Madhya Pradesh", "Indore", 2, 3, 0.10), ("Punjab", "Ludhiana", 2, 2, 0.15),
        ("Odisha", "Bhubaneswar", 2, 2, 0.20), ("Kerala", "Kochi", 2, 3, -0.05),
    ],
    columns=["state", "city", "city_tier", "weight", "geo_risk"],
)
geo["p"] = geo["weight"] / geo["weight"].sum()

# ---------------- Customers ----------------
gi = rng.choice(len(geo), size=N_CUST, p=geo["p"])
cust = pd.DataFrame({"customer_id": np.arange(1, N_CUST + 1)})
cust["age"] = np.clip(rng.normal(36, 9, N_CUST), 21, 65).astype(int)
cust["state"] = geo["state"].values[gi]
cust["city"] = geo["city"].values[gi]
cust["city_tier"] = geo["city_tier"].values[gi]
cust["geo_risk"] = geo["geo_risk"].values[gi]

emp_types = ["Salaried - Govt", "Salaried - Private", "Self-Employed", "Gig/Contract"]
cust["employment_type"] = rng.choice(emp_types, N_CUST, p=[0.12, 0.50, 0.26, 0.12])

max_years = np.clip(cust["age"] - 21, 0, None)
cust["years_employed"] = np.round(rng.uniform(0, 1, N_CUST) ** 1.3 * max_years, 1)

inc_mu = cust["employment_type"].map(
    {"Salaried - Govt": 13.35, "Salaried - Private": 13.45, "Self-Employed": 13.40, "Gig/Contract": 12.85}
)
tier_adj = cust["city_tier"].map({1: 0.15, 2: 0.0, 3: -0.20})
exp_adj = np.log1p(cust["years_employed"]) * 0.12
cust["annual_income"] = (np.exp(rng.normal(inc_mu + tier_adj + exp_adj - 0.35, 0.55)) // 1000 * 1000).astype(int)
cust["annual_income"] = cust["annual_income"].clip(150_000, 6_000_000)

z_inc = (np.log(cust["annual_income"]) - np.log(cust["annual_income"]).mean()) / np.log(cust["annual_income"]).std()
cust["credit_score"] = np.clip(rng.normal(715 + 22 * z_inc, 62), 300, 900).astype(int)
cust["prior_delinquencies"] = rng.poisson(np.clip((720 - cust["credit_score"]) / 120, 0.05, 2.0))
cust["existing_monthly_emi"] = (
    cust["annual_income"] / 12 * rng.beta(1.6, 6, N_CUST) * (rng.random(N_CUST) < 0.65)
).round(-2).astype(int)

# ---------------- Loans ----------------
loan_types = ["Home Loan", "Auto Loan", "Personal Loan", "Education Loan", "Business Loan", "Gold Loan"]
loans = pd.DataFrame({"loan_id": np.arange(100001, 100001 + N_LOAN)})
loans["customer_id"] = rng.choice(cust["customer_id"], N_LOAN)
loans["loan_type"] = rng.choice(loan_types, N_LOAN, p=[0.20, 0.17, 0.30, 0.09, 0.14, 0.10])
loans = loans.merge(cust, on="customer_id", how="left")

mult = loans["loan_type"].map(
    {"Home Loan": 3.5, "Auto Loan": 0.9, "Personal Loan": 0.55, "Education Loan": 0.9, "Business Loan": 1.4, "Gold Loan": 0.25}
)
loans["loan_amount"] = (loans["annual_income"] * mult * rng.uniform(0.6, 1.3, N_LOAN) // 5000 * 5000).astype(int)
loans["loan_amount"] = loans["loan_amount"].clip(lower=25_000)
loans["tenure_months"] = loans["loan_type"].map(
    {"Home Loan": 240, "Auto Loan": 60, "Personal Loan": 36, "Education Loan": 84, "Business Loan": 60, "Gold Loan": 12}
)
base_rate = loans["loan_type"].map(
    {"Home Loan": 8.7, "Auto Loan": 9.5, "Personal Loan": 13.0, "Education Loan": 10.0, "Business Loan": 12.0, "Gold Loan": 9.0}
)
loans["interest_rate"] = (base_rate + (720 - loans["credit_score"]).clip(-60, 150) / 40 + rng.normal(0, 0.3, N_LOAN)).round(2)

r = loans["interest_rate"] / 1200
n = loans["tenure_months"]
loans["emi"] = (loans["loan_amount"] * r * (1 + r) ** n / ((1 + r) ** n - 1)).round(-1).astype(int)
loans["dti"] = ((loans["existing_monthly_emi"] + loans["emi"]) / (loans["annual_income"] / 12)).round(3)

start = pd.Timestamp("2021-01-01")
span = (pd.Timestamp("2026-09-15") - start).days
loans["application_date"] = pd.Series(start + pd.to_timedelta(rng.integers(0, span, N_LOAN), unit="D")).dt.date

# ---------------- Default process (hidden "true" risk) ----------------
dti_c = loans["dti"].clip(upper=1.2)
logit = (
    -3.35
    + 0.95 * (700 - loans["credit_score"]) / 100
    + 2.6 * (dti_c - 0.35)
    + 0.45 * loans["prior_delinquencies"].clip(upper=4)
    + loans["employment_type"].map({"Salaried - Govt": -0.45, "Salaried - Private": 0.0, "Self-Employed": 0.30, "Gig/Contract": 0.65})
    + np.where(loans["years_employed"] < 2, 0.45, np.where(loans["years_employed"] < 5, 0.15, -0.10))
    + loans["loan_type"].map({"Home Loan": -0.55, "Auto Loan": -0.10, "Personal Loan": 0.55, "Education Loan": 0.10, "Business Loan": 0.45, "Gold Loan": -0.25})
    + loans["geo_risk"]
    + np.where(loans["annual_income"] < 400_000, 0.35, np.where(loans["annual_income"] > 1_500_000, -0.30, 0.0))
)
p_default = 1 / (1 + np.exp(-logit))
default_flag = rng.random(N_LOAN) < p_default

# ---------------- Status ----------------
app_date = pd.to_datetime(loans["application_date"])
months_old = (pd.Timestamp("2026-09-30") - app_date).dt.days / 30.4
pending = months_old < 2.5                     # recent applications, no decision yet
status = np.where(pending, "Pending",
         np.where(default_flag & (months_old > 6), "Defaulted",
         np.where(months_old > loans["tenure_months"], "Closed", "Active")))
loans["loan_status"] = status
loans["default_flag"] = (loans["loan_status"] == "Defaulted").astype(int)

# ---------------- Save ----------------
cust_cols = ["customer_id", "age", "state", "city", "city_tier", "employment_type",
             "years_employed", "annual_income", "credit_score", "prior_delinquencies", "existing_monthly_emi"]
loan_cols = ["loan_id", "customer_id", "loan_type", "loan_amount", "tenure_months", "interest_rate",
             "emi", "dti", "application_date", "loan_status", "default_flag"]
cust[cust_cols].to_csv(OUT / "customers.csv", index=False)
loans[loan_cols].to_csv(OUT / "loans.csv", index=False)

known = loans[loans.loan_status != "Pending"]
print(f"customers: {len(cust):,} | loans: {len(loans):,}")
print(loans.loan_status.value_counts().to_string())
print(f"observed default rate (non-pending): {known.default_flag.mean():.2%}")
