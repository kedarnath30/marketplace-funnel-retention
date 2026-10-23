"""Build figures and computed findings from the DuckDB outputs.

Run order:  python src/download_data.py  ->  python src/run_sql.py  ->  python src/analysis.py
Writes figures/*.png and outputs/findings.json (every number quoted in the README comes from here
or from outputs/*.csv).
"""
from pathlib import Path
import json
import math

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import numpy as np
import pandas as pd
import seaborn as sns

from run_sql import connect

ROOT = Path(__file__).resolve().parents[1]
OUT, FIG = ROOT / "outputs", ROOT / "figures"
FIG.mkdir(exist_ok=True)
sns.set_theme(style="whitegrid", context="talk", font_scale=0.8)
BLUE, RED, GREY = "#1f5fbf", "#d1495b", "#8a8f98"


def read(name: str) -> pd.DataFrame:
    return pd.read_csv(OUT / f"{name}.csv")


def save(fig, name):
    fig.tight_layout()
    fig.savefig(FIG / name, dpi=130, bbox_inches="tight")
    plt.close(fig)


def two_prop_z(x1, n1, x2, n2):
    p1, p2 = x1 / n1, x2 / n2
    p = (x1 + x2) / (n1 + n2)
    se = math.sqrt(p * (1 - p) * (1 / n1 + 1 / n2))
    z = (p1 - p2) / se
    pval = math.erfc(abs(z) / math.sqrt(2))
    return z, pval


findings = {}

# ---------------- headline ----------------
h = read("02_headline_metrics").iloc[0].to_dict()
findings["headline"] = h

con = connect()
# repeat rate excluding same-day "basket split" repeats (a 2nd order placed on the same calendar day)
rr = con.execute("""
  WITH s AS (
    SELECT user_id, COUNT(*) n,
           COUNT(DISTINCT CAST(purchased_at AS DATE)) n_days
    FROM purchases GROUP BY 1)
  SELECT COUNT(*) buyers,
         SUM((n>=2)::INT) repeat_any,
         SUM((n_days>=2)::INT) repeat_distinct_day
  FROM s""").df().iloc[0]
findings["repeat"] = {
    "buyers": int(rr.buyers),
    "repeat_buyers_any": int(rr.repeat_any),
    "repeat_pct_any": round(rr.repeat_any / rr.buyers * 100, 2),
    "repeat_buyers_distinct_day": int(rr.repeat_distinct_day),
    "repeat_pct_distinct_day": round(rr.repeat_distinct_day / rr.buyers * 100, 2),
}

# ---------------- 1. north star trend ----------------
ns = read("01_north_star_monthly")
ns["month"] = pd.to_datetime(ns["month"])
fig, ax = plt.subplots(figsize=(11, 5))
ax.bar(ns["month"], ns["new_buyers"], width=20, color=BLUE, label="New buyers")
ax.bar(ns["month"], ns["returning_buyers"], width=20, bottom=ns["new_buyers"], color=RED, label="Returning buyers")
ax.set_title("North star: Monthly Active Buyers (new vs returning)")
ax.set_ylabel("Buyers")
ax.legend(loc="upper left")
ax2 = ax.twinx()
ax2.plot(ns["month"], ns["returning_buyers"] / ns["active_buyers"] * 100, color="black", marker="o", lw=1.5, label="% returning")
ax2.set_ylabel("% of MAB returning")
ax2.yaxis.set_major_formatter(mtick.PercentFormatter(decimals=1))
ax2.grid(False)
ax2.set_ylim(0, 4)
ax2.legend(loc="upper center")
save(fig, "01_north_star_mab.png")
findings["north_star"] = {
    "mab_jan2017": int(ns.iloc[0].active_buyers),
    "mab_aug2018": int(ns.iloc[-1].active_buyers),
    "mab_peak": int(ns.active_buyers.max()),
    "mab_peak_month": ns.loc[ns.active_buyers.idxmax(), "month"].strftime("%Y-%m"),
    "returning_share_aug2018_pct": round(ns.iloc[-1].returning_buyers / ns.iloc[-1].active_buyers * 100, 2),
    "returning_share_2018_avg_pct": round(ns[ns.month >= "2018-01-01"].returning_buyers.sum() / ns[ns.month >= "2018-01-01"].active_buyers.sum() * 100, 2),
}

