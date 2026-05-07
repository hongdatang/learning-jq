# Lesson 03 -- Sales Summary
# Tutorial: accounting/03-first-sales.md
# Data:     accounting/src/data/03-daily-sales.json
# Run:      jq -f accounting/src/programs/03-sales-summary.jq accounting/src/data/03-daily-sales.json

# ── 1. Total cups sold ───────────────────────────────────
# map extracts the quantity column, add sums it (like SUM in Excel)
"--- Total Cups Sold ---",
"Cups sold: \(.sales | map(.quantity) | add)",

# ── 2. Total revenue ────────────────────────────────────
"",
"--- Total Revenue ---",
"Revenue: $\(.sales | map(.total) | add)",

# ── 3. Average sale amount ──────────────────────────────
"",
"--- Average Sale ---",
"Number of transactions: \(.sales | length)",
"Average per transaction: $\(.sales | map(.total) | (add / length * 100 | floor) / 100)",

# ── 4. Filter: premium sales (unit_price > 1.00) ───────
"",
"--- Premium Sales (above $1.00/cup) ---",
(.sales | map(select(.unit_price > 1.00))),

# ── 5. Filter: a specific customer ─────────────────────
"",
"--- Mrs. Henderson's Purchases ---",
(.sales | map(select(.customer == "Mrs. Henderson"))),

# ── 6. First and last sale of the week ──────────────────
"",
"--- First and Last Sale ---",
"First sale: id \(.sales | first | .id) on \(.sales | first | .date)",
"Last sale:  id \(.sales | last  | .id) on \(.sales | last  | .date)",

# ── 7. Array indexing and slicing ───────────────────────
"",
"--- Indexing and Slicing ---",
"First sale (.[0]):  \(.sales[0])",
"Last sale  (.[-1]): \(.sales[-1])",
"Sales 3-5 (.[2:5]): \([.sales[2:5][] | .id])",

# ── 8. The comma operator: multiple fields at once ──────
"",
"--- Comma Operator: date + total for each sale ---",
[.sales[] | "\(.date): $\(.total)"],

# ── 9. Collecting with [...] ────────────────────────────
"",
"--- All unit prices (collected into an array) ---",
([.sales[].unit_price] | unique),

# ── 10. range: generating sequences ────────────────────
"",
"--- range: sale IDs 1 through 5 ---",
[range(1; 6)],

# ── 11. Type selectors ─────────────────────────────────
"",
"--- Type Selectors Demo ---",
"Numbers in first sale: \([.sales[0][] | numbers])",
"Strings in first sale: \([.sales[0][] | strings])",
"Scalars in first sale: \([.sales[0][] | scalars])",
"Iterables in data root: \([.[] | iterables] | length) items",

# ── 12. limit: first 3 sales only ──────────────────────
"",
"--- First 3 Sales (using limit) ---",
[limit(3; .sales[])]
