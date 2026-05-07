# Lesson 11 -- Full Financial Statements
# Tutorial: accounting/11-financial-statements.md
# Data:     accounting/src/data/11-full-month.json
# Run:      jq -L accounting/src/lib -f accounting/src/programs/11-full-statements.jq accounting/src/data/11-full-month.json

include "accounting";

# ══════════════════════════════════════════════════════════
#  1. INDEX -- Build a lookup table from chart of accounts
# ══════════════════════════════════════════════════════════
#
# INDEX is the jq equivalent of VLOOKUP / XLOOKUP in Excel.
# It takes a stream of objects and builds a dictionary keyed
# by whatever field you choose.
#
# INDEX(.chart_of_accounts[]; .code) produces:
#   { "1000": { "code": "1000", "name": "Cash", ... },
#     "1100": { "code": "1100", "name": "Accounts Receivable", ... },
#     ... }
#
# Now you can look up any account by code: $lookup["1000"].name

INDEX(.chart_of_accounts[]; .code) as $lookup |

# ══════════════════════════════════════════════════════════
#  1b. JOIN -- Pair balances with account metadata
# ══════════════════════════════════════════════════════════
#
# JOIN combines two data sources by key -- like VLOOKUP run
# down an entire column at once.
#
# JOIN($lookup; stream; key_expr) takes each element of
# stream, evaluates key_expr to get a key, looks it up in
# $lookup, and emits [element, match].
#
# Here we join account_balances with chart_of_accounts to
# produce a report with names alongside balances.

[
  JOIN(
    $lookup;
    .account_balances | to_entries[];
    .key
  )
  | select(.[1] != null)
  | { code: .[0].key, name: .[1].name, type: .[1].type, balance: .[0].value }
  | select(.balance != 0)
] as $joined_balances |

# ══════════════════════════════════════════════════════════
#  2. walk -- Normalize all account names to title case
# ══════════════════════════════════════════════════════════
#
# walk(f) applies f to every node in a JSON tree -- every
# string, number, array, and object at every depth.  It is
# like "Find & Replace" across the entire workbook.
#
# Here we use it to trim whitespace from every string value.
# (walk only sees leaf values when used with type checks.)

(. | walk(if type == "string" then ltrim | rtrim else . end)) as $clean |

# ══════════════════════════════════════════════════════════
#  3. Resolve account codes to names using the INDEX lookup
# ══════════════════════════════════════════════════════════
#
# For each account code in pre_closing_balances, look up
# the full account name and type from $lookup.
# This is like VLOOKUP(A2, chart, 2, FALSE) in Excel.

def account_name(code):
  $lookup[code].name // "Unknown (\(code))";

def account_type(code):
  $lookup[code].type // "unknown";

# ══════════════════════════════════════════════════════════
#  4. contains / startswith -- Filter by account type
# ══════════════════════════════════════════════════════════
#
# startswith("1") checks if a code starts with "1" (assets).
# contains("Expense") checks if a name contains "Expense".
#
# These are like LEFT(A1,1)="1" and SEARCH("Expense",A1)
# in Excel, but cleaner.

# Collect pre-closing balances with resolved names
[
  $clean.pre_closing_balances | to_entries[] |
  {
    code:    .key,
    name:    account_name(.key),
    type:    account_type(.key),
    balance: .value
  }
] as $all_accounts |

# Filter by type using startswith on the code
[ $all_accounts[] | select(.code | startswith("1")) ] as $assets |
[ $all_accounts[] | select(.code | startswith("2")) ] as $liabilities |
[ $all_accounts[] | select(.code | startswith("3")) ] as $equity_accts |

# Filter revenue and expenses using contains on the type
[ $all_accounts[] | select(.type | contains("revenue")) ] as $revenue |
[ $all_accounts[] | select(.type | contains("expense")) ] as $expenses |

# ══════════════════════════════════════════════════════════
#  5. INCOME STATEMENT
# ══════════════════════════════════════════════════════════

