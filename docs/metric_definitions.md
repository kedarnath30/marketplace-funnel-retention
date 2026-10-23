# Metric definitions

All metrics are computed in DuckDB SQL (`sql/`) over orders **purchased 2017-01-01 to 2018-08-31**.

**Grain and identity**
- **User / buyer** = `customer_unique_id`. Olist's `customer_id` is per order; `customer_unique_id` is the person.
- **Seller** = `seller_id` on the order items.
- **Purchase** = an order whose status is not `canceled` or `unavailable` and has at least one item.
- **GMV** = item price + freight, summed over a purchase's items (BRL). Seller revenue uses item price only.

## North star

| Metric | Definition | Why |
|---|---|---|
| **Monthly Active Buyers (MAB)** | Distinct buyers with >= 1 purchase in the calendar month | Counts people who got value from a transaction. Harder to inflate than GMV with one big basket. |

## Metric tree

```
Monthly GMV
├── Monthly Active Buyers (north star)
│   ├── New buyers            first purchase this month
│   └── Returning buyers      first purchase in an earlier month
│        └── driven by buyer retention: M1 / M3 / M6 / M12 cohort retention
├── Orders per active buyer   orders / MAB
└── AOV                       GMV / orders
Health and trust guardrails (supply and fulfilment)
├── On-time delivery rate     delivered on or before the estimated date / delivered
├── Avg review score          1-5, latest review per order
├── Funnel completion         on time AND review >= 4 / orders placed
├── Seller retention          % of a seller cohort making >= 1 sale in month k
└── Seller concentration      share of monthly seller revenue from the top 10% of sellers
```

## Definitions

| Metric | Definition | SQL |
|---|---|---|
| New buyers | MAB whose first purchase month is this month | `01_north_star_monthly.sql` |
| Returning buyers | MAB whose first purchase month is earlier | `01` |
| Repeat buyer rate | Buyers with >= 2 purchases / all buyers in the window | `02_headline_metrics.sql` |
| Repeat rate (distinct days) | Buyers who purchased on >= 2 different calendar days / all buyers. Leaves out same-day split baskets. | `src/analysis.py` |
| AOV | GMV / purchases | `01`, `02` |
| Late delivery | Delivered date (day) > estimated delivery date (day) | `00_views.sql` |
| Days vs estimate | delivered date - estimated date, in days (negative = early) | `00_views.sql` |
| Funnel stages | placed -> payment approved -> handed to carrier -> delivered -> delivered on time -> on time with review >= 4 | `03`, `04` |
| Buyer cohort retention (month k) | % of buyers first purchasing in month c who purchase in month c+k | `05_cohort_retention.sql` |
| Cumulative GMV per buyer (LTV-style) | Cohort's cumulative GMV through month k / cohort size. Only fully observed months are shown. | `06_cohort_ltv.sql` |
| DAU / WAU / MAU | Distinct buyers purchasing on the day / in the trailing 7 days / in the trailing 28 days | `07_active_users.sql` |
| Stickiness | DAU/MAU and WAU/MAU, from the trailing windows above | `07` |
| Seller cohort retention (month k) | % of sellers first selling in month c who make >= 1 sale in month c+k | `12_seller_retention.sql` |
| Seller 91-180 day retention | Seller makes >= 1 sale 91-180 days after their first sale. Sellers with first sale before Mar 2018 and >= 5 orders in their first 90 days. | `13_seller_health_vs_churn.sql` |
| Buyers per seller | MAB / monthly active sellers | `14_marketplace_liquidity.sql` |

## Caveats
- Olist has no sessions, views or carts. The "funnel" starts at checkout and runs through fulfilment, satisfaction and repurchase. It does not cover browse-to-cart.
- Activity means *purchasing*, so DAU/MAU is a transaction-stickiness measure. It is not app engagement.
- The last cohorts have short windows. Cells that are not fully observable are blanked or excluded.
