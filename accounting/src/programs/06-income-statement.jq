# Lesson 06 -- Income Statement
# Tutorial: accounting/06-the-income-statement.md
# Data:     accounting/src/data/06-income-data-week1.json
# Run:      jq -f accounting/src/programs/06-income-statement.jq accounting/src/data/06-income-data-week1.json

# ══════════════════════════════════════════════════════════
#  Functions -- reusable named formulas (like VBA macros)
# ══════════════════════════════════════════════════════════

# Sum all revenue from the sales array
def total_revenue:
  .sales | map(.revenue) | add;

# Cost of goods sold -- read from the data
def cogs:
  .cost_of_goods.total_cogs;

# Gross Profit = Revenue - COGS
def gross_profit:
  total_revenue - cogs;

# Sum all operating expenses
def total_expenses:
  .expenses | map(.amount) | add;

# Net Income = Gross Profit - Expenses
def net_income:
  gross_profit - total_expenses;

# Format a number as a dollar amount: 6 -> "$6.00"
# Uses split/join to ensure two decimal places (like Excel TEXT(A1,"$#,##0.00"))
def dollars:
  "$" + (. * 100 | round / 100 | tostring | split(".")
    | if length == 1 then .[0] + ".00"
      elif (.[1] | length) == 1 then join(".") + "0"
      else join(".")
      end);

# Calculate a percentage: margin(11; 21) -> "52.4%"
def margin(part; whole):
  if whole == 0
  then "N/A"
  else ((part / whole * 1000 | floor) / 10 | tostring) + "%"
  end;

# Classify a day's performance using if-then-elif-else
def day_rating:
  if .revenue == 0     then "No sales (rain day)"
  elif .revenue >= 8   then "Great day!"
  elif .revenue >= 5   then "Good day"
  elif .revenue >= 3   then "Okay day"
  else                      "Slow day"
  end;

# Safe division with try-catch (like IFERROR in Excel)
def safe_divide(numerator; denominator):
  try (numerator / denominator)
  catch "Error: division failed";

# ══════════════════════════════════════════════════════════
#  Header
# ══════════════════════════════════════════════════════════
"==================================================",
"  INCOME STATEMENT",
"  \(.period): \(.start_date) to \(.end_date)",
"==================================================",

# ══════════════════════════════════════════════════════════
#  Revenue section
# ══════════════════════════════════════════════════════════
"",
"--- Revenue ---",
total_revenue as $rev |
"  Sales Revenue:        \($rev | dollars)",

# ══════════════════════════════════════════════════════════
#  Cost of Goods Sold
# ══════════════════════════════════════════════════════════
"",
"--- Cost of Goods Sold ---",
cogs as $cogs |
"  COGS (\(.cost_of_goods.cups_sold) cups x \(.cost_of_goods.cost_per_cup | dollars)/cup): \($cogs | dollars)",

# ══════════════════════════════════════════════════════════
#  Gross Profit
# ══════════════════════════════════════════════════════════
"",
"--- Gross Profit ---",
total_revenue as $rev |
gross_profit as $gp |
"  Gross Profit:         \($gp | dollars)",
"  Gross Margin:         \(margin($gp; $rev))",

# ══════════════════════════════════════════════════════════
#  Operating Expenses
# ══════════════════════════════════════════════════════════
"",
"--- Operating Expenses ---",
(.expenses[] | "  \(.category): \(.amount | dollars)  (\(.description))"),
total_expenses as $exp |
"  --------------------------",
"  Total Expenses:       \($exp | dollars)",

# ══════════════════════════════════════════════════════════
#  Net Income (the bottom line)
# ══════════════════════════════════════════════════════════
"",
"==================================================",
total_revenue as $rev |
net_income as $ni |
"  NET INCOME:           \($ni | dollars)",
"  Net Margin:           \(margin($ni; $rev))",
"==================================================",

# ══════════════════════════════════════════════════════════
#  Daily breakdown with if-then-elif-else ratings
# ══════════════════════════════════════════════════════════
"",
"--- Daily Breakdown ---",
# if-then-elif-else: classify each day's performance
(.sales[] |
  if .revenue == 0
  then "  \(.date): CLOSED (rain) -- \(day_rating)"
  else "  \(.date): \(.cups) cups, \(.revenue | dollars) -- \(day_rating)"
  end),
# if-without-else (jq 1.8): pass through only active sales days unchanged
# When the condition is false, the input passes through as-is (identity)
"",
"--- Active Sales Days (if-without-else demo) ---",
([.sales[] | if .revenue > 0 then .date end | strings] | unique) as $active |
"  Days with sales: \($active | join(", "))",

# ══════════════════════════════════════════════════════════
#  split / join demo -- format expense categories
# ══════════════════════════════════════════════════════════
"",
"--- Expense Categories (split/join demo) ---",
"  All categories: \([.expenses[].category] | join(", "))",
"  Reversed:       \("Wages, Advertising" | split(", ") | reverse | join(" + "))",

# ══════════════════════════════════════════════════════════
#  try-catch demo -- safe division
# ══════════════════════════════════════════════════════════
"",
"--- Safe Division (try-catch demo) ---",
"  Revenue per cup: \(safe_divide(total_revenue; .cost_of_goods.cups_sold) | dollars)",
"  Division by zero test: \(safe_divide(100; 0))"
