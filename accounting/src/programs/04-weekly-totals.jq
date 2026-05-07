# Lesson 04 -- Weekly Totals
# Tutorial: accounting/04-end-of-week.md
# Data:     accounting/src/data/04-week1-transactions.json
# Run:      jq -f accounting/src/programs/04-weekly-totals.jq accounting/src/data/04-week1-transactions.json

# ── 1. Sort all transactions by date ────────────────────
# Like clicking Data > Sort in Excel
"=== All Transactions (sorted by date, then by id) ===",
[sort_by(.date, .id)[] | "\(.date)  \(.type | . + " " * (12 - length))  $\(.amount)\t\(.description)"],

# ── 2. Unique transaction types ─────────────────────────
# Like Remove Duplicates on a column
"",
"=== Transaction Types Used This Week ===",
([.[] | .type] | unique),

# ── 3. Group by type with subtotals ────────────────────
# Like a Pivot Table: row = type, value = SUM(amount)
"",
"=== Totals by Type (Pivot Table) ===",
[group_by(.type)[] | {
  type:  .[0].type,
  count: length,
  total: (map(.amount) | add)
}],

# ── 4. Revenue by day ──────────────────────────────────
# Group just the sales, then subtotal each day
"",
"=== Daily Revenue ===",
[map(select(.type == "sale")) | group_by(.date)[] | {
  date:    .[0].date,
  cups:    length,
  revenue: (map(.amount) | add)
}],

# ── 5. Best and worst revenue days ─────────────────────
# Like MAX and MIN on a column
"",
"=== Best and Worst Days ===",
(
  [map(select(.type == "sale")) | group_by(.date)[] | {
    date:    .[0].date,
    revenue: (map(.amount) | add)
  }]
) as $days |
"Best day:  \($days | max_by(.revenue) | "\(.date) ($\(.revenue))")",
"Worst day: \($days | min_by(.revenue) | "\(.date) ($\(.revenue))")",

# ── 6. Top 3 largest transactions ──────────────────────
# Like sorting descending then taking the first 3 rows
"",
"=== Top 3 Transactions by Amount ===",
[sort_by(.amount) | reverse | limit(3; .[])],

# ── 7. Object construction shorthand ───────────────────
# Pick only the columns you need -- like hiding columns in Excel
"",
"=== Compact View (type + amount only) ===",
[.[:5][] | {type, amount}],

# ── 8. to_entries: turn an object into rows ─────────────
# Like unpivoting a row into a tall table
"",
"=== to_entries Demo: Pivot Table as Rows ===",
(
  [group_by(.type)[] | {(.[0].type): (map(.amount) | add)}] | add
  | to_entries
),

# ── 9. skip: ignore the first N results ────────────────
# Like deleting the header rows to get to real data (jq 1.8)
"",
"=== Skip first 5 transactions ===",
"(Transactions 6-20, skipping the setup transactions)",
"Remaining transactions: \([skip(5; .[])] | length)",

# ── 10. Week 1 summary ─────────────────────────────────
"",
"=== Week 1 Summary ===",
(map(select(.type == "sale"))        | map(.amount) | add) as $revenue     |
(map(select(.type == "purchase"))    | map(.amount) | add) as $supplies    |
(map(select(.type == "wage"))        | map(.amount) | add) as $wages       |
(map(select(.type == "advertising")) | map(.amount) | add) as $advertising |
($supplies + $wages + $advertising) as $expenses |
"Revenue (sales):      $\($revenue)",
"Supplies purchased:  -$\($supplies)",
"Wages paid:          -$\($wages)",
"Advertising:         -$\($advertising)",
"Total expenses:      -$\($expenses)",
"─────────────────────────",
"Net income:           $\($revenue - $expenses)"
