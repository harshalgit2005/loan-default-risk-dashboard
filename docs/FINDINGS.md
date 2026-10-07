# Findings (from the synthetic dataset)

> These numbers come from generated data, so they illustrate the method. They are not real market statistics.
> If you swap in a real dataset, re-run the pipeline and rewrite this file from your own results.

**Portfolio baseline:** 21,994 loans with a known outcome, 9.2% default rate (loans need 6+ months of seasoning to count).

## Which segment has the highest default probability?

| Cut | Highest-risk segment | Default rate | vs. portfolio |
|---|---|---|---|
| Income bracket | Under 3L per year | 18.0% | 1.95x |
| Loan type | Business Loan | 13.7% | 1.48x |
| Employment type | Gig / Contract | 17.9% | 1.94x |
| Employment history | Under 2 years | 13.3% | 1.43x |
| Geography | Punjab, Bihar, Uttar Pradesh (11-12%) | ~12% | ~1.3x |
| Credit band (extra) | Under 600 | 34.2% | 3.7x |
| DTI band (extra) | 60%+ | 16.9% | 1.8x |

**Worst combined segment** (min 100 loans): income under 3L + Business Loan + Gig/Contract workers, 34.6% default rate, about 3.7x the portfolio.
Lowest-risk: Government salaried (5.1%), income 18L+ (2.5%), Karnataka (7.9%).

## Which applications should the credit team review?

Of 727 pending applications, the rules route **90 (12.4%) to manual review**, covering about Rs 3.9 Cr of requested amount,
and **180 (24.8%) to fast-track**. Manual-review cases average a segment PD of ~16% and a credit score around 656,
versus ~5% PD and a score of ~740 for fast-track.
The queue is sorted by `priority_score` = segment PD x loan amount x (1 + 0.25 x red flags), so large, risky tickets come first.

## Recommendations (written the way a credit head would read them)
1. Add a second approver for Business Loans to Gig/Contract applicants under 6L income.
2. Tighten the DTI cap around 55%, because default rates climb sharply past that point.
3. Review pricing on sub-600 credit scores, where one in three loans defaults.
4. Watch the Tier-3 city and the UP / Bihar / Punjab books (roughly 1.2-1.3x the portfolio rate).

## Limitations (say these in interviews)
- Synthetic data: relationships were designed, not observed.
- Segment PD is a historical default rate, not a trained model. A logistic regression or gradient boosting model is the natural next step.
- Active loans can still default later, so recent vintages are understated even after the seasoning rule.
- No rejected-application data, so approval bias is not measured.
- Thresholds (1.8x lift, DTI 0.55, score 620) are judgment calls and should be tuned with the credit team.
