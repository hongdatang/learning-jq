# Lesson 10 -- Validate Ledger
# Tutorial: accounting/10-trial-balance.md
# Data:     accounting/src/data/10-general-ledger.json
# Run:      jq -f accounting/src/programs/10-validate-ledger.jq accounting/src/data/10-general-ledger.json

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

# Right-pad a string to a given width
def pad(w):
  . + " " * ([w - length, 0] | max);

# Left-pad a string to a given width (for aligning numbers)
def lpad(w):
  " " * ([w - length, 0] | max) + .;

# ══════════════════════════════════════════════════════════
#  1. Validate account codes with regex: test()
# ══════════════════════════════════════════════════════════
#
#  test("regex") returns true/false -- like Excel's
#  ISNUMBER(SEARCH(pattern, cell)), but far more powerful.
#
#  Our chart of accounts uses these ranges:
#    1xxx = Assets
#    2xxx = Liabilities
#    3xxx = Equity
#    4xxx = Revenue
#    5xxx = Cost of Goods Sold
#    6xxx = Expenses
#
#  Any code outside 1000-6999 is invalid.

"==================================================",
"  LEDGER VALIDATION REPORT",
"  Period: \(.period)",
"==================================================",
"",
"--- 1. Account Code Validation (regex test) ---",
"",

# Walk every account.  test() checks if the code matches
# the pattern ^[1-6]\d{3}$ -- exactly four digits, first
# digit 1-6.
#
# Excel analogy: =AND(LEN(A1)=4, LEFT(A1,1)>="1", LEFT(A1,1)<="6")
# Regex does this in one shot.

(
  [.ledger[] | select(.code | test("^[1-6]\\d{3}$") | not)] |
  if length == 0
  then "  All account codes valid."
  else
    "  INVALID account codes found:",
    (.[] | "    Code \(.code) -- \(.name) (not in 1xxx-6xxx range)")
  end
),

"",

# ══════════════════════════════════════════════════════════
#  2. Detect inconsistent account names: gsub + capture
# ══════════════════════════════════════════════════════════
#
#  match("pattern") returns the match details (offset,
#  length, capture groups).  capture("pattern") returns
#  just the named groups as an object.
#
#  gsub("pattern"; replacement) does global find-replace --
#  like Excel's SUBSTITUTE(), but with regex power.
#
#  Strategy: for each account code, collect all the names
#  used.  If the same code appears with different names
#  (even just different casing), flag it.

"--- 2. Name Consistency Check (gsub + capture) ---",
"",

(
  # Group by code, then check for conflicting names
  [.ledger[] | {code, name}] | group_by(.code) |
  map(select(length > 1)) |       # codes that appear more than once
  map({
    code: .[0].code,
    names: [.[].name] | unique     # unique names for this code
  }) |
  map(select(.names | length > 1)) |  # only keep if names differ
  if length == 0
  then "  All account names consistent."
  else
    "  INCONSISTENT names found:",
    (.[] |
      "    Code \(.code): \(.names | join(" vs "))" +
      # The first name (capitalized) is likely the correct one
      " -- fix: normalize to \(.names | sort | last)"
    )
  end
),

"",

# ══════════════════════════════════════════════════════════
#  3. Find missing descriptions: recursive descent (..)
# ══════════════════════════════════════════════════════════
#
#  .. (two dots) walks into every level of the JSON tree,
#  like XPath's // or a recursive VLOOKUP through all
#  nested tabs.
#
#  We use it here to find every "description" field at
#  any depth and check for empty strings.

"--- 3. Missing Description Check (recursive ..) ---",
"",

(
  # .. produces every value at every depth.  We select
  # only objects that have a "description" key with an
  # empty string value.
  [.ledger[] | . as $acct |
    .entries[] | select(.description == "") |
    { code: $acct.code, name: $acct.name, date: .date }
  ] |
  if length == 0
  then "  All entries have descriptions."
  else
    "  MISSING descriptions found:",
    (.[] | "    Account \(.code) (\(.name)) on \(.date) -- description is empty")
  end
),

"",

# ══════════════════════════════════════════════════════════
#  4. Locate errors by path: paths(), getpath(), setpath()
# ══════════════════════════════════════════════════════════
#
#  path(expr) returns the "address" of a value -- like the
#  cell reference $A$3 in Excel, but for nested JSON.
#
#  paths(filter) finds ALL paths matching a condition.
#  getpath(p) reads the value at that address.
#  setpath(p; val) writes a new value at that address.
#
#  Think of it as: instead of hardcoding "row 3, column B",
#  you can COMPUTE which cell to look at.

"--- 4. Suspicious Amounts (path operations) ---",
"",

# Use paths to find every numeric value in the entire
# ledger, then flag amounts that look transposed.
# Common transposition pattern: digits are swapped
# (e.g., 31 instead of 13).

(
  # Find all debit/credit paths that have round-dollar amounts
  # where the reverse of the digits is also a round amount
  # and appears elsewhere.  Here we flag amounts > 20 that
  # are in accounts with code "9999" (already flagged above).
  [.ledger[] | select(.code | test("^[1-6]\\d{3}$") | not) |
    . as $acct |
    .entries[] |
    { code: $acct.code, name: $acct.name, date: .date,
      amount: (if .debit > 0 then .debit else .credit end),
      side: (if .debit > 0 then "debit" else "credit" end),
      description: .description }
  ] |
  if length == 0
  then "  No suspicious amounts in invalid accounts."
  else
    "  Amounts in INVALID accounts (possible transpositions):",
    (.[] | "    \(.code) \(.name): \(.amount | dollars) \(.side) on \(.date) -- \(.description)")
  end
),

