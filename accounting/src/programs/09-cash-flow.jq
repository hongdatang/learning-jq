# Lesson 09 -- Cash Flow Statement
# Tutorial: accounting/09-cash-flow-statement.md
# Data:     accounting/src/data/09-cash-movements.json
# Run:      jq -f accounting/src/programs/09-cash-flow.jq accounting/src/data/09-cash-movements.json

# ══════════════════════════════════════════════════════════
#  Functions
# ══════════════════════════════════════════════════════════

# Format a number as a dollar amount: 6 -> "$6.00", -3 -> "-$3.00"
def dollars:
  (if . < 0 then "-$" else "$" end) as $sign |
  ((. | fabs) * 100 | round / 100 | tostring | split(".")
    | if length == 1 then .[0] + ".00"
      elif (.[1] | length) == 1 then join(".") + "0"
      else join(".")
      end) |
  $sign + .;

# Pad a string to a given width (right-padded with spaces)
def pad(width):
  . + (" " * (width - length));

# ══════════════════════════════════════════════════════════
#  1. group_by + map pipeline -- subtotals per section
#     Excel: a pivot table grouping by Section column
# ══════════════════════════════════════════════════════════

. as $data |

# Group movements by section and compute subtotals
(.movements | group_by(.section) | map({
  section: .[0].section,
  items: .,
  subtotal: (map(.amount) | add)
})) as $sections |