# ---------------- 2. funnel ----------------
fu = read("03_funnel_overall")
fig, ax = plt.subplots(figsize=(11, 5))
ax.barh(fu["stage"][::-1], fu["n"][::-1], color=[RED] * 2 + [BLUE] * 4)
for i, (n, pct, drop) in enumerate(zip(fu["n"][::-1], fu["pct_of_placed"][::-1], fu["step_dropoff_pct"][::-1])):
    lab = f"{n:,}  ({pct:.1f}% of placed" + (f", -{drop:.1f}% step)" if not np.isnan(drop) else ")")
    ax.text(n * 1.01, i, lab, va="center", fontsize=10)
ax.set_xlim(0, fu["n"].max() * 1.45)
ax.set_title("Order-to-satisfaction funnel (orders placed Jan 2017 - Aug 2018)")
ax.set_xlabel("Orders")
save(fig, "02_funnel.png")

seg = read("04_funnel_segmented")
reg = seg[seg.dimension == "region"].set_index("segment")
fig, axes = plt.subplots(1, 2, figsize=(13, 4.8))
r = reg.sort_values("late_pct_of_delivered")
axes[0].barh(r.index, r["late_pct_of_delivered"], color=[RED if x == "Northeast" else BLUE for x in r.index])
axes[0].set_title("Late deliveries (% of delivered)")
axes[0].xaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
r2 = reg.sort_values("on_time_positive_pct")
axes[1].barh(r2.index, r2["on_time_positive_pct"], color=[RED if x == "Northeast" else BLUE for x in r2.index])
axes[1].set_title("Funnel completion: on time + review >= 4")
axes[1].xaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
axes[1].set_xlim(60, 80)
for a, col in zip(axes, ["late_pct_of_delivered", "on_time_positive_pct"]):
    src = r if col == "late_pct_of_delivered" else r2
    for i, v in enumerate(src[col]):
        a.text(v, i, f" {v:.1f}%", va="center", fontsize=10)
fig.suptitle("Funnel by customer region", y=1.02)
save(fig, "03_funnel_by_region.png")
findings["funnel"] = {
    "placed": int(fu.n.iloc[0]),
    "delivered_pct": float(fu.pct_of_placed.iloc[3]),
    "on_time_pct": float(fu.pct_of_placed.iloc[4]),
    "on_time_positive_pct": float(fu.pct_of_placed.iloc[5]),
    "biggest_step_dropoff": fu.loc[fu.step_dropoff_pct.idxmax(), "stage"],
    "biggest_step_dropoff_pct": float(fu.step_dropoff_pct.max()),
    "northeast_late_pct": float(reg.loc["Northeast", "late_pct_of_delivered"]),
    "southeast_late_pct": float(reg.loc["Southeast", "late_pct_of_delivered"]),
    "northeast_on_time_positive_pct": float(reg.loc["Northeast", "on_time_positive_pct"]),
    "southeast_on_time_positive_pct": float(reg.loc["Southeast", "on_time_positive_pct"]),
    "northeast_avg_delivery_days": float(reg.loc["Northeast", "avg_delivery_days"]),
    "southeast_avg_delivery_days": float(reg.loc["Southeast", "avg_delivery_days"]),
}
cat = seg[seg.dimension == "category"].sort_values("repurchase_pct", ascending=False)
findings["category_repurchase_top"] = cat[["segment", "repurchase_pct"]].head(3).values.tolist()
findings["category_repurchase_bottom"] = cat[["segment", "repurchase_pct"]].tail(3).values.tolist()

