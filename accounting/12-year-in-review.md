# Lesson 12 -- Year in Review: Analysis and Comparison

> **Prerequisites**: You have read Lessons 01 through 11.  You know
> how to use `.`, `|`, `map`, `select`, `reduce`, `group_by`, `def`,
> `try/catch`, string interpolation, and object construction.

## The Story So Far

Summer is over.  The lemonade stand ran for three months -- June, July,
and August 2024 -- and you kept perfect books the whole time.

June was the learning month.  You invested $50, took out a $50 loan,
bought $40 worth of equipment, and earned your first revenue.  Net
income was modest: $6.  You were figuring things out.

July was the growth month.  Revenue jumped to $85.  You paid down $20
of the loan and cut unnecessary expenses.  Net income: $33.

August was the peak.  Revenue hit $120, you paid off the remaining $30
of the loan, and walked away with $53 of net income.  Zero debt.

Now it is September.  Your mom sits down with you and says: "Good
summer.  But before we close the books, let's look at all three months
side by side.  That's how real accountants do it -- comparative
statements."

In this lesson you will learn the jq tools for multi-period analysis:
loading and combining data, pivoting rows into columns, reusing code
across files, and inspecting your pipeline when things go wrong.

---

## Setup

All commands below run from the **project root**.  The data file is at
`accounting/src/data/12-multi-period.json`.

Quick check -- print the business name and month labels:

```bash
jq '{business, months: [.months[].period]}' \
  accounting/src/data/12-multi-period.json
```

You should see:

```json
{
  "business": "Lemonade Stand",
  "months": ["June 2024", "July 2024", "August 2024"]
}
```

The file holds three months of income statements and balance sheets in
a single JSON document.  Each month is an object in the `.months` array.

---

## 1. `jq -s` (slurp) -- Loading Multiple Worksheets at Once

**Excel analogy**: You have three separate Excel files -- `June.xlsx`,
`July.xlsx`, `August.xlsx`.  You open all three and copy them into one
workbook as separate tabs.  That is exactly what `jq -s` does.

Normally, jq processes one JSON document at a time.  The `-s` flag
("slurp") reads *all* inputs and wraps them into a single array:

```bash
# Without -s: each document is processed independently
echo '{"month":"June"}' | jq '.'
# {"month":"June"}

# With -s: all documents become one array
echo '{"month":"June"}
{"month":"July"}
{"month":"Aug"}' | jq -s '.'
# [{"month":"June"},{"month":"July"},{"month":"Aug"}]
```

When would you use this?  When your data lives in separate files:

```bash
# Imagine three monthly files (we will simulate with one file)
# jq -s '.' june.json july.json august.json
# Result: [ {june data}, {july data}, {august data} ]
```

After slurping, you have an array, and all your array tools work:
`map`, `group_by`, `sort_by`, `add`, `length`.

> **Key insight**: `-s` is your "combine workbooks" button.  Use it
> when data arrives in multiple files or multiple JSON lines, and you
> need to process them together.

### The `inputs` alternative

There is also a built-in called `inputs` that works with the `-n` flag.
`-n` suppresses the default input, and `inputs` reads all remaining
inputs as a stream:

```bash
echo '{"a":1}
{"b":2}
{"c":3}' | jq -n '[inputs]'
# [{"a":1},{"b":2},{"c":3}]
```

`inputs` gives you more control than `-s` because you can process
documents one at a time inside a `foreach` or `reduce` without loading
them all into memory.  For small files, `-s` is simpler.  For very
large files, `inputs` is more efficient.

---

## 2. `--slurpfile` -- Loading Reference Data

**Excel analogy**: You have a main worksheet open, and you use VLOOKUP
to pull values from a second workbook.  `--slurpfile` loads that second
workbook into a variable.

```bash
jq --slurpfile ref other-file.json '...' main-file.json
```

Inside the filter, `$ref` is an array containing the parsed contents of
`other-file.json`.  You access it like any other variable.

