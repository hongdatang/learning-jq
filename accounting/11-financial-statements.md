# Lesson 11 -- The Full Picture: Financial Statements

> **Prerequisites**: You have read Lessons
> [01](01-opening-day.md) through [10](10-trial-balance.md).
> You know pipes, `map`, `select`, `reduce`, `group_by`, functions,
> regular expressions, path operations, and update assignments.

## The Story So Far

It is June 30th.  The lemonade stand has been running for a full month.
Thirty-two journal entries sit in one JSON file -- purchases, sales,
wages, a bank loan, adjusting entries, and closing entries.

Your mom says, "Time for the monthly close.  We need three reports for
the bank and for your aunt."

Those three reports are the **financial statements**:

1. **Income Statement** -- did the business make money?
2. **Balance Sheet** -- what does the business own and owe right now?
3. **Statement of Cash Flows** -- where did the cash go?

You will generate all three from a single ledger file, learning jq's
most powerful lookup and formatting tools along the way.

---

## Setup

All commands run from the **project root**.  The data file is at
`accounting/src/data/11-full-month.json`.

```bash
jq 'keys' accounting/src/data/11-full-month.json
```

The file contains:

- `.chart_of_accounts` -- all 20 accounts with codes, names, and types
- `.transactions` -- 32 journal entries for the full month
- `.pre_closing_balances` -- balances *before* closing (revenue and
  expense accounts still have balances)
- `.account_balances` -- final post-closing balances (temporary accounts
  zeroed, net income moved to Retained Earnings)
- `.cash_flow_detail` -- operating, investing, and financing cash flows

This is the "single source of truth" -- one file, three statements.

---

## 1. INDEX -- Your Chart of Accounts Lookup Table

**Excel analogy**: `=VLOOKUP(A2, ChartOfAccounts, 2, FALSE)` -- look up
a name by code from a reference sheet.

`INDEX` builds a dictionary keyed by a field you choose:

```bash
jq 'INDEX(.chart_of_accounts[]; .code) | .["1000"].name' \
  accounting/src/data/11-full-month.json
# "Cash"

jq 'INDEX(.chart_of_accounts[]; .code) | .["6300"].name' \
  accounting/src/data/11-full-month.json
# "Depreciation Expense"
```

`INDEX(stream; key_expr)` iterates `stream`, evaluates `key_expr` on
each element, and stores it under that key.  Equivalent to
`reduce (stream) as $x ({}; . + { ($x | key_expr): $x })`.

| Excel                                | jq                               |
|--------------------------------------|----------------------------------|
| `=VLOOKUP("1000", chart, 2, FALSE)` | `$lookup["1000"].name`           |
| Create a named range from a table    | `INDEX(stream; .key) as $lookup` |

---

## 2. IN -- Membership Testing

**Excel analogy**: `=COUNTIF(range, A1) > 0` -- does this value exist
in the list?

`IN(stream)` returns `true` if the current value appears in the stream:

```bash
jq '.account_balances as $bal |
  [.chart_of_accounts[] | select(.code | IN($bal | keys[]))]
  | map(.name)' accounting/src/data/11-full-month.json
```

Note: you must save `.account_balances` with `as $bal` before entering
`select`, because `.` changes inside the filter.

---

## 3. JOIN -- Combine Two Tables by Key

**Excel analogy**: `=VLOOKUP` to pull columns from a second table into the
first -- like joining a Sales sheet to a Products sheet on product ID.

`INDEX` builds a lookup table.  `JOIN` takes that a step further: it
matches every element of a stream against a lookup table and pairs them.

```
JOIN(INDEX(table2; .key); stream1; .key; add)
```

Think of it as a left join in SQL or a `VLOOKUP` that runs down an entire
column at once instead of cell by cell.

```bash
# Join account_balances with chart_of_accounts to get names + balances
jq '
  INDEX(.chart_of_accounts[]; .code) as $lookup |
  [
    JOIN(
      $lookup;
      .account_balances | to_entries[];
      .key
    )
    | select(length > 0)
    | { code: .[0].key, name: .[1].name, type: .[1].type, balance: .[0].value }
    | select(.balance != 0)
  ]
' accounting/src/data/11-full-month.json
```

`JOIN(idx; stream; key_expr)` evaluates `key_expr` on each element of
`stream`, looks it up in `idx`, and emits a two-element array
`[element, match]` (or `[element, null]` if no match).