# ---------------- 3. cohort retention heatmap ----------------
co = read("05_cohort_retention")
co["cohort_month"] = pd.to_datetime(co["cohort_month"]).dt.strftime("%Y-%m")
piv = co[co.month_k.between(1, 12)].pivot(index="cohort_month", columns="month_k", values="retention_pct")
sizes = co.drop_duplicates("cohort_month").set_index("cohort_month")["cohort_size"]
# blank out cells that are not fully observable (cohort + k beyond 2018-08)
for cm in piv.index:
    maxk = (2018 - int(cm[:4])) * 12 + (8 - int(cm[5:]))
    piv.loc[cm, [k for k in piv.columns if k > maxk]] = np.nan
    piv.loc[cm, [k for k in piv.columns if k <= maxk]] = piv.loc[cm, [k for k in piv.columns if k <= maxk]].fillna(0)
fig, ax = plt.subplots(figsize=(13, 8))
sns.heatmap(piv, annot=True, fmt=".2f", cmap="Blues", cbar_kws={"label": "% of cohort purchasing in month k"}, ax=ax, annot_kws={"size": 8})
ax.set_yticklabels([f"{c}  (n={sizes[c]:,})" for c in piv.index], rotation=0)
ax.set_title("Monthly cohort retention (% of first-time buyers who purchase again in month k)")
ax.set_xlabel("Months since first purchase")
ax.set_ylabel("Acquisition cohort")
save(fig, "04_cohort_retention_heatmap.png")
# size-weighted average month-1, month-3, month-6 retention
w = {}
for k in (1, 3, 6, 12):
    col = piv[k].dropna()
    w[f"m{k}_retention_pct_weighted"] = round(float((col * sizes[col.index]).sum() / sizes[col.index].sum()), 3)
findings["cohorts"] = w

# ---------------- 4. cumulative GMV per buyer ----------------
ltv = read("06_cohort_ltv")
ltv["cohort_month"] = pd.to_datetime(ltv["cohort_month"])
fig, ax = plt.subplots(figsize=(11, 5.5))
sel = ltv[ltv.cohort_month.dt.month.isin([1, 4, 7, 10])]
pal = sns.color_palette("viridis", sel.cohort_month.nunique())
for (cm, g), c in zip(sel.groupby("cohort_month"), pal):
    ax.plot(g.month_k, g.cum_gmv_per_buyer, marker="o", ms=3, color=c, label=cm.strftime("%Y-%m"))
ax.set_title("LTV-style curve: cumulative GMV per acquired buyer (BRL)")
ax.set_xlabel("Months since first purchase")
ax.set_ylabel("Cumulative GMV / buyer (R$)")
ax.legend(title="Cohort", ncol=2, fontsize=9)
save(fig, "05_cohort_cumulative_gmv.png")
m0 = ltv[ltv.month_k == 0].set_index("cohort_month").cum_gmv_per_buyer
m12 = ltv[ltv.month_k == 12].set_index("cohort_month").cum_gmv_per_buyer
both = m12.index
uplift = ((m12 / m0[both]) - 1) * 100
findings["ltv"] = {
    "cohorts_with_12m": len(both),
    "avg_m0_gmv_per_buyer": round(float(m0[both].mean()), 2),
    "avg_m12_gmv_per_buyer": round(float(m12.mean()), 2),
    "avg_uplift_m0_to_m12_pct": round(float(uplift.mean()), 2),
}

