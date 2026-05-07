# Lesson 02 -- Calculate Costs
# Tutorial: accounting/02-buying-supplies.md
# Data:     accounting/src/data/02-purchases.json
# Run:      jq -f accounting/src/programs/02-calculate-costs.jq accounting/src/data/02-purchases.json

# ── 1. Sum purchase totals ──────────────────────────────────────────
#    Excel: =SUM(D2:D4) where column D holds each purchase total
"== Total Spent ==",
"Total supplies cost: $\([.purchases[].total] | add)",

# ── 2. Calculate remaining cash ─────────────────────────────────────
#    Excel: =B1-SUM(D2:D4) where B1 is starting cash
"",
"== Cash Remaining ==",
"Starting cash: $\(.starting_cash)",
"After purchases: $\(.starting_cash - ([.purchases[].total] | add))",
"Balance sheet cash: $\(.balance_sheet.assets.cash)",

# ── 3. Verify the balance sheet equation ────────────────────────────
#    Assets = Liabilities + Owner's Equity
#    Excel: =IF(SUM(assets)=SUM(liabilities)+SUM(equity),"Balanced","ERROR!")
"",
"== Balance Sheet Check ==",
(
  (.balance_sheet.assets.cash + ([.balance_sheet.assets.inventory | to_entries[].value] | add)) as $total_assets |
  ([.balance_sheet.owners_equity | to_entries[].value] | add) as $total_equity |
  "Total assets: $\($total_assets)",
  "Total equity: $\($total_equity)",
  "Balanced: \($total_assets == $total_equity)"
),

# ── 4. Compare costs between items ──────────────────────────────────
#    Excel: =IF(D2>D3,"Lemons cost more","Sugar costs more")
"",
"== Cost Comparisons ==",
(
  .purchases[0].total as $lemons |
  .purchases[1].total as $sugar |
  .purchases[2].total as $cups |
  "Lemons ($\($lemons)) > Sugar ($\($sugar)): \($lemons > $sugar)",
  "Cheapest item is Cups at $\($cups)",
  "Lemons cost \($lemons / $cups) times more than cups"
),

# ── 5. Cost per cup of lemonade ─────────────────────────────────────
#    Total cost / cups we can make = cost per serving
#    Excel: =SUM(D2:D4)/20
"",
"== Unit Economics ==",
(
  ([.purchases[].total] | add) as $total_cost |
  .purchases[2].quantity as $servings |
  ($total_cost / $servings) as $cost_per_cup |
  "Total cost: $\($total_cost)",
  "Servings: \($servings)",
  "Cost per cup: $\($cost_per_cup)"
),

# ── 6. Show types of different fields ───────────────────────────────
#    Excel: =TYPE(A1) returns 1 for number, 2 for text, etc.
"",
"== Field Types ==",
"date is a: \(.date | type)",
"starting_cash is a: \(.starting_cash | type)",
"purchases is an: \(.purchases | type)",
"balance_sheet is an: \(.balance_sheet | type)",
"liabilities is an: \(.balance_sheet.liabilities | type)",
"Liabilities empty? length = \(.balance_sheet.liabilities | length)"