This is useful when your analysis needs reference data -- industry
benchmarks, prior-year numbers, or a chart of accounts -- that lives in
a separate file:

```bash
# Example: load a benchmark file alongside your data
# jq --slurpfile bench benchmarks.json \
#   '.months[] | .income_statement.revenue / $bench[0].industry_avg' \
#   accounting/src/data/12-multi-period.json
```

> **When to use what**:
> - `-s` = "merge all inputs into one array"
> - `--slurpfile var file` = "load this second file as a side reference"
> - `--arg name value` = "pass in a single string value" (Lesson 01)
> - `--argjson name value` = "pass in a JSON value"

---

## 3. `transpose` -- Turning Rows into Columns

**Excel analogy**: Paste Special > Transpose.  You have data in rows
and you want it in columns, or vice versa.  `transpose` flips the
orientation.

Given a "matrix" (array of arrays), `transpose` swaps rows and columns:

```bash
jq -n '[[1,2,3],[4,5,6]] | transpose'
# [[1,4],[2,5],[3,6]]
```

Before:
```
  Row 0: [1, 2, 3]
  Row 1: [4, 5, 6]
```

After:
```
  Row 0: [1, 4]   (was column 0)
  Row 1: [2, 5]   (was column 1)
  Row 2: [3, 6]   (was column 2)
```

### Why accountants need this

You have three months of data, each with the same line items (revenue,
COGS, gross profit, etc).  Each month is naturally a "column."  But for
side-by-side comparison, you want each *line item* as a row with three
values across.  `transpose` does that pivot:

```bash
# Extract the five key numbers from each month (three columns)
jq '.months | map(.income_statement | [
  .revenue, .cogs, .gross_profit, .total_expenses, .net_income
])' accounting/src/data/12-multi-period.json
# [[51,25,26,20,6],[85,40,45,12,33],[120,55,65,12,53]]

# Transpose: now each row is one line item across three months
jq '.months | map(.income_statement | [
  .revenue, .cogs, .gross_profit, .total_expenses, .net_income
]) | transpose' accounting/src/data/12-multi-period.json
# [[51,85,120],[25,40,55],[26,45,65],[20,12,12],[6,33,53]]
```

Row 0 is revenue across all three months: `[51, 85, 120]`.  Row 4 is
net income: `[6, 33, 53]`.  Now you can see trends at a glance.

---

## 4. Modules -- Reusable Macro Libraries

**Excel analogy**: You have a set of VBA macros you use in every
workbook -- currency formatting, ratio calculations, column alignment.
Instead of copy-pasting them into each file, you save them in a shared
module that every workbook can reference.

jq has the same idea.  You can put function definitions (`def`) in a
`.jq` file and load them with `import` or `include`:

```
# file: mylib.jq
def dollars:
  "$" + (. * 100 | round / 100 | tostring | split(".")
    | if length == 1 then .[0] + ".00"
      elif (.[1] | length) == 1 then join(".") + "0"
      else join(".")
      end);

def pct:
  . * 1000 | round / 10 | tostring + "%";
```

```
# file: report.jq
include "mylib";

.revenue | dollars    # uses dollars from mylib.jq
```

To run it, tell jq where to find the library with `-L`:

```bash
jq -L ./lib -f report.jq data.json
```

### `import` vs `include`

- `include "mylib";` -- pulls all definitions into the current scope.
  Like `#include` in C or `from mylib import *` in Python.

- `import "mylib" as mylib;` -- pulls definitions in under a namespace.
  You call them as `mylib::dollars`.  Avoids name collisions.

For small projects, `include` is fine.  For larger projects with
multiple libraries, `import` keeps things organized.

> **Practical note**: In this lesson's program file, we define `dollars`,
> `pct`, `pad`, and `lpad` directly in the script (as we have done since
> Lesson 06).  In a real project with many reports, you would move those
> into a shared module.

---

## 5. `-c` -- Compact Output

**Excel analogy**: "Save As CSV" versus a formatted printout.
Sometimes you want data tight and compact for another program to read,
not pretty-printed for humans.

