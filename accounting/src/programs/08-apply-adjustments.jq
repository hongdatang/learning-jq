# Lesson 08 -- Apply Adjustments
# Tutorial: accounting/08-adjustments-and-accruals.md
# Data:     accounting/src/data/08-adjusting-entries.json
# Run:      jq -f accounting/src/programs/08-apply-adjustments.jq accounting/src/data/08-adjusting-entries.json

# ══════════════════════════════════════════════════════════
#  Helper functions
# ══════════════════════════════════════════════════════════

# Format a number as a dollar amount: 8 -> "$8.00"
def dollars:
  "$" + (. * 100 | round / 100 | tostring | split(".")
    | if length == 1 then .[0] + ".00"
      elif (.[1] | length) == 1 then join(".") + "0"
      else join(".")
      end);

# Right-pad a string to a given width (for alignment)
def pad(w):
  . + " " * ([w - length, 0] | max);

# ══════════════════════════════════════════════════════════
#  Save original input (like Excel's $Sheet1.$A$1 absolute ref)
# ══════════════════════════════════════════════════════════

. as $input |

# ══════════════════════════════════════════════════════════
#  1. Pre-Adjustment Balance Sheet
# ══════════════════════════════════════════════════════════

"==================================================",
"  MONTH-END ADJUSTMENTS",
"  Period ending: \(.period_end)",
"==================================================",
"",
"--- Pre-Adjustment Trial Balance ---",

# ── Destructuring bind: unpack the balances object ─────
# . as {$cash, $ar, ...} pulls named fields into variables.
# This is like naming cells in Excel: $A$1 = Cash, $B$1 = A/R.
#
# {$var} shorthand (jq 1.8): {$cash} means {"cash": $cash}.

.pre_adjustment_balances as {
  $cash,
  accounts_receivable: $ar,
  $inventory,
  prepaid_insurance: $prepaid,
  $equipment,
  accumulated_depreciation: $accum_dep,
  notes_payable: $notes,
  owners_equity: $oe,
  retained_earnings: $re
} |

"  Cash:                  \($cash | dollars)",
"  Accounts Receivable:   \($ar | dollars)",
"  Inventory:             \($inventory | dollars)",
"  Prepaid Insurance:     \($prepaid | dollars)",
"  Equipment:             \($equipment | dollars)",
"  Accum. Depreciation:   \($accum_dep | dollars)",
"                          ----------",
"  Total Assets:          \($cash + $ar + $inventory + $prepaid + $equipment - $accum_dep | dollars)",
"",
"  Notes Payable:         \($notes | dollars)",
"  Owner's Equity:        \($oe | dollars)",
"  Retained Earnings:     \($re | dollars)",
"                          ----------",
"  Total L + OE:          \($notes + $oe + $re | dollars)",
"",

# ══════════════════════════════════════════════════════════
#  2. Process adjusting entries with foreach
# ══════════════════════════════════════════════════════════
#
# foreach is like a column where each row depends on the
# row above. You carry a running total (the "state") and
# update it for each entry.
#
# foreach EXPR as $var (INIT; UPDATE; EXTRACT)
#   EXPR   = the values to loop over
#   INIT   = starting state
#   UPDATE = how to change state for each value
#   EXTRACT = what to output after each step

"--- Applying Adjusting Entries (foreach) ---",
"",

# foreach walks the adjusting entries and updates the
# balance sheet after each one.  After each step, we
# extract the journal entry line and the running balances.

foreach .adjusting_entries[] as $entry (

  # INIT: start with the pre-adjustment balances
  .pre_adjustment_balances;

  # UPDATE: apply debit/credit to the running balances.
  # Debits to expense accounts reduce retained earnings.
  # Credits to asset accounts subtract; credits to contra-asset
  # accounts (accumulated_depreciation) add.
  if $entry.credit.account == "accumulated_depreciation"
  then .accumulated_depreciation += $entry.credit.amount
  else .[$entry.credit.account] -= $entry.credit.amount
  end
  | .retained_earnings -= $entry.debit.amount;

  # EXTRACT: output the journal entry and running retained earnings
  "  \($entry.id): \($entry.description)"
  , "    Debit:  \($entry.debit.account | gsub("_"; " "))  \($entry.debit.amount | dollars)"
  , "    Credit: \($entry.credit.account | gsub("_"; " "))  \($entry.credit.amount | dollars)"
  , "    (Retained Earnings now: \(.retained_earnings | dollars))"
  , ""
),

# ══════════════════════════════════════════════════════════
#  3. Generate depreciation schedule with foreach
# ══════════════════════════════════════════════════════════
#
# This is a classic "running total" column, like Excel
# column C where C2 = C1 + B2, C3 = C2 + B3, and so on.