| Excel                                           | jq                                          |
|-------------------------------------------------|---------------------------------------------|
| `=VLOOKUP(A2, Products, 2, FALSE)` down a column | `JOIN($lookup; .balances[]; .code)`         |
| Join two tables on a key column                  | `JOIN(INDEX(t2; .key); t1[]; .key)`         |

---

## 4. contains / inside / startswith / endswith

**Excel analogy**: `=SEARCH("Expense", A1)` for substrings,
`=LEFT(A1,1)="1"` for prefixes.

```bash
# String containment -- names containing "Expense"
jq '[.chart_of_accounts[] | select(.name | contains("Expense"))]
  | map(.name)' accounting/src/data/11-full-month.json

# inside is the reverse of contains
jq -n '["adjusting"] | inside(["operating","adjusting","closing"])'
# true

# startswith -- all asset accounts (codes starting with "1")
jq '[.chart_of_accounts[] | select(.code | startswith("1"))]
  | map(.name)' accounting/src/data/11-full-month.json
```

Account codes follow a bookkeeping convention: 1xxx = assets,
2xxx = liabilities, 3xxx = equity, 4xxx = revenue, 5xxx-6xxx = expenses.

---

## 5. ltrimstr / rtrimstr / trim -- Cleaning Up Strings

**Excel analogy**: `=SUBSTITUTE(A1, "prefix_", "")` and `=TRIM(A1)`.

```bash
# Remove "Inventory - " prefix from inventory account names
jq '[.chart_of_accounts[] | select(.code | startswith("12"))
  | .name | ltrimstr("Inventory - ")]' accounting/src/data/11-full-month.json
# ["Lemons","Sugar","Cups"]

# Remove " Expense" suffix
jq '[.chart_of_accounts[] | select(.name | endswith("Expense"))
  | .name | rtrimstr(" Expense")]' accounting/src/data/11-full-month.json
# ["Wages","Advertising","Insurance","Depreciation","Bad Debt","Interest"]
```

Whitespace trimming (jq 1.8+):

```bash
jq -n '"  hello world  " | trim'     # "hello world"
jq -n '"  hello world  " | ltrim'    # "hello world  "
jq -n '"  hello world  " | rtrim'    # "  hello world"
```

`trimstr(s)` strips `s` from both ends at once.

---

## 6. ascii_downcase / ascii_upcase

**Excel analogy**: `=UPPER(A1)` and `=LOWER(A1)`.

```bash
jq '[.chart_of_accounts[] | .type] | unique | map(ascii_upcase)' \
  accounting/src/data/11-full-month.json
# ["ASSET","EQUITY","EXPENSE","LIABILITY","REVENUE"]
```

---

## 7. walk -- Apply a Transformation Everywhere

**Excel analogy**: A formula that applies to every cell in the entire
workbook -- every sheet, every column, every nested table.

`walk(f)` recursively visits every node in a JSON tree and applies `f`:

```bash
# Uppercase every string value
jq 'walk(if type == "string" then ascii_upcase else . end)' \
  accounting/src/data/11-full-month.json | jq '.chart_of_accounts[0]'
# {"code":"1000","name":"CASH","type":"ASSET","category":"CURRENT"}

# Round every number to integers
jq 'walk(if type == "number" then round else . end)' \
  accounting/src/data/11-full-month.json | jq '.account_balances'
```

`walk` processes bottom-up: children first, then the parent.

---

## 8. @csv and @tsv -- Exporting to Excel

**Excel analogy**: File > Save As > CSV.

`@csv` formats an array as a CSV row.  Use `-r` for clean output:

```bash
jq -rn '["Cash", "1000", "asset", 62.00] | @csv'
# "Cash","1000","asset",62
```

Build a full CSV -- header plus data:

```bash
jq -r '
  INDEX(.chart_of_accounts[]; .code) as $lookup |
  (["Code","Name","Type","Balance"] | @csv),
  (.account_balances | to_entries[] | select(.value != 0) |
    [.key, $lookup[.key].name, $lookup[.key].type, .value] | @csv)
' accounting/src/data/11-full-month.json
```

`@tsv` uses tabs instead of commas.  Redirect to save:
`jq -r '...' data.json > balance-sheet.csv`

---

## 9. input / inputs and --rawfile -- Multi-File Processing

