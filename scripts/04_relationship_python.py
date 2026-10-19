# scripts/04_relationship_python.py
# Question 5: Python replication of Question 3 band table and figure (Variant 0: Punjab rural)

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

person = pd.read_csv("data/pslm_person_subset.csv")
hh = pd.read_csv("data/pslm_hh_subset.csv")[["hhid", "hhweight", "prov_code", "urban_rural"]]

df = person.merge(hh, on="hhid", how="left")

# Variant 0: Punjab rural (prov_code == 2, urban_rural == 1), age 10-64, non-missing literate
lit = df[
    (df["prov_code"] == 2) &
    (df["urban_rural"] == 1) &
    (df["age"] >= 10) & (df["age"] <= 64) &
    (df["literate"].notna()) &
    (df["sex"].isin([1, 2]))
].copy()

lit["band_start"] = ((lit["age"] - 10) // 5) * 5 + 10
lit["band_end"] = lit["band_start"] + 4
lit["age_band"] = lit["band_start"].astype(int).astype(str) + "-" + lit["band_end"].astype(int).astype(str)
lit["midpoint"] = lit["band_start"] + 2
lit["sex_label"] = np.where(lit["sex"] == 1, "Men", "Women")

records = []
for (age_band, midpoint, sex_label), grp in lit.groupby(["age_band", "midpoint", "sex_label"]):
    n_unw = len(grp)
    w_lit = 100.0 * (grp["hhweight"] * grp["literate"]).sum() / grp["hhweight"].sum()
    records.append({
        "age_band": age_band,
        "midpoint": int(midpoint),
        "sex_label": sex_label,
        "n_unweighted": n_unw,
        "lit_rate": w_lit,
        "is_thin": n_unw < 30
    })

band_stats = pd.DataFrame(records).sort_values(["midpoint", "sex_label"])

piv = band_stats.pivot(index=["age_band", "midpoint"], columns="sex_label", values=["n_unweighted", "lit_rate"]).reset_index()
piv.columns = ["age_band", "midpoint", "n_Men", "n_Women", "lit_Men", "lit_Women"]
piv = piv.sort_values("midpoint").reset_index(drop=True)
piv["gap"] = piv["lit_Men"] - piv["lit_Women"]

print("\n================ QUESTION 5 PYTHON BAND TABLE ================")
print(piv.to_string(index=False, float_format=lambda x: f"{x:.1f}"))
w_15_19 = piv.loc[piv["age_band"] == "15-19", "lit_Women"].values[0]
print(f"\nPython Women aged 15-19 literacy rate: {w_15_19:.1f}%")
print("==============================================================\n")

fig, ax = plt.subplots(figsize=(8.5, 5.2))
colors = {"Men": "#1f78b4", "Women": "#e31a1c"}

for sex_label in ["Men", "Women"]:
    sub = band_stats[band_stats["sex_label"] == sex_label].sort_values("midpoint")
    ax.plot(sub["midpoint"], sub["lit_rate"], color=colors[sex_label], linewidth=2)

    solid = sub[~sub["is_thin"]]
    ax.scatter(solid["midpoint"], solid["lit_rate"], color=colors[sex_label], s=45, zorder=3)

    thin = sub[sub["is_thin"]]
    if len(thin) > 0:
        ax.scatter(thin["midpoint"], thin["lit_rate"], facecolors="none", edgecolors=colors[sex_label], s=45, linewidths=1.5, zorder=3)

    end_row = sub[sub["midpoint"] == 62].iloc[0]
    ax.text(
        end_row["midpoint"] + 0.8, end_row["lit_rate"],
        f"{sex_label} ({end_row['lit_rate']:.1f}%)",
        color=colors[sex_label], fontweight="bold", va="center", fontsize=9.5
    )

max_row = piv.loc[piv["gap"].abs().idxmax()]
ax.plot(
    [max_row["midpoint"], max_row["midpoint"]],
    [max_row["lit_Women"], max_row["lit_Men"]],
    color="dimgray", linestyle=":", linewidth=1.2
)
ax.text(
    max_row["midpoint"], (max_row["lit_Men"] + max_row["lit_Women"]) / 2,
    f"Largest gap ({max_row['age_band']}):\n{max_row['gap']:.1f} pp",
    ha="center", va="center", fontsize=8.5,
    bbox=dict(boxstyle="round,pad=0.3", facecolor="white", edgecolor="lightgray")
)

ax.set_xlim(10, 71)
ax.set_ylim(0, 100)
ax.set_xticks(piv["midpoint"])
ax.set_xticklabels(piv["age_band"])
ax.set_yticks(range(0, 101, 20))
ax.grid(True, linestyle="-", linewidth=0.5, color="#ebebeb")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

ax.set_title(
    "Literacy Rises Sharply in Younger Cohorts in Rural Punjab, Narrowing the Gender Gap",
    loc="left", fontweight="bold", fontsize=11.5, pad=18
)
plt.suptitle(
    "Weighted literacy rate (%) by 5-year age band and sex, plotted at band midpoints",
    x=0.125, y=0.93, ha="left", fontsize=9.5, color="#333333"
)
ax.set_xlabel("Age Band (plotted at 5-year midpoints: 12, 17, ..., 62)", fontsize=10)
ax.set_ylabel("Weighted Literacy Rate (%)", fontsize=10)

caption = (
    f"Source: PSLM 2019-20 person and household files. Sample: Persons aged 10-64 with non-missing literacy "
    f"in rural Punjab (n = {len(lit):,}).\nWeighted by hhweight. Hollow markers indicate thin cells with fewer than 30 unweighted observations."
)
fig.text(0.125, 0.01, caption, fontsize=8, color="#4d4d4d")
plt.tight_layout(rect=[0, 0.05, 1, 0.91])

os.makedirs("figures", exist_ok=True)
plt.savefig("figures/relationship_python.svg")
plt.close()