"--- Depreciation Schedule (foreach with running state) ---",
"",
"  Month  Expense  Accumulated  Book Value",
"  ─────  ───────  ───────────  ──────────",

.depreciation_schedule as {$cost, $monthly_depreciation} |

foreach range(.depreciation_schedule.useful_life_months) as $i (

  # INIT: no depreciation accumulated yet
  { accumulated: 0, book_value: $cost };

  # UPDATE: add one month of depreciation
  .accumulated += $monthly_depreciation
  | .book_value -= $monthly_depreciation;

  # EXTRACT: print the row
  # Destructuring the state: . as {$accumulated, $book_value}
  . as {$accumulated, $book_value} |
  "  \($i + 1 | tostring | pad(6)) \($monthly_depreciation | dollars | pad(8)) \($accumulated | dollars | pad(12)) \($book_value | dollars)"
),

# ══════════════════════════════════════════════════════════
#  4. empty and generators -- filtering adjustments
# ══════════════════════════════════════════════════════════
#
# empty produces zero outputs -- it is like a row that
# vanishes. FILTER() in Excel removes blanks; empty
# removes values that fail a test.
#
# A generator is anything that can produce multiple outputs
# (or zero outputs). .[] is a generator. select() uses
# empty internally: when the condition is false, select
# calls empty and the value disappears.

"",
"--- Expense-Only Adjustments (empty filters non-expenses) ---",

# Walk all entries; keep only those whose debit account
# ends with "_expense"; discard the rest via empty.
(
  .adjusting_entries[] |

  # Destructuring bind: unpack the debit side
  .debit as {$account, $amount} |

  # If the account name does not contain "expense", produce
  # nothing (empty). Otherwise output the line.
  if ($account | test("expense"))
  then "  \($account | gsub("_"; " ") | pad(24)) \($amount | dollars)"
  else empty
  end
),

# ══════════════════════════════════════════════════════════
#  5. Post-Adjustment Balance Sheet
# ══════════════════════════════════════════════════════════

"",
"==================================================",
"  POST-ADJUSTMENT BALANCE SHEET",
"==================================================",
"",

# Apply all adjustments using reduce to get final balances.
# Then destructure the result for display.
(
  reduce .adjusting_entries[] as $entry (
    .pre_adjustment_balances;
    if $entry.credit.account == "accumulated_depreciation"
    then .accumulated_depreciation += $entry.credit.amount
    else .[$entry.credit.account] -= $entry.credit.amount
    end
    | .retained_earnings -= $entry.debit.amount
  )
) as $final |

# Destructuring bind on the final balances.
# . as {key: $var} pulls named fields into separate variables --
# like naming cells in Excel so you can reference them everywhere.
$final | . as {
  $cash,
  accounts_receivable: $ar,
  $inventory,
  prepaid_insurance: $prepaid,
  $equipment,
  accumulated_depreciation: $accum_dep,
  notes_payable: $notes,
  owners_equity: $oe,
  retained_earnings: $re
} |

# Compute totals
($cash + $ar + $inventory + $prepaid + $equipment - $accum_dep) as $total_assets |
($notes + $oe + $re) as $total_l_oe |

"ASSETS",
"  Cash:                  \($cash | dollars)",
"  Accounts Receivable:   \($ar | dollars)",
"  Inventory:             \($inventory | dollars)",
"  Prepaid Insurance:     \($prepaid | dollars)",
"  Equipment:             \($equipment | dollars)",
"  Accum. Depreciation:  -\($accum_dep | dollars)",
"                          ----------",
"  Total Assets:          \($total_assets | dollars)",
"",
"LIABILITIES + EQUITY",
"  Notes Payable:         \($notes | dollars)",
"  Owner's Equity:        \($oe | dollars)",
"  Retained Earnings:     \($re | dollars)",
"                          ----------",
"  Total L + OE:          \($total_l_oe | dollars)",
"",
"==================================================",
(if $total_assets == $total_l_oe
 then "  The books balance! Assets \($total_assets | dollars) = L+OE \($total_l_oe | dollars)"
 else "  WARNING: OFF by \(($total_assets - $total_l_oe) | fabs | dollars)!"
 end),
"==================================================",
"",

# ══════════════════════════════════════════════════════════
#  6. Summary: total adjustment impact
# ══════════════════════════════════════════════════════════

"--- Impact Summary ({$var} shorthand) ---",

# Use {$var} shorthand to build a compact summary object.
# {$total} is the same as {"total": $total}.
($input.adjusting_entries | map(.debit.amount) | add) as $total |
($input.adjusting_entries | length) as $count |
{$count, $total, average: ($total / $count)} |
"  Entries processed: \(.count)",
"  Total adjustment:  \(.total | dollars)",
"  Average per entry: \(.average * 100 | round / 100 | dollars)"
