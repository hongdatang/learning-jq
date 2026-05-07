# Lesson 01 -- View Accounts
# Tutorial: accounting/01-opening-day.md
# Data:     accounting/src/data/01-opening-day.json
# Run:      jq -f accounting/src/programs/01-view-accounts.jq accounting/src/data/01-opening-day.json

# --- Read basic business info ---
"=== Business Info ===",
("Business: " + .business),
("Owner:    " + .owner),
("Date:     " + .date),

# --- Navigate to a nested value ---
"",
"=== Cash on Hand ===",
("Cash: $" + (.balance_sheet.assets.cash | tostring)),

# --- Verify the accounting equation: Assets = Liabilities + Equity ---
"",
"=== Accounting Equation Check ===",
(.balance_sheet.assets | add) as $assets
| (.balance_sheet.liabilities | add // 0) as $liabilities
| (.balance_sheet.owners_equity | add) as $equity
| ("Assets:      $" + ($assets | tostring)),
  ("Liabilities: $" + ($liabilities | tostring)),
  ("Equity:      $" + ($equity | tostring)),
  (""),
  if $assets == ($liabilities + $equity)
  then "The books balance! Assets ($\($assets)) = Liabilities + Equity ($\($liabilities + $equity))"
  else "WARNING: Books do not balance!"
  end