# ---------------- 5. actives & stickiness ----------------
au = read("07_active_users")
au["day"] = pd.to_datetime(au["day"])
au["dau_mau"] = au.dau / au.mau_28d * 100
au["wau_mau"] = au.wau / au.mau_28d * 100
weekly = au[au.day.dt.day_of_week == 6]  # Sundays -> trailing-7-day WAU
fig, axes = plt.subplots(2, 1, figsize=(11, 7.5), sharex=True)
axes[0].plot(weekly.day, weekly.wau, color=BLUE, label="WAU (trailing 7d)")
axes[0].plot(weekly.day, weekly.mau_28d, color=GREY, label="MAU (trailing 28d)")
axes[0].set_title("Weekly / monthly active buyers")
axes[0].legend()
axes[1].plot(au.day, au.dau_mau.rolling(7).mean(), color=RED, label="DAU/MAU (7d avg)")
axes[1].plot(weekly.day, weekly.wau_mau, color=BLUE, label="WAU/MAU")
axes[1].yaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
axes[1].set_title("Stickiness")
axes[1].legend()
save(fig, "06_actives_stickiness.png")
a18 = au[au.day >= "2018-01-01"]
findings["actives"] = {
    "avg_dau_2018": round(float(a18.dau.mean()), 1),
    "avg_wau_2018": round(float(a18.wau.mean()), 1),
    "avg_mau28_2018": round(float(a18.mau_28d.mean()), 1),
    "avg_dau_mau_2018_pct": round(float(a18.dau_mau.mean()), 2),
    "avg_wau_mau_2018_pct": round(float(a18.wau_mau.mean()), 2),
    "peak_dau": int(au.dau.max()),
    "peak_dau_day": au.loc[au.dau.idxmax(), "day"].strftime("%Y-%m-%d"),
}

# ---------------- 6. deep dive: delivery delay -> review -> repeat ----------------
dv = read("09_delivery_vs_review")
fig, ax = plt.subplots(figsize=(11, 5))
colors = [BLUE if "early" in b else RED for b in dv.delay_bucket]
ax.bar(dv.delay_bucket.str[3:], dv.avg_review, color=colors)
for i, (v, s) in enumerate(zip(dv.avg_review, dv.one_star_pct)):
    ax.text(i, v + 0.05, f"{v:.2f}\n{s:.0f}% 1-star", ha="center", fontsize=9)
ax.set_ylim(0, 5)
ax.set_ylabel("Average review score")
ax.set_title("Review score collapses once an order misses its promised date")
plt.setp(ax.get_xticklabels(), rotation=20)
save(fig, "07_delay_vs_review.png")

mv = read("10_metric_movement_review_dip")
mv["month"] = pd.to_datetime(mv["month"])
fig, ax = plt.subplots(figsize=(11, 5))
ax.plot(mv.month, mv.avg_review, color=BLUE, marker="o", label="Avg review score")
ax.set_ylabel("Avg review score")
ax.set_ylim(3.6, 4.5)
ax2 = ax.twinx()
ax2.bar(mv.month, mv.late_pct, width=20, color=RED, alpha=0.35, label="Late delivery %")
ax2.set_ylabel("Late deliveries (%)")
ax2.grid(False)
ax2.yaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
ax.set_zorder(ax2.get_zorder() + 1)
ax.patch.set_visible(False)
h1, l1 = ax.get_legend_handles_labels(); h2, l2 = ax2.get_legend_handles_labels()
ax.legend(h1 + h2, l1 + l2, loc="lower left")
ax.set_title("Metric movement: review score dips track late-delivery spikes (Nov-17, Feb/Mar-18)")
save(fig, "08_review_dip_root_cause.png")

