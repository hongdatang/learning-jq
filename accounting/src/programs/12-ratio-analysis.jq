# Lesson 12 -- Ratio Analysis
# Tutorial: accounting/12-year-in-review.md
# Data:     accounting/src/data/12-multi-period.json
# Run:      jq -L accounting/src/lib -f accounting/src/programs/12-ratio-analysis.jq accounting/src/data/12-multi-period.json

# ══════════════════════════════════════════════════════════
#  Shared helpers (dollars, pct, pad, lpad) from library
# ══════════════════════════════════════════════════════════
include "accounting";

# ══════════════════════════════════════════════════════════
#  1. Monthly Income Statement Comparison
# ══════════════════════════════════════════════════════════

"══════════════════════════════════════════════════════════",
"  SUMMER 2024 -- YEAR IN REVIEW",
"  \(.business) -- Comparative Financial Statements",
"══════════════════════════════════════════════════════════",
"",

# ── Extract short month labels ───────────────────────────
# .period is "June 2024" -- grab just the month name.

(.months | map(.period | split(" ")[0])) as $labels |

"--- Comparative Income Statement ---",
"",
"  Line Item            \($labels[0] | pad(10)) \($labels[1] | pad(10)) \($labels[2] | pad(10))",
"  ────────────────     ──────────   ──────────   ──────────",

# ── Build rows using map + transpose ─────────────────────
# transpose flips rows into columns (and vice versa).
#
# Think of it this way: you have three columns of numbers
# (June, July, August). Each column is a monthly report.
# transpose turns those columns into rows -- one row per
# line item, with three values across. This is exactly
# what "side-by-side comparison" means in a spreadsheet.

# First, build an array of arrays -- one per month
(.months | map(.income_statement | [
  .revenue, .cogs, .gross_profit,
  .total_expenses, .net_income
])) as $cols |

# transpose turns [[jun_rev, jun_cogs, ...], [jul_rev, ...], ...]
# into [[jun_rev, jul_rev, aug_rev], [jun_cogs, jul_cogs, ...], ...]
($cols | transpose) as $rows |

# Label each row
(["Revenue", "COGS", "Gross Profit", "Total Expenses", "Net Income"]) as $row_labels |

# Print each row
($rows | to_entries[] |
  .key as $i | .value as $vals |
  "  \($row_labels[$i] | pad(22))" +
  ($vals | map(dollars | lpad(10)) | join("   "))
),

"",

# ══════════════════════════════════════════════════════════
#  2. Ratio Analysis with debug
# ══════════════════════════════════════════════════════════
#
# debug prints a value to stderr without affecting the
# pipeline. It is like Debug.Print in VBA or printing to
# the Immediate Window -- the output goes to the side
# channel, not into your actual results.
#
# Usage: .revenue | debug | ...
#   prints the value to stderr, passes it through unchanged.
#
# You will see debug output in the terminal prefixed with
# ["DEBUG:"] -- it helps you inspect values mid-pipeline
# without breaking the flow.

"--- Financial Ratios by Month ---",
"",
"  Ratio                \($labels[0] | pad(10)) \($labels[1] | pad(10)) \($labels[2] | pad(10))",
"  ────────────────     ──────────   ──────────   ──────────",

# Compute ratios for each month
(.months | map(
  .income_statement as $is |
  .balance_sheet as $bs |
  {
    gross_margin:   ($is.gross_profit / $is.revenue),
    net_margin:     ($is.net_income / $is.revenue),
    expense_ratio:  ($is.total_expenses / $is.revenue),
    current_ratio:  (if $bs.total_liabilities > 0
                     then $bs.total_assets / $bs.total_liabilities
                     else null end),
    debt_to_equity: (if $bs.total_equity > 0
                     then $bs.total_liabilities / $bs.total_equity
                     else null end),
    roe:            (if $bs.total_equity > 0
                     then $is.net_income / $bs.total_equity
                     else null end)
  }
)) as $ratios |

# Gross Margin row
"  \("Gross Margin" | pad(22))" +
  ([$ratios[] | .gross_margin | pct | lpad(10)] | join("   ")),

# Net Margin row
"  \("Net Margin" | pad(22))" +
  ([$ratios[] | .net_margin | pct | lpad(10)] | join("   ")),

# Expense Ratio row
"  \("Expense Ratio" | pad(22))" +
  ([$ratios[] | .expense_ratio | pct | lpad(10)] | join("   ")),

# Current Ratio row (null means no liabilities)
"  \("Current Ratio" | pad(22))" +
  ([$ratios[] | .current_ratio |
    if . == null then "N/A"
    else . * 100 | round / 100 | tostring + "x"
    end | lpad(10)] | join("   ")),

# Debt-to-Equity row
"  \("Debt-to-Equity" | pad(22))" +
  ([$ratios[] | .debt_to_equity |
    if . == null then "N/A"
    else . * 100 | round / 100 | tostring + "x"
    end | lpad(10)] | join("   ")),

