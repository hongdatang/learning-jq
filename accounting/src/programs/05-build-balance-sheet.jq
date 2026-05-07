# Lesson 05 -- Build Balance Sheet
# Tutorial: accounting/05-the-balance-sheet.md
# Data:     accounting/src/data/05-balance-sheet-week1.json
# Run:      jq -rf accounting/src/programs/05-build-balance-sheet.jq accounting/src/data/05-balance-sheet-week1.json

# ── 1. Save the original input ─────────────────────────────
# as $var names a result so you can reuse it later -- like naming
# a cell in Excel ($A$1) so you can refer to it in many formulas.

. as $input |

# ── 2. Classify accounts by type using reduce ──────────────
# reduce loops through each account and sorts it into the right
# bucket. Think of it like going through a stack of receipts and
# dropping each one into the right folder: asset, liability, equity.

.accounts
| to_entries
| reduce .[] as $acct (
    { "asset": {}, "liability": {}, "equity": {} };
    .[$acct.value.type] += { ($acct.key): $acct.value.balance }
  )
| . as $classified |

# ── 3. Compute totals with as $var ─────────────────────────
# Each "as $var" binds a computed value to a name.
# It is exactly like SUM(B2:B5) saved into a named cell.

($classified.asset      | values | add // 0) as $total_assets      |
($classified.liability  | values | add // 0) as $total_liabilities |
($classified.equity     | values | add // 0) as $total_equity      |

# ── 4. Verify the accounting equation ──────────────────────
# A = L + OE must always hold. We store a boolean here;
# all(f) and any(f) are shown in the tutorial text.

($total_assets == $total_liabilities + $total_equity) as $balanced |

# ── 5. Use keys and has to inspect the data ────────────────

($classified.asset  | keys) as $asset_names  |
($classified.equity | keys) as $equity_names |
($classified.asset  | has("cash")) as $has_cash |

# ── 6. Round all balances with map_values ──────────────────
# map_values applies a function to every value in an object --
# like dragging a ROUND() formula down an entire column.

($classified | map_values(map_values(. * 100 | round / 100))) as $rounded |

# ── 7. Use // to handle missing accounts ──────────────────
# The // operator is like IFERROR() or IFNA() in Excel.
# If the left side is null or false, use the right side instead.

($classified.asset.accounts_receivable // 0) as $ar |

# ── 8. Format the balance sheet ────────────────────────────

"=========================================",
"  LEMONADE STAND -- BALANCE SHEET",
"  Week 1 -- June 5, 2024",
"=========================================",
"",
"ASSETS",
"------------------------------",
($rounded.asset | to_entries[] |
  "  \(.key | gsub("_"; " "))          $\(.value)"),
"                        ----------",
"  TOTAL ASSETS            $\($total_assets)",
"",
"LIABILITIES",
"------------------------------",
(if ($rounded.liability | length) == 0
 then "  (none)"
 else ($rounded.liability | to_entries[] |
   "  \(.key | gsub("_"; " "))          $\(.value)")
 end),
"                        ----------",
"  TOTAL LIABILITIES       $\($total_liabilities)",
"",
"OWNER'S EQUITY",
"------------------------------",
($rounded.equity | to_entries[] |
  "  \(.key | gsub("_"; " "))   $\(.value)"),
"                        ----------",
"  TOTAL EQUITY            $\($total_equity)",
"",
"=========================================",
"  TOTAL L + OE            $\($total_liabilities + $total_equity)",
"=========================================",
"",
(if $balanced
 then "The books balance! A ($\($total_assets)) = L + OE ($\($total_liabilities + $total_equity))"
 else "WARNING: Books do NOT balance! A=$\($total_assets), L+OE=$\($total_liabilities + $total_equity)"
 end),
"",
"-- Income Summary (Week 1) --",
"  Revenue:       $\($input.income_summary.revenue)",
"  COGS:         -$\($input.income_summary.cogs)",
"  Wages:        -$\($input.income_summary.wages)",
"  Advertising:  -$\($input.income_summary.advertising)",
"                 ------",
"  Net Income:    $\($input.income_summary.net_income)",
"",
"-- Data Inspection --",
"  Asset accounts:  \($asset_names | join(", "))",
"  Equity accounts: \($equity_names | join(", "))",
"  Has cash?        \($has_cash)",
"  A/R balance:     $\($ar) (used // to default missing account to 0)"