# Pull out each section by name
([$sections[] | select(.section == "operating")][0]  // {section:"operating", items:[], subtotal:0}) as $operating |
([$sections[] | select(.section == "investing")][0]  // {section:"investing", items:[], subtotal:0}) as $investing |
([$sections[] | select(.section == "financing")][0]  // {section:"financing", items:[], subtotal:0}) as $financing |

# ══════════════════════════════════════════════════════════
#  2. reduce with complex state (object accumulator)
#     Excel: a helper row that tracks multiple running totals
# ══════════════════════════════════════════════════════════

# Build a summary object in one pass through all movements.
# The accumulator tracks: inflows, outflows, and count per section.
(reduce .movements[] as $m (
  { operating: {in: 0, out: 0, n: 0},
    investing: {in: 0, out: 0, n: 0},
    financing: {in: 0, out: 0, n: 0} };
  .[$m.section].n += 1 |
  if $m.amount >= 0
  then .[$m.section].in += $m.amount
  else .[$m.section].out += $m.amount
  end
)) as $stats |

# ══════════════════════════════════════════════════════════
#  3. foreach -- running cash balance after each movement
#     Excel: column C where C1 = beginning_cash + A1,
#            C2 = C1 + A2, C3 = C2 + A3, ...
# ══════════════════════════════════════════════════════════

# foreach produces one output per step (unlike reduce, which
# produces only the final result).  We collect them into an array.
([foreach .movements[] as $m (
  $data.beginning_cash;        # INIT: start at beginning cash
  . + $m.amount;               # UPDATE: add each movement
  { id: $m.id,                 # EXTRACT: output after each step
    date: $m.date,
    description: $m.description,
    amount: $m.amount,
    running_balance: . }
)]) as $running |

# ══════════════════════════════════════════════════════════
#  4. Date functions -- group movements by week
#     Excel: =WEEKNUM(A1), =TEXT(A1,"yyyy-mm-dd")
# ══════════════════════════════════════════════════════════

# Parse date strings into week numbers using strptime + gmtime.
# strptime parses "2024-06-01" into a time array.
# The week number is element [7] (day-of-year) divided by 7.
([.movements[] | {
  week: ((.date | strptime("%Y-%m-%d") | .[7]) / 7 | floor + 1),
  amount: .amount,
  section: .section
}] | group_by(.week) | map({
  week: .[0].week,
  total: (map(.amount) | add),
  count: length
})) as $by_week |

# ══════════════════════════════════════════════════════════
#  5. index / indices / rindex -- find specific transactions
#     Excel: =MATCH("Insurance", A:A, 0)
# ══════════════════════════════════════════════════════════

# Find where the equipment purchase is in the movements array
(.movements | map(.description) | index("Equipment purchase - cooler")) as $equip_pos |

# Find all supply purchases (positions where description contains "Buy")
([.movements | to_entries[] | select(.value.description | test("^Buy")) | .key]) as $supply_positions |

# Find the last sale in the list using rindex-style logic
(.movements | map(.description | test("^Sales")) | [to_entries[] | select(.value == true) | .key] | last) as $last_sale_pos |

# ══════════════════════════════════════════════════════════
#  6. until -- "how many months to pay off the loan?"
#     Excel: Goal Seek or filling cells down until balance = 0
# ══════════════════════════════════════════════════════════

# If we save $10/month, how many months until the $50 loan is paid off?
# until(cond; update) runs update repeatedly until cond is true.
# State is {balance, months}. Each step subtracts $10.
(
  { balance: 50, months: 0 }
  | until(.balance <= 0; .balance -= 10 | .months += 1)
  | .months
) as $months_to_payoff |

# ══════════════════════════════════════════════════════════
#  7. while -- project monthly cash if we earn $2/month net
#     Excel: filling cells down WHILE condition holds
# ══════════════════════════════════════════════════════════

# while(cond; update) produces outputs as long as cond is true.
# Project ending cash balances month by month while cash < $100.
([
  62                                       # starting cash (end of June)
  | while(. < 100; . + 2)                 # add $2 net per month
]) as $monthly_projections |

# ══════════════════════════════════════════════════════════
#  8. recurse -- compound interest on the loan balance
#     Excel: a recursive formula like =A1*1.04 copied down
# ══════════════════════════════════════════════════════════

# What does $50 grow to at 4% monthly interest if you never pay?
# recurse(f; cond) applies f repeatedly while cond holds.
# We stop when the balance exceeds $75 (50% more than principal).
([
  50 | recurse(. * 1.04; . < 75)
] | map(. * 100 | round / 100)) as $compound |

# ══════════════════════════════════════════════════════════
#  9. Date formatting demos
#     Excel: =TEXT(A1, "mmmm d, yyyy"), =TODAY()
# ══════════════════════════════════════════════════════════

# now returns the current Unix timestamp.
# todate converts it to ISO 8601 format.
# We demonstrate the date pipeline on our data's dates.

# Parse a date and reformat it: "2024-06-01" -> "Saturday, June 01"
(
  "2024-06-01"
  | strptime("%Y-%m-%d")
  | mktime
  | strftime("Started: %A, %B %d, %Y")
) as $formatted_start |

# Convert first movement date to ISO 8601 and back
(
  "2024-06-01"
  | strptime("%Y-%m-%d")
  | mktime
  | todateiso8601
) as $iso_date |

# Show date components using gmtime
(
  "2024-06-01"
  | strptime("%Y-%m-%d")
  | mktime
  | gmtime
  | { year: .[0], month: (.[1] + 1), day: .[2],
      hour: .[3], minute: .[4], day_of_year: .[7] }
) as $date_parts |

# ══════════════════════════════════════════════════════════
#  Format the Cash Flow Statement
# ══════════════════════════════════════════════════════════

"==================================================",
"  CASH FLOW STATEMENT",
"  \($data.period)",
"==================================================",
"",

# --- Operating Activities ---
"  OPERATING ACTIVITIES",
"  ------------------------------------------------",
($operating.items[] |
  "    \(.description | pad(35)) \(.amount | dollars)"),
"                                      ----------",
"    Net Cash from Operations:       \($operating.subtotal | dollars)",
"",

# --- Investing Activities ---
"  INVESTING ACTIVITIES",
"  ------------------------------------------------",
($investing.items[] |
  "    \(.description | pad(35)) \(.amount | dollars)"),
"                                      ----------",
"    Net Cash from Investing:        \($investing.subtotal | dollars)",
"",

# --- Financing Activities ---
"  FINANCING ACTIVITIES",
"  ------------------------------------------------",
($financing.items[] |
  "    \(.description | pad(35)) \(.amount | dollars)"),
"                                      ----------",
"    Net Cash from Financing:        \($financing.subtotal | dollars)",
"",
"==================================================",
($operating.subtotal + $investing.subtotal + $financing.subtotal) as $net_change |
"  NET CHANGE IN CASH:               \($net_change | dollars)",
"  Beginning Cash:                    \($data.beginning_cash | dollars)",
"  Ending Cash:                       \($data.beginning_cash + $net_change | dollars)",
"==================================================",

# ══════════════════════════════════════════════════════════
#  Supplemental: reduce stats (inflows vs outflows)
# ══════════════════════════════════════════════════════════
"",
"-- Section Statistics (reduce with object accumulator) --",
"  Operating: \($stats.operating.n) transactions, in=\($stats.operating.in | dollars), out=\($stats.operating.out | dollars)",
"  Investing: \($stats.investing.n) transactions, in=\($stats.investing.in | dollars), out=\($stats.investing.out | dollars)",
"  Financing: \($stats.financing.n) transactions, in=\($stats.financing.in | dollars), out=\($stats.financing.out | dollars)",

# ══════════════════════════════════════════════════════════
#  Supplemental: running balance (foreach)
# ══════════════════════════════════════════════════════════
"",
"-- Running Cash Balance (foreach) --",
($running[] |
  "  #\(.id | tostring | pad(3)) \(.date)  \(.amount | dollars | pad(10))  balance: \(.running_balance | dollars)"),

# ══════════════════════════════════════════════════════════
#  Supplemental: weekly summary (date functions)
# ══════════════════════════════════════════════════════════
"",
"-- Weekly Cash Summary (date functions + group_by) --",
($by_week[] |
  "  Week \(.week): \(.count) transactions, net \(.total | dollars)"),

# ══════════════════════════════════════════════════════════
#  Supplemental: transaction search (index/indices)
# ══════════════════════════════════════════════════════════
"",
"-- Transaction Lookup (index/indices) --",
"  Equipment purchase at position: \($equip_pos)",
"  Supply purchases at positions:  \($supply_positions)",
"  Last sale at position:          \($last_sale_pos)",

# ══════════════════════════════════════════════════════════
#  Supplemental: projections (until/while/recurse)
# ══════════════════════════════════════════════════════════
"",
"-- Loan Payoff (until) --",
"  Saving $10/month: loan paid off in \($months_to_payoff) months",
"",
"-- Monthly Cash Projection (while) --",
"  Earning $2/month net, cash stays under $100 for these balances:",
"  \($monthly_projections)",
"",
"-- Compound Interest Warning (recurse) --",
"  $50 at 4% monthly if you never pay:",
"  \($compound)",
"",
"-- Date Formatting --",
"  \($formatted_start)",
"  ISO 8601:    \($iso_date)",
"  Components:  \($date_parts)",

# ══════════════════════════════════════════════════════════
#  Key insight: profit != cash
# ══════════════════════════════════════════════════════════
"",
"==================================================",
"  WHY PROFIT != CASH",
"==================================================",
"  Retained earnings (after adjustments): $6.00",
"  Ending cash:                           $62.00",
"  Difference:                            $56.00",
"",
"  The gap is explained by non-income cash:",
"    Owner investment (financing):    $50.00",
"    Bank loan (financing):           $50.00",
"    Equipment purchase (investing): -$40.00",
"    Depreciation (non-cash expense): -$4.00",
"                                     ------",
"    Total non-income items:          $56.00",
"  ",
"  Profit shows what you EARNED.",
"  Cash flow shows what you CAN SPEND."
