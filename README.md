# Customer Segmentation & Revenue Concentration Analysis

Segments a real UK online retailer's customers into four actionable groups
using RFM (Recency, Frequency, Monetary) features and K-Means clustering,
then quantifies exactly how concentrated revenue is — built and verified two
ways, in pandas and in SQL.

## Business problem

A retailer can't spend retention budget evenly across every customer. This
project answers: **which customers actually drive revenue, and what should
be done for each group?** — using only behavioral data (what each customer
bought, when, how often), no demographics required.

## Dataset

[UCI "Online Retail"](https://archive.ics.uci.edu/dataset/352/online+retail)
— a real-world transactional dataset: 541,909 e-commerce transactions from a
UK-based online retailer, December 2010 to December 2011, 4,300+ unique
customers. Includes cancellations, missing customer IDs, and messy
StockCodes that had to be handled (see below) — not a pre-cleaned CSV.

## Tools

Python (pandas, NumPy, scikit-learn, Matplotlib, Seaborn) for the modeling
pipeline; SQL (SQLite, with MySQL 8.0+ equivalents throughout) for an
independent, validated rebuild of the same feature engineering plus
additional business queries; Jupyter for both notebooks.

## Pipeline

1. **Clean** raw transactions — missing customer IDs, cancelled orders,
   non-positive quantities/prices, non-merchandise line items (see the bug
   below), and outliers.
2. **Engineer RFM features** per customer, with a quick KPI snapshot
   computed directly from the data.
3. **Handle skew** — log-transform (with before/after skewness evidence),
   then standardize.
4. **Select k** — compared on five criteria (silhouette, inertia, minimum
   cluster share, revenue separation, business interpretability), not
   silhouette alone.
5. **Fit K-Means, profile & name segments**, with an explicit RFM-evidence
   table behind each name.
6. **Visualize** segment separability, revenue by segment, and a revenue
   concentration (Pareto-style) curve.
7. **Stress-test** the conclusion against a stricter outlier threshold.

## A data-quality bug, found and fixed

The raw dataset mixes real merchandise with administrative line items —
`POST`/`DOT` (postage), `M` (manual entries), `BANK CHARGES`, `C2` (carriage)
— that carry *positive* quantity and price, so a sign-based filter alone lets
them straight through.

| | Before fix | After fix |
|---|---|---|
| Rows counted as revenue | +1,332 non-merchandise rows | excluded |
| Revenue wrongly attributed | £68,722 | £0 |
| Customers affected | 495 (~11% of base) | 0 |
| Top-segment revenue share | 64.8% | 64.4% |

Found by checking every non-standard `StockCode` directly against the raw
file, not by code review. The headline finding moved by only 0.4 points —
evidence the conclusion is a data-quality-robust one, not an artifact of the
bug. Presented here as a robustness test, because that's the actual
analytical value of having found it.

## Key findings

| Metric | Value |
|---|---|
| Customers analyzed | 4,318 |
| Clean transaction rows | 395,555 (from 541,909 raw) |
| Repeat-customer rate | 65.1% (cross-checked in both pandas and SQL) |
| Average order value | £440.36 |
| Chosen model | k=4, silhouette 0.339 |
| Top segment ("Champions") revenue share | 64.4% of total revenue, from 16% of customers |
| Top 10% of customers by spend | 59.0% of revenue |
| Top 20% of customers by spend | 72.9% of revenue |

| Segment | Customers | Avg Recency (days) | Avg Frequency | Avg Spend (£) | Revenue Share |
|---|---|---|---|---|---|
| **Champions** | 699 (16%) | 12.1 | 13.7 | £7,409 | **64.4%** |
| Loyal / Steady | 1,178 (27%) | 67.9 | 4.1 | £1,608 | 23.5% |
| At Risk | 1,612 (37%) | 183.7 | 1.3 | £334 | 6.7% |
| Low-Value / New | 829 (19%) | 18.4 | 2.1 | £526 | 5.4% |

**Why k=4, explicitly:** k=2 scores highest on silhouette (0.434) but
collapses everyone into "big spenders vs. the rest." k=4 was chosen after
comparing k=2–6 on cluster quality, minimum cluster share, revenue
separation, and interpretability — not by a hard-coded rule. Full comparison
table: [`outputs/k_comparison.csv`](outputs/k_comparison.csv), reasoning in
`segmentation.ipynb` §4.

**On the "At Risk" label:** it means high Recency relative to this dataset's
own snapshot date — it is *not* a churn probability. No churn threshold or
supervised model was fit. See `segmentation.ipynb` §5 for the full scope
note.

## Business recommendations

- **Champions (16% of customers, 64% of revenue):** protect this segment —
  loyalty treatment, priority service, retention spend concentrated here.
- **At Risk (37% of customers, 7% of revenue):** a win-back / reactivation
  campaign before the relationship lapses entirely — large in customer count,
  small in current revenue, which is exactly the group a campaign can move.
- **Low-Value / New (19% of customers):** nurture toward a second purchase;
  distinct from At Risk because these customers are often *recent*, just
  unproven — a different message than a win-back campaign.
- **Loyal / Steady (27% of customers, 24% of revenue):** cross-sell and
  engagement targets — the group closest to becoming Champions.

## SQL analysis (`sql_analysis.ipynb`)

Rebuilds RFM entirely in SQL and validates it matches the pandas version
exactly — the first draft caught a real off-by-one bug from a
date-truncation gotcha (walked through in the notebook). Adds business
queries beyond RFM: monthly revenue trend, top-10 products, repeat-purchase
rate, a **cohort-retention heatmap expressed as percentages** (not just raw
counts), a segment-level KPI query that reproduces the revenue-share numbers
above directly in SQL, and a `RANK() OVER (PARTITION BY ...)` window-function
query pulling the top 3 spenders per segment. Every query also has a real
MySQL 8.0+ rewrite next to it — see the notebook for the dialect specifics
(`DATEDIFF`/`DATE_FORMAT` vs. SQLite's `julianday`/`strftime`, and a real
derived-table-alias gotcha).

The same MySQL queries are also collected as a standalone
[`queries.sql`](queries.sql) — schema + all 8 queries, no notebook required,
for quick reference or a code review. Includes one addition not in the
notebook: query 6 computes cohort-retention percentages entirely in SQL via
`FIRST_VALUE() OVER (...)`, where the notebook does that specific step in
pandas.

## Limitations

- **UK-only, one-year snapshot** — conclusions aren't validated against a
  different market or time period.
- **No demographic or acquisition-channel data** — segmentation is behavior-only.
- **"At Risk" is not a churn model** — see the scope note above.
- **Revenue is not profit** — no cost data is available, so nothing here
  claims profitability.
- **RFM thresholds drift over time** — this is a point-in-time model; a
  production version would need periodic re-fitting.
- **K-Means assumes roughly spherical, similarly-sized clusters** —
  reasonable here (checked via the k-comparison table) but not guaranteed
  for a different dataset.

## Repository structure

```
Data Analysis Project/
├── README.md
├── requirements.txt
├── .gitignore
├── segmentation.ipynb       # clustering pipeline
├── sql_analysis.ipynb       # SQL rebuild + validation + business queries
├── queries.sql              # same SQL, as a standalone MySQL file
├── data/
│   └── Online Retail.xlsx   # raw dataset (gitignored, re-downloadable from UCI)
└── outputs/                 # generated by the notebooks, not hand-written
    ├── rfm_table.csv
    ├── segment_profile.csv
    ├── k_comparison.csv
    ├── model_summary.json
    ├── k_selection.png
    ├── segment_scatter.png
    ├── revenue_by_segment.png
    ├── pareto_revenue.png
    ├── cohort_retention.png         # retention %, primary view
    ├── cohort_retention_counts.png  # raw counts, audit view
    └── retail.db                    # SQLite DB (gitignored, regenerated on run)
```

## Reproduction

```bash
pip install -r requirements.txt
jupyter notebook segmentation.ipynb   # run this first — it writes outputs/rfm_table.csv
jupyter notebook sql_analysis.ipynb   # then this — §4e/§4f read that file
```