# Revenue total
($revenue | map(.balance) | add // 0) as $total_revenue |

# COGS -- account 5000
([ $all_accounts[] | select(.code | startswith("5")) ] | map(.balance) | add // 0) as $cogs |

# Gross profit
($total_revenue - $cogs) as $gross_profit |

# Operating expenses (6xxx accounts)
([ $all_accounts[] | select(.code | startswith("6")) ]) as $opex_list |
($opex_list | map(.balance) | add // 0) as $total_opex |

# Net income
($gross_profit - $total_opex) as $net_income |

"==================================================",
"  INCOME STATEMENT",
"  \($clean.period): \($clean.start_date) to \($clean.end_date)",
"==================================================",
"",
"REVENUE",
($revenue[] | "  \(.name | pad(28)) \(.balance | dollars | lpad(10))"),
"                               ----------",
"  Total Revenue                \($total_revenue | dollars | lpad(10))",
"",
"COST OF GOODS SOLD",
([ $all_accounts[] | select(.code | startswith("5")) ] | .[] |
  "  \(.name | pad(28)) \(.balance | dollars | lpad(10))"),
"                               ----------",
"  Gross Profit                 \($gross_profit | dollars | lpad(10))",
"  Gross Margin                 \($gross_profit / $total_revenue * 100 | floor | tostring)%",
"",
"OPERATING EXPENSES",
($opex_list[] | "  \(.name | pad(28)) \(.balance | dollars | lpad(10))"),
"                               ----------",
"  Total Expenses               \($total_opex | dollars | lpad(10))",
"",
"==================================================",
"  NET INCOME                   \($net_income | dollars | lpad(10))",
"  Net Margin                   \($net_income / $total_revenue * 100 | floor | tostring)%",
"==================================================",
"",

# ══════════════════════════════════════════════════════════
#  6. BALANCE SHEET (using post-closing balances)
# ══════════════════════════════════════════════════════════
#
# The balance sheet uses account_balances (post-closing),
# where temporary accounts are zeroed out and net income
# has been transferred to Retained Earnings.

# Rebuild account list from post-closing balances
[
  $clean.account_balances | to_entries[] |
  select(.value != 0) |
  {
    code:    .key,
    name:    account_name(.key),
    type:    account_type(.key),
    balance: .value
  }
] as $bs_accounts |

# IN(stream) -- membership testing
# Check which codes are active (have a non-zero balance).
# IN(.account_balances | keys[]) tests if a code exists
# among the balance keys.  Like MATCH() in Excel.

[
  $clean.chart_of_accounts[] |
  select(.code | IN($clean.account_balances | keys[]))
  | .code
] as $active_codes |

# Asset accounts (post-closing)
[ $bs_accounts[] | select(.code | startswith("1")) ] as $bs_assets |
([ $bs_assets[] | select(.code != "1410") ] | map(.balance) | add // 0) as $assets_gross |
([ $bs_assets[] | select(.code == "1410") ] | map(.balance) | add // 0) as $accum_dep |
($assets_gross + $accum_dep) as $total_assets |

# Liabilities
[ $bs_accounts[] | select(.code | startswith("2")) ] as $bs_liabs |
($bs_liabs | map(.balance) | add // 0) as $total_liabs |

# Equity
[ $bs_accounts[] | select(.code | startswith("3")) ] as $bs_equity |
($bs_equity | map(.balance) | add // 0) as $total_equity |

"==================================================",
"  BALANCE SHEET",
"  As of \($clean.end_date)",
"==================================================",
"",
"ASSETS",
([ $bs_assets[] | select(.code != "1410") ] | .[] |
  "  \(.name | pad(28)) \(.balance | dollars | lpad(10))"),
([ $bs_assets[] | select(.code == "1410") ] | .[] |
  "  \(.name | pad(28)) \(.balance | dollars | lpad(10))"),
"                               ----------",
"  Total Assets                 \($total_assets | dollars | lpad(10))",
"",
"LIABILITIES",
($bs_liabs[] | "  \(.name | pad(28)) \(.balance | dollars | lpad(10))"),
"                               ----------",
"  Total Liabilities            \($total_liabs | dollars | lpad(10))",
"",
"OWNER'S EQUITY",
($bs_equity[] | "  \(.name | pad(28)) \(.balance | dollars | lpad(10))"),
"                               ----------",
"  Total Equity                 \($total_equity | dollars | lpad(10))",
"",
"==================================================",
"  Total Liabilities + Equity   \($total_liabs + $total_equity | dollars | lpad(10))",
"==================================================",
"",
(if $total_assets == ($total_liabs + $total_equity)
 then "  The books balance! Assets \($total_assets | dollars) = L+OE \($total_liabs + $total_equity | dollars)"
 else "  WARNING: OFF by \(($total_assets - $total_liabs - $total_equity) | fabs | dollars)!"
 end),
"",

# ══════════════════════════════════════════════════════════
#  7. @csv -- Export balance sheet as CSV
# ══════════════════════════════════════════════════════════
#
# @csv formats an array as a CSV row -- each element becomes
# a column, strings get quoted, commas separate them.
# This is how you export jq output straight to Excel!
#
# ltrimstr / rtrimstr strip prefixes and suffixes from strings.
# We use rtrimstr to clean up trailing spaces from padded names.

"==================================================",
"  BALANCE SHEET (CSV FORMAT)",
"  Copy this into a .csv file and open in Excel!",
"==================================================",

# CSV header row
(["Account Code", "Account Name", "Type", "Balance"] | @csv),

# CSV data rows -- use walk to trim whitespace from names
(
  $bs_accounts[] |
  [.code, (.name | rtrimstr(" ")), (.type | ascii_upcase), .balance] | @csv
),
"",

# ══════════════════════════════════════════════════════════
#  8. CASH FLOW STATEMENT
# ══════════════════════════════════════════════════════════
#
# The cash flow statement traces where cash came from and
# where it went.  Three sections: operating, investing,
# financing.
#
# We use endswith to categorize, and @tsv as an alternative
# to @csv for tab-separated output.

$clean.cash_flow_detail as $cf |
($cf.operating | map(.amount) | add // 0) as $op_total |
($cf.investing | map(.amount) | add // 0) as $inv_total |
($cf.financing | map(.amount) | add // 0) as $fin_total |
($op_total + $inv_total + $fin_total) as $net_change |

"==================================================",
"  STATEMENT OF CASH FLOWS",
"  \($clean.period): \($clean.start_date) to \($clean.end_date)",
"==================================================",
"",
"OPERATING ACTIVITIES",
($cf.operating[] | select(.amount != 0) |
  "  \(.description | pad(28)) \(.amount | dollars | lpad(10))"),
"                               ----------",
"  Net Operating Cash           \($op_total | dollars | lpad(10))",
"",
"INVESTING ACTIVITIES",
($cf.investing[] |
  "  \(.description | pad(28)) \(.amount | dollars | lpad(10))"),
"                               ----------",
"  Net Investing Cash           \($inv_total | dollars | lpad(10))",
"",
"FINANCING ACTIVITIES",
($cf.financing[] |
  "  \(.description | pad(28)) \(.amount | dollars | lpad(10))"),
"                               ----------",
"  Net Financing Cash           \($fin_total | dollars | lpad(10))",
"",
"==================================================",
"  NET CHANGE IN CASH           \($net_change | dollars | lpad(10))",
"  Beginning Cash               \(0 | dollars | lpad(10))",
"  Ending Cash                  \($net_change | dollars | lpad(10))",
"==================================================",
"",
(if $net_change == $clean.account_balances["1000"]
 then "  Cash reconciles! Ending cash \($net_change | dollars) matches ledger \($clean.account_balances["1000"] | dollars)"
 else "  WARNING: Cash does NOT reconcile!"
 end),
"",

# ══════════════════════════════════════════════════════════
#  9. Summary -- All three statements connect
# ══════════════════════════════════════════════════════════

"==================================================",
"  HOW THE STATEMENTS CONNECT",
"==================================================",
"  Income Statement:  Net Income = \($net_income | dollars)",
"  Balance Sheet:     Retained Earnings = \($clean.account_balances["3100"] | dollars)  (= Net Income after closing)",
"  Cash Flow:         Net Cash Change = \($net_change | dollars)  (= Ending Cash balance)",
"",
"  Net Income flows into Retained Earnings on the Balance Sheet.",
"  The Cash Flow Statement explains how Cash on the Balance Sheet changed.",
"  All three statements are generated from the same ledger.",
"",

# ══════════════════════════════════════════════════════════
#  10. JOIN demo -- Account Summary Report
# ══════════════════════════════════════════════════════════
#
# This report uses $joined_balances produced by JOIN in
# section 1b.  JOIN paired each balance entry with its
# chart_of_accounts metadata so we have names and types
# without manual lookup.

"==================================================",
"  ACCOUNT SUMMARY (via JOIN)",
"==================================================",
($joined_balances[] |
  "  \(.code)  \(.name | pad(28)) \(.type | pad(10)) \(.balance | dollars | lpad(10))")