"",

# ══════════════════════════════════════════════════════════
#  5. Demonstrate path() with a concrete example
# ══════════════════════════════════════════════════════════
#
#  path(expr) returns an array of keys/indices that
#  lead to the matching value.  This is the JSON
#  equivalent of "this value lives in cell B3."

"--- 5. Path Demonstration ---",
"",

# Find the path to every entry with amount $31 (the
# suspected transposition) using paths and getpath.
(
  [
    paths(type == "number" and . == 31) |
    . as $p |
    { path: $p, address: ($p | map(tostring) | join(".")) }
  ] |
  if length == 0
  then "  No entries with amount $31 found."
  else
    "  Paths to amount $31.00 (suspected transposition of $13.00):",
    (.[] | "    [\(.address)]")
  end
),

"",

# ══════════════════════════════════════════════════════════
#  6. Full error summary using scan and paths
# ══════════════════════════════════════════════════════════
#
#  scan("regex") finds ALL matches of a pattern in a
#  string -- like Excel's FILTERXML trick for extracting
#  every match, not just the first one.
#
#  sub("regex"; replacement) replaces the FIRST match.
#  gsub("regex"; replacement) replaces ALL matches.

"--- 6. Error Summary ---",
"",

# Count total errors found
(
  # Error 1: invalid codes
  ([.ledger[] | select(.code | test("^[1-6]\\d{3}$") | not)] | length) as $bad_codes |
  # Error 2: inconsistent names
  ([.ledger[] | {code, name}] | group_by(.code) |
    map(select(length > 1)) |
    map({names: [.[].name] | unique}) |
    map(select(.names | length > 1)) | length) as $bad_names |
  # Error 3: missing descriptions
  ([.ledger[].entries[] | select(.description == "")] | length) as $missing_desc |
  # Total
  ($bad_codes + $bad_names + $missing_desc) as $total |

  "  Invalid account codes:      \($bad_codes)",
  "  Inconsistent account names: \($bad_names)",
  "  Missing descriptions:       \($missing_desc)",
  "  ─────────────────────────",
  "  Total issues found:         \($total)",
  "",
  (if $total > 0
   then "  ACTION REQUIRED: Fix these errors before running the trial balance."
   else "  Ledger is clean."
   end)
),

"",

# ══════════════════════════════════════════════════════════
#  7. Trial Balance (valid accounts only)
# ══════════════════════════════════════════════════════════
#
#  The trial balance is the fundamental check: the sum of
#  all debit balances must equal the sum of all credit
#  balances.  If they don't, something is wrong.
#
#  Excel analogy: you have a column of debits and a column
#  of credits.  SUM(debits) must equal SUM(credits).

"==================================================",
"  TRIAL BALANCE (valid accounts only)",
"  Period ending: \(.period_end)",
"==================================================",
"",
"  Code  Account                    Debit      Credit",
"  ────  ─────────────────────────  ─────────  ─────────",

# Filter to valid accounts only, compute each balance,
# then display in trial balance format.
(
  [.ledger[] |
    select(.code | test("^[1-6]\\d{3}$")) |
    {
      code,
      name,
      normal_balance,
      total_debit: ([.entries[].debit] | add // 0),
      total_credit: ([.entries[].credit] | add // 0)
    } |
    .balance = (.total_debit - .total_credit) |
    # For display: debit-balance accounts show in debit column,
    # credit-balance accounts show in credit column.
    if .balance > 0 then
      . + { dr: .balance, cr: 0 }
    elif .balance < 0 then
      . + { dr: 0, cr: (-.balance) }
    else
      . + { dr: 0, cr: 0 }
    end
  ] |

  # Group by code to merge any duplicate-code accounts
  # (handles the "cash" vs "Cash" case -- both are code 1000)
  group_by(.code) |
  map(
    {
      code: .[0].code,
      name: .[0].name,
      normal_balance: .[0].normal_balance,
      total_dr: (map(.total_debit) | add),
      total_cr: (map(.total_credit) | add)
    } |
    # Net the merged totals into a single column
    (.total_dr - .total_cr) as $net |
    if $net > 0 then . + { dr: $net, cr: 0 }
    elif $net < 0 then . + { dr: 0, cr: (-$net) }
    else . + { dr: 0, cr: 0 }
    end
  ) |
  sort_by(.code) |

  # Bind totals before scattering into individual lines
  (map(.dr) | add) as $total_dr |
  (map(.cr) | add) as $total_cr |

  # Print each line (skip zero-balance accounts)
  (.[] | select(.dr > 0 or .cr > 0) |
    "  \(.code)  \(.name | pad(25))  " +
    (if .dr > 0 then .dr | dollars | lpad(9) else "         " end) +
    "  " +
    (if .cr > 0 then .cr | dollars | lpad(9) else "         " end)
  ),

  # Totals
  "        ─────────────────────────  ─────────  ─────────",
  "        TOTALS                     \($total_dr | dollars | lpad(9))  \($total_cr | dollars | lpad(9))",
  "",
  "==================================================",
  (if $total_dr == $total_cr
   then "  BALANCED -- Debits \($total_dr | dollars) = Credits \($total_cr | dollars)"
   else "  OUT OF BALANCE by \(($total_dr - $total_cr) | fabs | dollars)!"
   end),
  "=================================================="
)