**Excel analogy**: `=[OtherWorkbook.xlsx]Sheet1!A1` -- pulling data from
another workbook.

`input` reads the next file argument.  `inputs` reads all remaining.
Always use `-n` so jq does not auto-consume the first file:

```bash
jq -n '
  input as $chart | input as $month |
  INDEX($chart.accounts[]; .code) as $lookup |
  $month.account_balances | to_entries
  | map({ code: .key, name: $lookup[.key].name, balance: .value })
  | map(select(.balance != 0))
' accounting/src/data/chart-of-accounts.json \
  accounting/src/data/11-full-month.json
```

`--rawfile varname filename` reads a non-JSON file as a raw string --
useful for embedding templates or SQL queries.

---

## 10. The Shared Library: Reusable Functions

Stop copying `dollars` and `pad` between files.  Put shared functions in
`accounting/src/lib/accounting.jq` and use `-L` to load them:

```bash
jq -L accounting/src/lib -n 'include "accounting"; 42 | format_currency'
# "$42.00"

jq -L accounting/src/lib -n 'import "accounting" as acct; -4 | acct::format_currency'
# "-$4.00"
```

> **Excel analogy**: A shared library is like `PERSONAL.XLSB` -- your
> custom functions available in every spreadsheet.

---

## 11. Putting It All Together

```bash
jq -L accounting/src/lib -rf accounting/src/programs/11-full-statements.jq \
  accounting/src/data/11-full-month.json
```

The program chains INDEX, walk, startswith, contains, and @csv to
generate all three statements from one data file:

| Statement      | Key Figure             | Amount    |
|----------------|------------------------|-----------|
| Income         | Revenue                | $51.00    |
| Income         | COGS                   | $25.00    |
| Income         | Gross Profit           | $26.00    |
| Income         | Operating Expenses     | $20.00    |
| Income         | **Net Income**         | **$6.00** |
| Balance Sheet  | Total Assets           | $106.00   |
| Balance Sheet  | Total Liabilities      | $50.00    |
| Balance Sheet  | Total Equity           | $56.00    |
| Cash Flow      | Operating              | $2.00     |
| Cash Flow      | Investing              | -$40.00   |
| Cash Flow      | Financing              | $100.00   |
| Cash Flow      | **Net Change in Cash** | **$62.00**|

---

## Accounting Sidebar: The Accounting Cycle and Closing

You have now walked the full **accounting cycle**: identify transactions
(L01-03), record journal entries (L07), post to accounts, prepare a
trial balance (L08), record adjustments (L08), prepare financial
statements (this lesson), and close the books.

### How the Statements Connect

```
Income Statement:  Revenue $51 - COGS $25 - Expenses $20 = Net Income $6
                                                                |
Balance Sheet:     Assets $106 = Liabilities $50 + OE $50 + RE $6
                     |
                     +-- Cash $62  <-- Operating $2 + Investing -$40 + Financing $100
```

- **Net Income** ($6) flows into **Retained Earnings** via closing entries
- **Ending Cash** ($62) = Net Change in Cash on the Cash Flow Statement
- **Assets** ($106) = Liabilities + Equity ($50 + $56)

Transactions 25-32 close temporary accounts: Revenue $51 and Expenses
$45 ($25 COGS + $20 OpEx) are zeroed and the difference ($6) lands in
Retained Earnings.  Each expense account gets its own closing entry
(one per debit/credit pair), so there are 8 closing transactions total.

---

## jq Feature Summary

| Feature                     | Excel Equivalent           | What It Does                           |
|-----------------------------|----------------------------|----------------------------------------|
| `INDEX(s; k)`               | VLOOKUP / XLOOKUP          | Build a lookup table from a stream     |
| `JOIN(idx; s; k)`           | VLOOKUP down a column      | Join a stream against a lookup table   |
| `IN(stream)`                | MATCH / COUNTIF > 0        | Test if a value exists in a stream     |
| `contains` / `inside`       | SEARCH / FIND              | Structural containment check           |
| `startswith` / `endswith`   | LEFT / RIGHT comparison    | Test prefix or suffix                  |
| `ltrimstr` / `rtrimstr`     | SUBSTITUTE                 | Remove a known prefix or suffix        |
| `trim` / `ltrim` / `rtrim`  | TRIM                       | Strip whitespace                       |
| `ascii_upcase` / `downcase` | UPPER / LOWER              | Case conversion                        |
| `@csv` / `@tsv`             | Save As CSV                | Format arrays as delimited rows        |
| `walk(f)`                   | Apply formula to all cells | Recursively transform every node       |
| `input` / `inputs`          | Cross-workbook references  | Read additional JSON files             |
| `--rawfile`                 | Embed text                 | Read a file as a raw string            |

