# Customer Segmentation via RFM Analysis + K-Means Clustering

Segments ~4,300 real customers of a UK-based online retailer into actionable
groups using Recency, Frequency, and Monetary (RFM) analysis and K-Means
clustering — then quantifies how much revenue each segment drives. RFM is
built twice, once in pandas and once in raw SQL, so the same result is
verified two ways — plus a set of SQL-only analyst queries (monthly revenue,
top products, repeat-purchase rate, cohort retention, window functions).

## Dataset
[UCI "Online Retail"](https://archive.ics.uci.edu/dataset/352/online+retail) —
541,909 real e-commerce transactions (Dec 2010 – Dec 2011), 4,300+ unique
customers. Not synthetic/toy data — includes cancellations, missing customer
IDs, and outliers that had to be handled.

## Pipeline
1. **Clean** raw transactions — drop missing customer IDs, cancelled orders,
   non-positive quantities/prices, non-product line items (postage, carriage,
   manual adjustments, bank charges — see bug note below), and extreme
   outliers (395,555 clean rows, 4,318 customers).
2. **Engineer RFM features** per customer: Recency (days since last order),
   Frequency (distinct orders), Monetary (total spend).
3. **Handle skew** with log-transform + standard scaling (RFM is heavily
   right-skewed — a few customers drive most revenue).
4. **Select k** via the Elbow method and Silhouette score.
5. **Fit K-Means** (k=4) and profile/name each segment by its relative RFM
   ranking (Champions, Loyal/Steady, Low-Value/New, At Risk/Churned).
6. **Visualize** segment separability and revenue contribution per segment.

## Key result
| Segment | Customers | Avg Recency (days) | Avg Frequency | Avg Spend (£) | Revenue Share |
|---|---|---|---|---|---|
| **Champions** | 699 (16%) | 12.1 | 13.7 | £7,409 | **64.4%** |
| Loyal / Steady | 1,178 (27%) | 67.9 | 4.1 | £1,608 | 23.5% |
| At Risk / Churned | 1,612 (37%) | 183.7 | 1.3 | £334 | 6.7% |
| Low-Value / New | 829 (19%) | 18.4 | 2.1 | £526 | 5.4% |

**Headline insight:** the top ~16% of customers ("Champions") generate nearly
**two-thirds of total revenue** — a clear Pareto pattern that justifies
prioritizing retention spend on that segment, while the 37% "At Risk" group
is a prime target for a win-back campaign.

## A second bug, found by checking the data itself
The dataset mixes real merchandise with administrative line items —
`POST`/`DOT` (postage), `M` (manual entries), `BANK CHARGES`, `C2` (carriage)
— that carry *positive* quantity and price, so a sign-based filter alone lets
them straight through. Checked directly against the raw file: **1,332 such
rows were slipping past the original cleaning**, worth **£68,722** wrongly
attributed to **495 customers** (~11% of the customer base) as product
revenue. Now excluded explicitly by `StockCode`. The headline Pareto finding
barely moved (64.8% → 64.4%) — which is itself a useful thing to be able to
say: the bug was real and worth fixing, but the business conclusion was
robust to it.

## SQL analysis (`sql_analysis.ipynb`)
Rebuilds RFM entirely in SQL and validates it matches the pandas version
exactly — the first draft actually caught a real off-by-one bug from a
date-truncation gotcha, walked through in the notebook. Then runs four
analyst-style queries that go beyond RFM: monthly revenue trend, top-10
products, repeat-purchase rate, a monthly cohort-retention heatmap (CTE +
join), and a `RANK() OVER (PARTITION BY ...)` window-function query pulling
the top 3 spenders within each customer segment.

**Every query has a MySQL rewrite right next to it.** The notebook *runs* on
SQLite (built into Python, zero setup for anyone opening it), but each SQL
cell is followed by a markdown cell with the real MySQL 8.0+ equivalent —
including the actual dialect differences, not just a function-name mapping:
`julianday()`/`strftime()` → `DATEDIFF()`/`DATE_FORMAT()`, and a note on
where MySQL *requires* a derived-table alias that SQLite lets you skip.

## Files
- `segmentation.ipynb` — clustering pipeline as a notebook, with narrative markdown cells and inline plots
- `sql_analysis.ipynb` — RFM rebuilt in SQL + validation + bonus analyst queries
- `data/Online Retail.xlsx` — raw dataset (gitignored, re-downloadable from UCI)
- `outputs/rfm_table.csv` — per-customer RFM values + assigned segment
- `outputs/segment_profile.csv` — segment-level summary stats
- `outputs/k_selection.png` — Elbow + Silhouette plots used to pick k
- `outputs/segment_scatter.png` — segment separability across RFM dimensions
- `outputs/revenue_by_segment.png` — revenue contribution per segment
- `outputs/cohort_retention.png` — monthly cohort retention heatmap (SQL)
- `outputs/retail.db` — SQLite database built by `sql_analysis.ipynb` (gitignored, regenerated on run, 36MB)

## Setup
```bash
pip install -r requirements.txt jupyter
jupyter notebook segmentation.ipynb   # run this first — sql_analysis.ipynb's
jupyter notebook sql_analysis.ipynb   # window-function query reads its output
```

## Suggested resume bullets
- Segmented 4,300+ e-commerce customers into 4 behavioral groups using RFM
  feature engineering and K-Means clustering (silhouette score 0.34),
  identifying that the top ~16% of customers drove 64% of total revenue.
- Audited the raw dataset for data-quality issues beyond the obvious ones,
  catching £68K of postage/admin charges miscounted as product revenue
  across 495 customers, and re-validated that the business conclusion held
  after the fix.
- Built an end-to-end unsupervised learning pipeline (Pandas, scikit-learn)
  on 540K+ real transaction records — data cleaning, log-transform scaling,
  optimal-k selection (Elbow + Silhouette), and segment profiling — to
  surface an actionable customer retention strategy.
- Rebuilt the feature-engineering layer in SQL (CTEs, window functions,
  date arithmetic) and validated it against the pandas implementation;
  wrote cohort-retention and repeat-purchase-rate queries to extend the
  analysis beyond the clustering model.
