# Lesson 07 -- Post Transactions
# Tutorial: accounting/07-growing-the-business.md
# Data:     accounting/src/data/07-week2-transactions.json
# Run:      jq -f accounting/src/programs/07-post-transactions.jq accounting/src/data/07-week2-transactions.json

# ══════════════════════════════════════════════════════════
#  Helper: format a dollar amount
# ══════════════════════════════════════════════════════════

def dollars:
  "$" + (. * 100 | round / 100 | tostring | split(".")
    | if length == 1 then .[0] + ".00"
      elif (.[1] | length) == 1 then join(".") + "0"
      else join(".")
      end);

# ══════════════════════════════════════════════════════════
#  Helper: classify which section an account belongs to
# ══════════════════════════════════════════════════════════

def account_section:
  if   . == "cash" or . == "accounts_receivable" or . == "inventory"
       or . == "prepaid_insurance" or . == "equipment"
  then "assets"
  elif . == "notes_payable"
  then "liabilities"
  elif . == "invested_capital" or . == "retained_earnings"
  then "owners_equity"
  else "income"          # revenue, cogs, interest_expense
  end;

# ══════════════════════════════════════════════════════════
#  Starting state -- display the opening balance sheet
# ══════════════════════════════════════════════════════════

"==================================================",
"  WEEK 2 -- POSTING TRANSACTIONS",
"  June 8-12, 2024",
"==================================================",
"",
"Starting balance sheet (end of Week 1):",
"  Cash:                \(.starting_balance_sheet.assets.cash | dollars)",
"  Owner's Equity:      \(.starting_balance_sheet.owners_equity.invested_capital | dollars)",
"  Retained Earnings:   \(.starting_balance_sheet.owners_equity.retained_earnings | dollars)",
"",

# ══════════════════════════════════════════════════════════
#  Post each transaction using reduce with update operators
#
#  This is the core of the lesson.  reduce walks through
#  every transaction.  For each entry in a transaction,
#  we use //= to create the account if it doesn't exist,
#  then += to adjust the balance.
#
#  Excel analogy: imagine you have a balance sheet in one
#  tab.  For each journal entry you go to the right cell
#  and type "=old_value + change".  That's what += does.
# ══════════════════════════════════════════════════════════

.starting_balance_sheet as $start |

# Build the initial ledger from the balance sheet
(
  $start.assets +
  $start.liabilities +
  $start.owners_equity
) as $opening_ledger |

# reduce: walk every transaction, accumulating the ledger
reduce .transactions[] as $txn (

  # Accumulator: the ledger (one flat object of account -> balance)
  # plus a log of snapshots after each transaction
  { "ledger": $opening_ledger, "log": [] };

  # For each transaction, apply every entry to the ledger.
  # Inner reduce walks the entries array.
  reduce $txn.entries[] as $entry (
    .;
    # //= creates the account with 0 if it doesn't exist yet
    #     (like IFERROR(cell, 0) -- ensure the cell has a number)
    .ledger[$entry.account] //= 0 |

    # += adjusts the balance in place
    #     (like typing =B2+change into the cell)
    .ledger[$entry.account] += $entry.change
  )

  # After processing all entries, snapshot the state
  | .log += [{
      id:          $txn.id,
      description: $txn.description,
      date:        $txn.date,
      snapshot:    .ledger
    }]

) as $result |

# ══════════════════════════════════════════════════════════
#  Display each transaction and the ledger state after it
# ══════════════════════════════════════════════════════════

($result.log[] |
  "--------------------------------------------------",
  "Txn #\(.id) [\(.date)] \(.description)",
  "--------------------------------------------------",

  # Show each account balance after this transaction.
  # .snapshot is a flat object; use to_entries to iterate.
  # try ... silently skips accounts with display issues (? operator demo)
  (try (
    .snapshot | to_entries | sort_by(.key)[] |
    "  \(.key | gsub("_"; " ") | .[0:24])  \(.value | dollars)"
  )),
  ""
),

# ══════════════════════════════════════════════════════════
#  Final balance sheet -- classify accounts into sections
# ══════════════════════════════════════════════════════════

# Extract the final ledger state from the last log entry
(($result.log | last) |

"==================================================",
"  FINAL BALANCE SHEET -- End of Week 2",
"==================================================",
"",

# Classify each account into its section
(.snapshot | to_entries | reduce .[] as $acct (
  { "assets": {}, "liabilities": {}, "owners_equity": {}, "income": {} };
  .[$acct.key | account_section] += { ($acct.key): $acct.value }
)) as $classified |

# Display assets
"ASSETS",
"------------------------------",
($classified.assets | to_entries[] |
  "  \(.key | gsub("_"; " "))          \(.value | dollars)"),
($classified.assets | [.[]] | add) as $total_assets |
"                        ----------",
"  TOTAL ASSETS            \($total_assets | dollars)",
"",

# Display liabilities
"LIABILITIES",
"------------------------------",
($classified.liabilities | to_entries[] |
  "  \(.key | gsub("_"; " "))          \(.value | dollars)"),
($classified.liabilities | [.[]] | add // 0) as $total_liab |
"                        ----------",
"  TOTAL LIABILITIES       \($total_liab | dollars)",
"",

# Display owner's equity (add net income to retained_earnings)
# Net income = revenue - cogs - interest_expense
($classified.income.revenue // 0) as $revenue |
($classified.income.cogs // 0) as $cogs |
($classified.income.interest_expense // 0) as $interest |
($revenue - $cogs - $interest) as $net_income |

"OWNER'S EQUITY",
"------------------------------",
"  invested capital         \($classified.owners_equity.invested_capital | dollars)",
"  retained earnings (wk1)  \($classified.owners_equity.retained_earnings | dollars)",
"  + net income (wk2)       \($net_income | dollars)",
($classified.owners_equity.invested_capital
 + $classified.owners_equity.retained_earnings
 + $net_income) as $total_equity |
"                        ----------",
"  TOTAL EQUITY            \($total_equity | dollars)",
"",

# Verify A = L + OE
"==================================================",
"  TOTAL L + OE            \($total_liab + $total_equity | dollars)",
"==================================================",
"",
if $total_assets == ($total_liab + $total_equity)
then "The books balance! A (\($total_assets | dollars)) = L + OE (\($total_liab + $total_equity | dollars))"
else "WARNING: Books do NOT balance! A=\($total_assets | dollars), L+OE=\($total_liab + $total_equity | dollars)"
end,
"",
"--- Week 2 Income Summary ---",
"  Revenue:              \($revenue | dollars)",
"  COGS:                -\($cogs | dollars)",
"  Interest Expense:    -\($interest | dollars)",
"                        ------",
"  Net Income:           \($net_income | dollars)"
)