---

## Deep Dive

For more on `INDEX`, `IN`, `contains`, and other advanced builtins, see
[11-advanced-patterns.md](../11-advanced-patterns.md).  For real-world
recipes combining these features, see
[12-real-world-recipes.md](../12-real-world-recipes.md).

---

## Exercises

### Exercise 1: Revenue by Week

Calculate Week 1 revenue (dates before 2024-06-08) and Week 2 revenue
(dates on/after 2024-06-08) from the transactions array.  Filter to
transactions crediting account "4000" (Sales Revenue).

<details>
<summary>Solution</summary>

```bash
jq '
  .transactions as $txns |
  {
    week1: [$txns[] | select(.credit.account == "4000" and .date < "2024-06-08") | .credit.amount] | add,
    week2: [$txns[] | select(.credit.account == "4000" and .date >= "2024-06-08") | .credit.amount] | add
  }
' accounting/src/data/11-full-month.json
# {"week1":21,"week2":30}
```

String comparison works on ISO dates because "2024-06-07" sorts before
"2024-06-08".  Like `=SUMIFS(amount, date, "<2024-06-08", account,
"4000")` in Excel.

</details>

### Exercise 2: CSV Trial Balance

Generate a CSV trial balance of all non-zero pre-closing balances.
Columns: Code, Name, Debit, Credit.  Assets and expenses go in Debit;
liabilities, equity, and revenue go in Credit.

<details>
<summary>Solution</summary>

```bash
jq -r '
  INDEX(.chart_of_accounts[]; .code) as $lookup |
  (["Code","Name","Debit","Credit"] | @csv),
  (.pre_closing_balances | to_entries[] | select(.value != 0) |
    .key as $code | $lookup[$code] as $acct |
    if ($acct.type == "asset" or $acct.type == "expense")
    then [$code, $acct.name, .value, ""] | @csv
    else [$code, $acct.name, "", .value] | @csv
    end)
' accounting/src/data/11-full-month.json
```

Total debits equal total credits -- the fundamental check before closing.

</details>

### Exercise 3: Walk and Transform

Use `walk` to convert every multi-word account name to lowercase-with-
dashes (e.g., "Sales Revenue" becomes "sales-revenue").  Do not mangle
dates or single-word values.

<details>
<summary>Solution</summary>

```bash
jq 'walk(
  if type == "string" and contains(" ") and (contains("-") | not)
  then ascii_downcase | gsub(" "; "-")
  else .
  end
)' accounting/src/data/11-full-month.json | jq '.chart_of_accounts[12]'
# {"code":"4000","name":"sales-revenue","type":"revenue","category":"operating"}
```

The guards (`contains(" ")` and `contains("-") | not`) prevent mangling
dates like "2024-06-01" or single-word values like "asset".

</details>

### Exercise 4: Expense Ranking with INDEX

Rank expenses from highest to lowest with name, amount, and percentage
of total.  Use `INDEX` for name lookup and `sort_by` for ranking.

<details>
<summary>Solution</summary>

```bash
jq '
  INDEX(.chart_of_accounts[]; .code) as $lookup |
  [
    .pre_closing_balances | to_entries[] |
    select(.key | startswith("6")) | select(.value > 0) |
    { name: $lookup[.key].name, amount: .value }
  ] |
  (map(.amount) | add) as $total |
  sort_by(-.amount) |
  map(. + { pct: (.amount / $total * 100 | round | tostring) + "%" })
' accounting/src/data/11-full-month.json
```

Bad Debt ($5, 25%) > Insurance and Depreciation ($4, 20% each) > Wages
($3, 15%) > Advertising and Interest ($2, 10% each).

</details>

---

**Next up**: [11-advanced-patterns.md](../11-advanced-patterns.md) dives
deeper into jq's advanced features, and
[12-real-world-recipes.md](../12-real-world-recipes.md) shows complete
recipes for real-world data processing tasks.