# mix vs rate decomposition of the Mar-2018 dip vs baseline (Jan-2018) -- shift-share
base = mv[mv.month == "2018-01-01"].iloc[0]
cur = mv[mv.month == "2018-03-01"].iloc[0]
L0, L1 = base.late_pct / 100, cur.late_pct / 100
mix = (L1 - L0) * ((base.avg_review_late + cur.avg_review_late) / 2 - (base.avg_review_on_time + cur.avg_review_on_time) / 2)
rate = ((1 - L0 + 1 - L1) / 2) * (cur.avg_review_on_time - base.avg_review_on_time) + ((L0 + L1) / 2) * (cur.avg_review_late - base.avg_review_late)
total = cur.avg_review - base.avg_review
findings["review_dip"] = {
    "baseline_month": "2018-01", "dip_month": "2018-03",
    "avg_review_baseline": float(base.avg_review), "avg_review_dip": float(cur.avg_review),
    "late_pct_baseline": float(base.late_pct), "late_pct_dip": float(cur.late_pct),
    "on_time_review_baseline": float(base.avg_review_on_time), "on_time_review_dip": float(cur.avg_review_on_time),
    "delta_total": round(float(total), 3),
    "delta_mix_from_more_late_orders": round(float(mix), 3),
    "delta_rate_within_groups": round(float(rate), 3),
    "mix_share_of_dip_pct": round(float(mix / total * 100), 1),
    "avg_delivery_days_baseline": float(base.avg_delivery_days), "avg_delivery_days_dip": float(cur.avg_delivery_days),
    "avg_promised_days_baseline": float(base.avg_promised_days), "avg_promised_days_dip": float(cur.avg_promised_days),
}
findings["delay_vs_review"] = dv.to_dict(orient="records")

# repeat-rate driver: late vs on-time first order (6+ months of observation)
drv = read("08_repeat_rate_drivers")
lf = drv[drv.driver == "late_flag"].set_index("bucket")
n_l, p_l = lf.loc["late", "first_orders"], lf.loc["late", "repeat_pct"] / 100
n_o, p_o = lf.loc["on time", "first_orders"], lf.loc["on time", "repeat_pct"] / 100
z, pv = two_prop_z(round(p_o * n_o), n_o, round(p_l * n_l), n_l)
rs = drv[drv.driver == "review_score"].set_index("bucket")
findings["repeat_drivers"] = {
    "on_time_first_order_repeat_pct": float(lf.loc["on time", "repeat_pct"]),
    "late_first_order_repeat_pct": float(lf.loc["late", "repeat_pct"]),
    "relative_gap_pct": round((p_l / p_o - 1) * 100, 1),
    "z": round(z, 2), "p_value": float(f"{pv:.2g}"),
    "n_on_time": int(n_o), "n_late": int(n_l),
    "review5_repeat_pct": float(rs.loc["5", "repeat_pct"]),
    "review1_repeat_pct": float(rs.loc["1", "repeat_pct"]),
}
fig, axes = plt.subplots(1, 2, figsize=(13, 4.8))
d1 = drv[drv.driver == "delivery_vs_estimate"]
d1 = d1[d1.bucket != "0. not delivered"]
axes[0].bar(d1.bucket.str[3:], d1.repeat_pct, color=[BLUE, BLUE, RED, RED])
axes[0].set_title("Repeat rate by 1st-order delivery vs promise")
d2 = drv[drv.driver == "review_score"]
d2 = d2[d2.bucket != "no review"]
axes[1].bar(d2.bucket, d2.repeat_pct, color=BLUE)
axes[1].set_title("Repeat rate by 1st-order review score")
axes[1].set_xlabel("Review score")
for a, d in zip(axes, [d1, d2]):
    a.yaxis.set_major_formatter(mtick.PercentFormatter(decimals=1))
    a.set_ylim(0, 5)
    for i, v in enumerate(d.repeat_pct):
        a.text(i, v + 0.08, f"{v:.2f}%", ha="center", fontsize=10)
fig.suptitle("Why is repeat rate low? First-order experience vs. ever buying again (first orders Jan-17..Feb-18)", y=1.03, fontsize=12)
save(fig, "09_repeat_rate_drivers.png")


# ---------------- 7. supply side: seller retention & health ----------------
sr = read("12_seller_retention")
sr["cohort_month"] = pd.to_datetime(sr["cohort_month"]).dt.strftime("%Y-%m")
ssz = sr.drop_duplicates("cohort_month").set_index("cohort_month")["cohort_size"]


