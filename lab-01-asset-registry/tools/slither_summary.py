"""Summarize Slither's JSON output: findings per impact, detector and origin."""
import json
import sys

detectors = json.load(sys.stdin)["results"]["detectors"]
rows: dict[tuple[str, str, str], int] = {}
for r in detectors:
    files = {e.get("source_mapping", {}).get("filename_relative", "")
             for e in r["elements"]}
    where = "ours" if any(f.startswith("contracts/") for f in files) else "OpenZeppelin"
    key = (r["impact"], r["check"], where)
    rows[key] = rows.get(key, 0) + 1

order = {"High": 0, "Medium": 1, "Low": 2, "Informational": 3, "Optimization": 4}
print(f"{'impact':<14}{'detector':<26}{'found in':<14}count")
for (impact, check, where), n in sorted(rows.items(),
                                       key=lambda kv: order[kv[0][0]]):
    print(f"{impact:<14}{check:<26}{where:<14}{n}")