# ROE (Return on Equity) row
"  \("ROE" | pad(22))" +
  ([$ratios[] | .roe |
    if . == null then "N/A"
    else pct
    end | lpad(10)] | join("   ")),

"",

# ══════════════════════════════════════════════════════════
#  3. Trend Analysis -- month-over-month growth
# ══════════════════════════════════════════════════════════
#
# To compute month-over-month change, we compare adjacent
# pairs. We already know how to use indices for this.

"--- Month-over-Month Revenue Growth ---",
"",

(.months | map(.income_statement.revenue)) as $revs |

"  June to July:    \($revs[0] | dollars) -> \($revs[1] | dollars)  " +
  "(+\(($revs[1] - $revs[0]) | dollars), " +
  "\((($revs[1] - $revs[0]) / $revs[0]) | pct) growth)",

"  July to August:  \($revs[1] | dollars) -> \($revs[2] | dollars)  " +
  "(+\(($revs[2] - $revs[1]) | dollars), " +
  "\((($revs[2] - $revs[1]) / $revs[1]) | pct) growth)",

"  Summer total:    \($revs | add | dollars) across 3 months",
"",

# ══════════════════════════════════════════════════════════
#  4. @json -- compact data for export
# ══════════════════════════════════════════════════════════
#
# Format strings transform data for different uses:
#   @json   -- compact JSON string (like Save As CSV but for JSON)
#   @base64 -- encode for safe transport (email attachments, URLs)
#   @uri    -- encode for web addresses (spaces become %20)
#
# Think of these as "Save As..." for different formats.

"--- Export Formats (@json, @base64, @uri) ---",
"",

# Build a summary object and show it in different formats
(
  .months | map({
    month:        (.period | split(" ")[0]),
    revenue:      .income_statement.revenue,
    net_income:   .income_statement.net_income,
    gross_margin: (.income_statement.gross_profit / .income_statement.revenue
                   | . * 1000 | round / 10)
  })
) as $summary |

"  @json (compact, machine-readable):",
"  \($summary | @json)",
"",
"  @base64 (encoded for safe transport):",
"  \($summary | @json | @base64)",
"",
"  @uri (encoded for web URLs):",
"  data=\($summary | @json | @uri)",
"",

# ══════════════════════════════════════════════════════════
#  5. $ENV -- reading environment variables
# ══════════════════════════════════════════════════════════
#
# $ENV is a built-in object containing all environment
# variables, like reading Windows system variables.
#
# $ENV.USER gives the current username.
# $ENV.HOME gives the home directory.
#
# This is useful for dynamic reports -- embedding who ran
# the report and when.

"--- Report Metadata ($ENV) ---",
"",
"  Generated by: \($ENV.USER // "unknown")",
"  Home dir:     \($ENV.HOME // "unknown")",
"",

# ══════════════════════════════════════════════════════════
#  6. Balance Sheet Comparison
# ══════════════════════════════════════════════════════════

"--- Comparative Balance Sheet ---",
"",
"  Category             \($labels[0] | pad(10)) \($labels[1] | pad(10)) \($labels[2] | pad(10))",
"  ────────────────     ──────────   ──────────   ──────────",

(.months | map(.balance_sheet | [
  .total_assets, .total_liabilities, .total_equity
]) | transpose) as $bs_rows |

(["Total Assets", "Total Liabilities", "Total Equity"]) as $bs_labels |

($bs_rows | to_entries[] |
  .key as $i | .value as $vals |
  "  \($bs_labels[$i] | pad(22))" +
  ($vals | map(dollars | lpad(10)) | join("   "))
),

"",

# ══════════════════════════════════════════════════════════
#  7. Summer Summary -- closing the books
# ══════════════════════════════════════════════════════════

"══════════════════════════════════════════════════════════",
"  SUMMER 2024 SUMMARY",
"══════════════════════════════════════════════════════════",
"",

(.months | map(.income_statement)) as $statements |

($statements | map(.revenue) | add) as $total_rev |
($statements | map(.cogs) | add) as $total_cogs |
($statements | map(.net_income) | add) as $total_ni |
(.months | last | .balance_sheet) as $final_bs |

"  Total Revenue (3 months):    \($total_rev | dollars)",
"  Total COGS:                  \($total_cogs | dollars)",
"  Total Net Income:            \($total_ni | dollars)",
"  Overall Net Margin:          \(($total_ni / $total_rev) | pct)",
"",
"  Starting Assets (June):      \(.months[0].balance_sheet.total_assets | dollars)",
"  Ending Assets (August):      \($final_bs.total_assets | dollars)",
"  Asset Growth:                \(($final_bs.total_assets - .months[0].balance_sheet.total_assets) | dollars)",
"",
"  Starting Debt:               \(.months[0].balance_sheet.total_liabilities | dollars)",
"  Ending Debt:                 \($final_bs.total_liabilities | dollars)",
"  Status:                      \(if $final_bs.total_liabilities == 0 then "DEBT FREE!" else "Debt remaining" end)",
"",
"══════════════════════════════════════════════════════════",
"  The books are closed. Great summer!",
"══════════════════════════════════════════════════════════"