```bash
# Pretty-printed (default) -- nice for humans
jq '.months[0].income_statement' accounting/src/data/12-multi-period.json

# Compact (-c) -- one line, no whitespace -- nice for pipelines
jq -c '.months[0].income_statement' accounting/src/data/12-multi-period.json
```

Compact output is useful when piping jq's output into another tool, or
when building JSON lines (one JSON object per line) for log files and
streaming systems.

```bash
# One line per month -- "JSON Lines" format
jq -c '.months[]' accounting/src/data/12-multi-period.json
```

---

## 6. `debug` -- The Immediate Window

**Excel analogy**: In VBA, you use `Debug.Print` to print a value to
the Immediate Window while your macro runs.  The macro keeps going --
`Debug.Print` is just a peek at what is happening inside.

`debug` does the same thing in jq.  It prints the current value to
stderr (the "side channel") and passes it through unchanged:

```bash
jq '.months[0].income_statement.revenue | debug | . * 2' \
  accounting/src/data/12-multi-period.json
```

You will see two things:

1. On stderr: `["DEBUG:",51]` -- the peek
2. On stdout: `102` -- the actual result

The pipeline is not affected.  `debug` just lets you inspect values
mid-flow.  Extremely useful when a calculation is producing unexpected
results and you want to see intermediate values.

You can add a label to identify which debug is which:

```bash
jq '.months[0].income_statement |
  .revenue as $rev | $rev | debug("revenue") |
  . - (.income_statement.cogs // 0) | debug("margin")' \
  accounting/src/data/12-multi-period.json
```

Or more practically, debug at each step of a calculation:

```bash
jq '.months[0].income_statement |
  { rev: .revenue, cogs: .cogs } | debug("inputs") |
  .rev - .cogs | debug("gross_profit")' \
  accounting/src/data/12-multi-period.json
```

There is also `stderr`, which outputs the value to stderr in JSON
format (without the `["DEBUG:"]` wrapper).  It is a rawer version of
debug for when you want clean stderr output.

> **Tip**: Sprinkle `| debug` into your pipeline when troubleshooting.
> Remove them when you are done -- they are the jq equivalent of
> leftover `print` statements.

---

## 7. Streaming -- Processing Data Piece by Piece

**Excel analogy**: Imagine a spreadsheet so large it won't fit in
memory.  Instead of opening the whole file, you read it one row at a
time.  jq's streaming mode does the same thing for JSON.

### `--stream` flag

The `--stream` flag breaks a JSON document into a stream of path-value
pairs:

```bash
echo '{"a":1,"b":[2,3]}' | jq --stream '.'
# [[],{"a":1,"b":[2,3]}]     (not actually -- let's see the real output)
```

Actually, `--stream` produces pairs like `[[path], value]`:

```bash
echo '{"a":1,"b":[2,3]}' | jq --stream '.'
# [["a"],1]
# [["b",0],2]
# [["b",1],3]
# [["b",1]]      <- end marker for array "b"
# [["b"]]        <- end marker for object
```

Each pair tells you: "at this path in the document, you will find this
value."  Think of it like: "Cell A1 contains 1, Cell B1 contains 2,
Cell B2 contains 3."

### `tostream` and `fromstream`

- `tostream` converts a value into path-value pairs (like `--stream`
  but as a filter, not a flag)
- `fromstream` reassembles path-value pairs back into a value
- `truncate_stream(expr)` removes one level of nesting from paths

```bash
# Break down the June income statement into path-value pairs
jq '.months[0].income_statement | [tostream]' \
  accounting/src/data/12-multi-period.json

# Truncate removes the leading path segment
jq -n '[[["a","b"],1],[["a","c"],2],[["a"]]] | fromstream(truncate_stream(.[]))'
```

Streaming is an advanced feature.  You will not need it for everyday
accounting work, but it is invaluable when processing files too large
to hold in memory, or when you need to transform deeply nested
structures programmatically.

---

## 8. Format Strings -- Save As Different Formats