def weighted_curve(df, sizes_, kmax=12):
    out = {}
    for k in range(1, kmax + 1):
        cells = []
        for cm in sizes_.index:
            maxk = (2018 - int(cm[:4])) * 12 + (8 - int(cm[5:]))
            if k <= maxk:
                v = df[(df.cohort_month == cm) & (df.month_k == k)]["retention_pct"]
                cells.append((float(v.iloc[0]) if len(v) else 0.0, sizes_[cm]))
        if cells:
            out[k] = sum(v * n for v, n in cells) / sum(n for _, n in cells)
    return pd.Series(out)


seller_curve = weighted_curve(sr, ssz)
buyer_curve = weighted_curve(co, sizes)
fig, ax = plt.subplots(figsize=(11, 5))
ax.plot(seller_curve.index, seller_curve.values, marker="o", color=RED, label="Sellers (% making a sale in month k)")
ax.plot(buyer_curve.index, buyer_curve.values, marker="o", color=BLUE, label="Buyers (% purchasing in month k)")
for k in (1, 6, 12):
    ax.annotate(f"{seller_curve[k]:.1f}%", (k, seller_curve[k]), textcoords="offset points", xytext=(0, 8), ha="center", fontsize=9, color=RED)
    ax.annotate(f"{buyer_curve[k]:.2f}%", (k, buyer_curve[k]), textcoords="offset points", xytext=(0, 8), ha="center", fontsize=9, color=BLUE)
ax.set_ylim(0, 70)
ax.yaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
ax.set_xlabel("Months since first transaction")
ax.set_title("Two-sided retention: sellers stay, buyers don't (cohort-size weighted)")
ax.legend()
save(fig, "10_buyer_vs_seller_retention.png")

sh = read("13_seller_health_vs_churn")
fig, axes = plt.subplots(1, 2, figsize=(13, 4.8))
for a, drv_, title in zip(axes, ["early_avg_review", "early_volume"],
                          ["by avg review in first 90 days", "by orders in first 90 days"]):
    d = sh[sh.driver == drv_]
    a.bar(d.bucket.str[3:], d.retained_pct, color=BLUE)
    for i, (v, n) in enumerate(zip(d.retained_pct, d.sellers)):
        a.text(i, v + 1, f"{v:.1f}%\n(n={n})", ha="center", fontsize=9)
    a.set_ylim(0, 115)
    a.yaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
    a.set_title(f"Seller still selling in days 91-180, {title}", fontsize=11)
save(fig, "11_seller_health_vs_retention.png")

liq = read("14_marketplace_liquidity")
findings["sellers"] = {
    "seller_m1_retention_pct": round(float(seller_curve[1]), 2),
    "seller_m6_retention_pct": round(float(seller_curve[6]), 2),
    "seller_m12_retention_pct": round(float(seller_curve[12]), 2),
    "buyer_m1_retention_pct": round(float(buyer_curve[1]), 3),
    "buyer_m6_retention_pct": round(float(buyer_curve[6]), 3),
    "buyer_m12_retention_pct": round(float(buyer_curve[12]), 3),
    "health_cohort_sellers": int(sh[sh.driver == "all"].sellers.iloc[0]),
    "health_cohort_retained_pct": float(sh[sh.driver == "all"].retained_pct.iloc[0]),
    "health_table": sh.to_dict(orient="records"),
    "active_sellers_jan2017": int(liq.iloc[0].active_sellers),
    "active_sellers_aug2018": int(liq.iloc[-1].active_sellers),
    "buyers_per_seller_aug2018": float(liq.iloc[-1].buyers_per_seller),
    "top10pct_seller_gmv_share_avg": round(float(liq.top10pct_seller_gmv_share.mean()), 2),
}

t2 = read("11_time_to_second_purchase")
findings["time_to_second"] = t2.to_dict(orient="records")

(OUT / "findings.json").write_text(json.dumps(findings, indent=2, default=float))
print(json.dumps(findings, indent=2, default=float))