**Excel analogy**: "Save As..." lets you export data as CSV, PDF, HTML,
or XML.  jq has format strings that transform data for different
destinations.

| Format     | Purpose                              | Example                        |
|------------|--------------------------------------|--------------------------------|
| `@json`    | Compact JSON string (escaped)        | `"hello" | @json` -> `"\"hello\""` |
| `@base64`  | Base64 encode                        | `"hello" | @base64` -> `"aGVsbG8="` |
| `@base64d` | Base64 decode                        | `"aGVsbG8=" | @base64d` -> `"hello"` |
| `@uri`     | URL-encode                           | `"a b" | @uri` -> `"a%20b"` |

### `@json` -- Machine-readable export

When you need to embed JSON inside another JSON string, or pass data to
an API:

```bash
# Wrap the summary as a JSON string
jq '.months[0].income_statement | @json' \
  accounting/src/data/12-multi-period.json
```

The result is a *string* containing JSON, with all quotes escaped.
This is useful when a downstream system expects a JSON payload inside
a string field.

### `@base64` -- Safe transport

Base64 turns any data into letters and numbers only -- no special
characters that might break email, URLs, or command lines:

```bash
jq '.months[0].income_statement | @json | @base64' \
  accounting/src/data/12-multi-period.json
```

To decode:

```bash
echo '"eyJyZXZlbnVlIjo1MX0="' | jq '. | @base64d'
```

### `@uri` -- Web-safe encoding

When embedding data in a URL, spaces and special characters must be
encoded:

```bash
jq -n '"Lemonade Stand Report" | @uri'
# "Lemonade%20Stand%20Report"
```

---

## 9. `$ENV` and `env` -- Environment Variables

**Excel analogy**: Like reading Windows environment variables (PATH,
USERNAME) from inside a macro.  Environment variables are settings that
live outside your data but can influence your program.

`$ENV` is a built-in jq object containing all environment variables:

```bash
jq -n '$ENV.USER'
# "yourusername"

jq -n '$ENV.HOME'
# "/Users/yourusername"
```

`env` is a built-in that returns the entire environment as an object:

```bash
jq -n 'env | keys[:5]'
# first 5 environment variable names
```

Practical use -- embedding metadata in reports:

```bash
jq '{
  report: "Summer 2024 Analysis",
  generated_by: $ENV.USER,
  data: .business
}' accounting/src/data/12-multi-period.json
```

> **When to use**: `$ENV` is read-only.  You cannot set environment
> variables from jq.  Use it to pick up configuration that was set
> before jq runs -- like which fiscal year to analyze, or who is
> running the report.

---

## Running the Full Program

The program file computes everything from this lesson:

```bash
jq -f accounting/src/programs/12-ratio-analysis.jq \
  accounting/src/data/12-multi-period.json
```

It produces:

1. **Comparative Income Statement** -- revenue, COGS, gross profit,
   expenses, and net income for all three months side by side (uses
   `transpose`)

2. **Financial Ratios** -- gross margin, net margin, expense ratio,
   current ratio, and debt-to-equity for each month

3. **Month-over-Month Growth** -- revenue trends from June to August

4. **Export Formats** -- the same summary data rendered with `@json`,
   `@base64`, and `@uri`

5. **Report Metadata** -- who generated the report (from `$ENV`)

6. **Comparative Balance Sheet** -- assets, liabilities, and equity
   across months (uses `transpose` again)

7. **Summer Summary** -- totals and final status

---

## Accounting Sidebar: Comparative Statements and Closing

### Comparative Financial Statements

When accountants say "comparative statements," they mean presenting
two or more periods side by side.  This is standard practice in annual
reports -- you always see this year and last year (at minimum) for every
line item.

The purpose is **trend analysis**.  A single number like "$120 revenue"
is meaningless by itself.  But "$120 revenue, up from $51 three months
ago" tells a story: the business is growing.

Common comparisons:

| Type | Compares |
|------|----------|
| Horizontal analysis | Same line item across periods (our approach) |
| Vertical analysis | Each line item as % of revenue (common-size) |
| Ratio analysis | Calculated metrics (margins, turnover, liquidity) |

### Key Financial Ratios

The ratios computed in the program:

- **Gross Margin** = Gross Profit / Revenue.  How much of each dollar
  is left after paying for supplies.  Our stand improved from 51% to
  54% -- we got better at managing ingredient costs.

- **Net Margin** = Net Income / Revenue.  The bottom-line profit per
  dollar of revenue.  Jumped from 12% to 44% as we eliminated
  one-time expenses (advertising, bad debt, interest).

- **Expense Ratio** = Operating Expenses / Revenue.  How much overhead
  eats into each revenue dollar.  Dropped from 39% to 10%.

- **Current Ratio** = Current Assets / Current Liabilities.  Can the
  business pay its bills?  Above 1.0 is healthy.  By August: no
  liabilities at all.

- **Debt-to-Equity** = Total Liabilities / Total Equity.  How much of
  the business is funded by debt vs. the owner's money.  Went from
  0.89x to 0.0x -- fully owner-funded by August.

### Closing the Books

At the end of an accounting period, you "close" the temporary accounts
(revenue, expenses) by transferring their balances to retained earnings.
This resets the income statement to zero for the next period.

Think of it like zeroing out a trip odometer.  The mileage (retained
earnings) keeps accumulating, but the trip counter (this month's
revenue and expenses) resets.

For our lemonade stand:
- Summer total revenue: $256 ($51 + $85 + $120)
- Summer total net income: $92 ($6 + $33 + $53)
- Final retained earnings: $92 (cumulative net income: $6 + $33 + $53)
- Final status: debt-free, $142 in total assets

Note: loan repayments do not affect retained earnings or net income.
Repaying a loan reduces Cash (asset) and Notes Payable (liability) by
equal amounts -- the balance sheet shrinks, but the income statement is
untouched.  Retained earnings is purely the accumulation of net income.

Not bad for a first summer.

---

## jq Cheat Sheet -- New Features

| Feature | What it does | Excel analogy |
|---------|-------------|---------------|
| `jq -s` | Slurp multiple inputs into one array | "Open all workbooks as tabs" |
| `inputs` | Stream multiple inputs with `-n` flag | "Open each workbook one at a time" |
| `--slurpfile var file` | Load a file into `$var` | "VLOOKUP from another workbook" |
| `transpose` | Swap rows and columns | "Paste Special > Transpose" |
| `include "lib"` | Load shared definitions | "Import VBA module" |
| `import "lib" as x` | Load with namespace | "Import module as x" |
| `-c` | Compact output (no whitespace) | "Save As CSV" |
| `debug` | Print to stderr, pass through | "Debug.Print (Immediate Window)" |
| `stderr` | Print to stderr (raw, no wrapper) | "Debug.Print (no label)" |
| `--stream` | Stream path-value pairs | "Read one row at a time" |
| `tostream` / `fromstream` | Convert to/from stream format | "Explode/reassemble a sheet" |
| `truncate_stream` | Remove leading path level | "Remove top header row" |
| `@json` | Format as JSON string | "Save As JSON" |
| `@base64` / `@base64d` | Encode/decode base64 | "Encode attachment" |
| `@uri` | URL-encode a string | "Encode for web link" |
| `$ENV.NAME` | Read environment variable | "Read system variable" |
| `env` | All environment variables as object | "List all system variables" |

---

## Exercises

### Exercise 1: Common-Size Income Statement

Create a "common-size" income statement where every line item is shown
as a percentage of revenue.  Output one object per month with the
period name and percentages.

*Hint*: Divide each line item by revenue and use the `pct` pattern
(`* 1000 | round / 10`).

<details>
<summary>Solution</summary>

```bash
jq '.months[] | .income_statement as $is | {
  period: .period,
  revenue:        "100%",
  cogs:           ($is.cogs / $is.revenue * 1000 | round / 10 | tostring + "%"),
  gross_profit:   ($is.gross_profit / $is.revenue * 1000 | round / 10 | tostring + "%"),
  expenses:       ($is.total_expenses / $is.revenue * 1000 | round / 10 | tostring + "%"),
  net_income:     ($is.net_income / $is.revenue * 1000 | round / 10 | tostring + "%")
}' accounting/src/data/12-multi-period.json
```

You should see gross margin improving (51% to 54%) and expense ratio
dropping (39% to 10%).  This is vertical analysis -- comparing each
line item to the top-line revenue within the same period.

</details>

### Exercise 2: Best and Worst Month

Use `max_by` and `min_by` to find the month with the highest net income
and the month with the lowest.  Output the period name and net income
for each.

<details>
<summary>Solution</summary>

```bash
jq '{
  best:  (.months | max_by(.income_statement.net_income)
          | {period, net_income: .income_statement.net_income}),
  worst: (.months | min_by(.income_statement.net_income)
          | {period, net_income: .income_statement.net_income})
}' accounting/src/data/12-multi-period.json
```

Best: August ($53), Worst: June ($6).

</details>

### Exercise 3: Balance Sheet Validation with debug

Write a filter that checks whether each month's balance sheet balances
(total_assets == total_liabilities + total_equity).  Use `debug` to
inspect the intermediate values.

*Hint*: Use `map` and produce an object with the period, computed sum,
stated total, and a `balanced` boolean.

<details>
<summary>Solution</summary>

```bash
jq '.months | map(
  .period as $period |
  .balance_sheet as $bs |
  ($bs.total_liabilities + $bs.total_equity) | debug("L+OE") |
  {
    period:    $period,
    assets:    $bs.total_assets,
    l_plus_oe: .,
    balanced:  (. == $bs.total_assets)
  }
)' accounting/src/data/12-multi-period.json
```

On stderr you will see the L+OE values being checked.  All three
months should show `"balanced": true`.  If not, you have a data entry
error -- just like a trial balance that does not balance.

</details>

### Exercise 4: Export Monthly Summary as JSON Lines

Use `-c` and `map` to produce one compact JSON line per month,
containing only the period, revenue, and net income.  This is the
"JSON Lines" format used by many data pipelines.

<details>
<summary>Solution</summary>

```bash
jq -c '.months[] | {
  period,
  revenue:    .income_statement.revenue,
  net_income: .income_statement.net_income
}' accounting/src/data/12-multi-period.json
```

Output (three lines, one per month):
```
{"period":"June 2024","revenue":51,"net_income":6}
{"period":"July 2024","revenue":85,"net_income":33}
{"period":"August 2024","revenue":120,"net_income":53}
```

Each line is valid JSON on its own.  This format is used by tools like
`jq -s` (to re-slurp), databases, and log aggregation systems.

</details>

### Exercise 5: Revenue Trend with transpose

Build a 2-row matrix: row 0 is the month labels, row 1 is the revenue
figures.  Then `transpose` it into an array of `[label, revenue]`
pairs.

<details>
<summary>Solution</summary>

```bash
jq '[
  [.months[].period],
  [.months[].income_statement.revenue]
] | transpose' accounting/src/data/12-multi-period.json
```

Output:
```json
[["June 2024",51],["July 2024",85],["August 2024",120]]
```

This is a common pattern for building tables: put headers and data in
separate rows, then transpose to get `[header, value]` pairs.  It
works with any number of columns -- add a third row for net income and
you get `[header, revenue, net_income]` triples.

</details>

---

**This is the final lesson of the Summer 2024 series.**  You started
with $50, a notebook, and no idea what a balance sheet was.  You
learned debits and credits, built income statements, handled
adjustments, and closed the books on a profitable summer.

Along the way, you learned jq from `.` to `transpose`, from simple
field access to modules and streaming.  Every concept was grounded in
a real accounting task -- because the best way to learn a tool is to
use it for something that matters.

The lemonade stand is closed for the season.  But the books are open
for review anytime.
