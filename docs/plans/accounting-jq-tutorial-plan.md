# Plan: The jq Accounting Game

A tutorial series that teaches jq through running a lemonade stand,
inspired by Darrell Mullis's "The Accounting Game." Each lesson advances
both the accounting story and jq complexity. An accountant learns
programming; a programmer learns accounting.

This is a **parallel** tutorial track. The existing developer-focused
tutorials (`00-overview.md` through `12-real-world-recipes.md` in the
project root) remain untouched. This accounting series lives entirely
under the `accounting/` subdirectory.

## Design Principles

1. **One continuous story** -- a lemonade stand grows from a $50 cash box
   to a business with loans, inventory, depreciation, and full financial
   statements. Every data file is a chapter in that story.
2. **Excel is the bridge** -- the reader knows Excel. Every jq concept is
   first shown as the Excel equivalent, then translated. "Think of `.[]`
   as dragging a formula down a column."
3. **Progressive jq features** -- each lesson introduces exactly the jq
   features needed for that accounting step. No feature appears before
   the story demands it.
4. **Runnable from day one** -- every lesson references data files in
   `accounting/src/data/` and jq programs in `accounting/src/programs/`
   that the reader runs in their terminal. The .md tutorials and src/
   files cross-reference each other.
5. **Dual audience** -- accounting sidebars teach programmers; jq
   sidebars teach accountants. Both learn by doing the same exercises.
6. **Complete jq coverage** -- by lesson 12, all commonly-used jq
   features have been introduced. Lesson 13 (appendix) covers niche
   features for reference.

---

## Directory Structure

```
learning-jq/
  00-overview.md                         # (EXISTING - developer tutorial, do not touch)
  01-basics.md                           # (EXISTING - developer tutorial, do not touch)
  ... through 12-real-world-recipes.md   # (EXISTING - developer tutorial, do not touch)

  accounting/                            # NEW - accounting-focused parallel track
    README.md                            # Series overview, prerequisites, how to run
    01-opening-day.md                    # Lesson 1
    02-buying-supplies.md                # Lesson 2
    03-first-sales.md                    # Lesson 3
    04-end-of-week.md                    # Lesson 4
    05-the-balance-sheet.md              # Lesson 5
    06-the-income-statement.md           # Lesson 6
    07-growing-the-business.md           # Lesson 7
    08-adjustments-and-accruals.md       # Lesson 8
    09-cash-flow-statement.md            # Lesson 9
    10-trial-balance.md                  # Lesson 10
    11-financial-statements.md           # Lesson 11
    12-year-in-review.md                 # Lesson 12
    13-appendix-extra-features.md        # Appendix: niche jq features
    src/
      data/
        chart-of-accounts.json           # Master account list (used throughout)
        01-opening-day.json              # Mom's $50 investment
        02-purchases.json                # Lemons, sugar, cups bought
        03-daily-sales.json              # Day 1 sales transactions
        04-week1-transactions.json       # Full week of mixed transactions
        05-balance-sheet-week1.json      # End-of-week1 account balances
        06-income-data-week1.json        # Revenue + expense details for week 1
        07-week2-transactions.json       # Loan, equipment, new sales, credit sales
        08-adjusting-entries.json         # Depreciation, prepaid insurance, bad debt
        09-cash-movements.json           # All cash in/out for cash flow statement
        10-general-ledger.json           # Full ledger with some deliberate errors
        11-full-month.json               # Complete month of data, all accounts
        12-multi-period.json             # Three months side-by-side for comparison
        13-appendix-samples.json         # Data for appendix exercises
      programs/
        01-view-accounts.jq              # Look at chart of accounts, read fields
        02-calculate-costs.jq            # Arithmetic on purchase amounts
        03-sales-summary.jq              # Filter/sort/map daily sales
        04-weekly-totals.jq              # group_by + reduce for period totals
        05-build-balance-sheet.jq        # Construct balance sheet from accounts
        06-income-statement.jq           # Compute Sales - COGS - Expenses = Net Income
        07-post-transactions.jq          # Update ledger with new transactions
        08-apply-adjustments.jq          # Process adjusting entries (depreciation etc.)
        09-cash-flow.jq                  # Build cash flow statement from movements
        10-validate-ledger.jq            # Trial balance + debit/credit validation
        11-full-statements.jq            # Generate all three financial statements
        12-ratio-analysis.jq             # Multi-period comparison + financial ratios
        13-appendix-demos.jq             # Niche feature demonstrations
      lib/
        accounting.jq                    # Shared library (introduced in lesson 11)
```

---

## Lesson-by-Lesson Plan

### Lesson 01 -- Opening Day: Setting Up the Books

**Story**: You save $50 from chores. Mom agrees to invest it in your
lemonade stand. You set up a chart of accounts and record the initial
investment.

**Accounting concepts**:
- What is a transaction? (An event that changes your financial position)
- The accounting equation: Assets = Liabilities + Owner's Equity
- Chart of accounts: giving names and numbers to categories
- Your first journal entry: Cash +$50, Owner's Equity +$50

**jq features introduced**:
- What is JSON? (Excel worksheet = JSON object, column header = key)
- The identity filter `.` ("like `=A1` -- just show me the cell")
- Field access `.field` ("like VLOOKUP picking one column")
- Pipe `|` ("like chaining formulas: `=B1` where B1 references A1")
- CLI flags: `-r` (raw output), pretty-print, `-n` (null input)
- `.field1.field2` chained access ("nested INDEX lookups")

**Data file**: `accounting/src/data/01-opening-day.json`
```json
{
  "business": "Lemonade Stand",
  "owner": "You",
  "date": "2024-06-01",
  "transactions": [
    {
      "id": 1,
      "date": "2024-06-01",
      "description": "Owner investment - saved from chores",
      "debit": { "account": "Cash", "amount": 50.00 },
      "credit": { "account": "Owner's Equity", "amount": 50.00 }
    }
  ],
  "balance_sheet": {
    "assets": { "cash": 50.00 },
    "liabilities": {},
    "owners_equity": { "invested_capital": 50.00 }
  }
}
```

**jq program**: `accounting/src/programs/01-view-accounts.jq`
- Read business name, owner, date
- Navigate to balance_sheet.assets.cash
- Verify equation: assets total == liabilities + equity

**Excel analogy box**: "JSON is a spreadsheet where every row has named
columns instead of A, B, C. `.balance_sheet.assets.cash` is like
clicking cell C2 in a sheet named 'Balance Sheet'."

---

### Lesson 02 -- Buying Supplies: Numbers and Calculations

**Story**: You buy lemons ($5), sugar ($3), cups ($2). Cash goes down,
inventory goes up. You learn that spending money doesn't always mean
losing money -- it can mean trading one asset for another.

**Accounting concepts**:
- Assets can change form (cash -> inventory) without affecting equity
- Cost of goods: tracking what you paid for supplies
- The balance sheet still balances after purchases

**jq features introduced**:
- Types: numbers, strings, booleans, null, arrays, objects
- Arithmetic: `+`, `-`, `*`, `/`, `%` modulo ("like =A1+B1 in Excel")
- **Comparison operators**: `==`, `!=`, `<`, `>`, `<=`, `>=`
  ("like =A1>B1 in Excel")
- **Logical operators**: `and`, `or`, `not` ("like AND(), OR(), NOT()")
- **Truthiness**: only `false` and `null` are falsy; `0`, `""`, `[]`
  are truthy ("different from Excel where 0 and empty string are falsy")
- String interpolation `\(...)` ("like =CONCAT or & in Excel")
- `type` function ("like Excel's TYPE()")
- `length` on different types
- `--arg` and `--argjson` for passing values in
- **`tonumber`, `tostring`, `toboolean`**: converting types ("like
  VALUE(), TEXT() in Excel")
- **`abs`**: absolute value ("like ABS() in Excel")

**Data file**: `accounting/src/data/02-purchases.json`
- Three purchase transactions (lemons, sugar, cups)
- Updated balance sheet showing cash down, inventory up

**jq program**: `accounting/src/programs/02-calculate-costs.jq`
- Sum up purchase amounts
- Calculate remaining cash
- Verify balance sheet equation
- Compare costs between items using comparison operators

---

### Lesson 03 -- Selling Lemonade: Working with Lists

**Story**: Your first day of sales! You sell 15 cups at $0.50 each,
some cups at $0.75 to an eager customer. You record each sale.
By end of day you have a list of transactions.

**Accounting concepts**:
- Revenue recognition: you record a sale when the lemonade is delivered
- Each sale has a quantity, price, and total
- Sales are the "top line" of business

**jq features introduced**:
- Arrays and `.[]` iterator ("like a column of data -- `.[]` applies
  to each row")
- **Array indexing**: `.[0]`, `.[-1]` ("like INDEX(A:A, 1) and
  INDEX(A:A, ROWS(A:A))")
- **Array slicing**: `.[2:5]` ("like selecting rows 3 through 5")
- `map(f)` ("like dragging a formula down a column")
- `select(f)` ("like Excel FILTER()")
- `add` ("like SUM()")
- `length` on arrays ("like COUNTA()")
- Collecting with `[...]` ("wrapping results back into a column")
- **The comma operator**: `.a, .b` produces multiple outputs
  ("like selecting two columns at once")
- **`range(n)`**: generating number sequences ("like ROW(1:10) or
  SEQUENCE(10)")
- **Type selectors**: `numbers`, `strings`, `booleans`, `nulls`,
  `arrays`, `objects`, `scalars`, `iterables` ("like filtering a column
  by cell type -- `[.[] | numbers]` keeps only numbers, like
  FILTER + ISNUMBER")
- **`first(expr)` and `last(expr)`**: getting the first/last output
- **`limit(n; expr)`**: taking only the first n results
  ("like TOP n in SQL or head of a list")

**Data file**: `accounting/src/data/03-daily-sales.json`
- Array of ~15 individual sale objects with date, quantity, unit_price, total

**jq program**: `accounting/src/programs/03-sales-summary.jq`
- Count total cups sold
- Calculate total revenue
- Filter: which sales were above $0.50/cup?
- Find the biggest single sale
- First/last sale of the day using `first` and `last`
- Use type selectors to extract only numeric values from mixed data

---

### Lesson 04 -- End of the Week: Sorting and Grouping

**Story**: Week 1 is done. You have purchases, sales, and expenses
(a friend helped for $1). Time to organize everything: sort by date,
group by type, compute subtotals.

**Accounting concepts**:
- Transaction types: revenue, expense, asset purchase
- Grouping transactions by category (like a pivot table)
- Period totals: what happened this week?

**jq features introduced**:
- `sort_by(.field)` ("like Data > Sort in Excel")
- **`sort` and `reverse`** ("plain sort for simple arrays")
- `group_by(.field)` ("like a Pivot Table")
- `unique` / `unique_by` ("like Remove Duplicates")
- `min_by` / `max_by`, **`min` / `max`** ("like MIN/MAX with criteria")
- `to_entries` / `from_entries` ("like unpivoting / pivoting")
- Object construction shorthand `{name, amount}`
- **`skip(n; expr)`**: skip the first n results (jq 1.8)

**Data file**: `accounting/src/data/04-week1-transactions.json`
- 15-20 transactions covering purchases, sales, labor payment, small expenses

**jq program**: `accounting/src/programs/04-weekly-totals.jq`
- Sort all transactions by date
- Group by type, compute subtotal per group
- Find the day with the highest revenue
- Get the top 3 transactions by amount using `sort_by | reverse | limit`

---

### Lesson 05 -- Counting the Money: The Balance Sheet

**Story**: End of week 1. You count your cash, count your leftover
lemons and sugar, and build your first balance sheet. Assets = Liabilities
+ Owner's Equity. Everything must balance.

**Accounting concepts**:
- Balance sheet: a snapshot at a point in time (like a photograph)
- Assets: Cash, Inventory (lemons, sugar, cups)
- Liabilities: none yet
- Owner's Equity: original investment + retained earnings
- The equation MUST balance

**jq features introduced**:
- `reduce` ("like SUM(), but you control the logic")
- **`as $var`**: binding a value to a name ("like naming a cell so you
  can reference it later -- `(.assets | add) as $a` is like `$A = SUM(Assets)`")
- Building objects from computed values
- **Computed keys `{($var): value}`**: building objects where the key
  is itself a variable or expression
- `with_entries(f)` ("like transforming a table's columns")
- **`map_values(f)`**: transform all values in an object
  ("like dragging a formula across all columns")
- `keys` and `values` and **`keys_unsorted`**
- `has(key)` and **`in(object)`** ("like checking if a column exists")
- The alternative operator `//` ("like IFERROR() or IFNA()")
- **`any(f)` and `all(f)`**: testing a list against a condition
  ("like OR(condition_range) and AND(condition_range) in Excel")
- **`flatten` / `flatten(depth)`**: flattening nested arrays
  ("like expanding grouped rows in a pivot table")
- **`add(generator)`**: sum a generator directly (jq 1.8 --
  `add(.[] | .amount)` instead of `[.[] | .amount] | add`)
- **`pick(.field1, .field2)`**: select a subset of fields from an
  object (jq 1.8 -- "like choosing which columns to include in a view")

**Data file**: `accounting/src/data/05-balance-sheet-week1.json`
- All account balances at end of week 1

**jq program**: `accounting/src/programs/05-build-balance-sheet.jq`
- Compute total assets, total liabilities, total equity using `as $var`
- Verify the equation balances using `all`
- Format a readable balance sheet output
- Use `map_values` to round all amounts to 2 decimal places
- Use `pick` to extract only balance sheet accounts from the full ledger

---

### Lesson 06 -- Did We Make Money? The Income Statement

**Story**: The balance sheet shows what you have, but did you actually
make money this week? The income statement answers: Revenue - COGS -
Expenses = Net Profit. You discover your gross profit margin.

**Accounting concepts**:
- Income statement: a movie vs the balance sheet's photograph
- Sales (top line)
- Cost of Goods Sold: what the lemons/sugar/cups cost for what you sold
- Gross Profit = Sales - COGS
- Operating Expenses (labor, advertising sign)
- Net Profit = Gross Profit - Expenses (the "bottom line")

**jq features introduced**:
- `if-then-elif-else-end` ("like nested IF() in Excel")
- `if` without `else` (jq 1.8: defaults to identity)
- Defining functions with `def` ("like creating a named formula or
  VBA function you can reuse")
- Functions calling functions (composability)
- Functions with arguments: `def f(x): ...`
- `try-catch` ("like IFERROR()")
- **`split` / `join`**: splitting and joining strings
  ("like TEXTSPLIT() and TEXTJOIN() in Excel")

**Data file**: `accounting/src/data/06-income-data-week1.json`
- Sales array, COGS breakdown, operating expenses

**jq program**: `accounting/src/programs/06-income-statement.jq`
- `def total_sales:`, `def cogs:`, `def gross_profit:`
- `def operating_expenses:`, `def net_profit:`
- Classify each transaction as revenue or expense
- Produce formatted income statement
- Split account names for display formatting

---

### Lesson 07 -- Growing the Business: Loans, Equipment, and Credit

**Story**: Week 2. Encouraged by profits, you borrow $50 from the bank
(Notes Payable). You buy a nicer stand. A neighbor buys lemonade on
credit (Accounts Receivable). You sell leftover inventory to a friend.
Business is getting complex.

**Accounting concepts**:
- Liabilities: Notes Payable (bank loan)
- Fixed assets vs current assets
- Accounts Receivable: selling on credit
- How the loan changes the balance sheet (cash up, liabilities up)
- Retained earnings carry forward from week 1

**jq features introduced**:
- Update operators: `|=`, `+=`, `-=` ("like changing a cell in place")
- `del(.field)` ("like deleting a column")
- `.path = value` ("like typing a new value into a cell")
- `//=` alternative assignment ("like setting a default")
- Nested updates: `.assets.cash += 50`
- **`?` operator**: optional access `.foo?`, `.[]?` ("like wrapping
  every cell reference in IFERROR -- no crash if it doesn't exist")
- **`try` without `catch`**: silently ignore errors

**Data file**: `accounting/src/data/07-week2-transactions.json`
- Bank loan, equipment purchase, credit sales, loan repayment,
  interest payment, inventory sale to friend

**jq program**: `accounting/src/programs/07-post-transactions.jq`
- Read previous balance sheet
- Apply each transaction as an update
- Show balance sheet after each transaction (running state)
- Use `?` when accessing accounts that may not exist yet

---

### Lesson 08 -- Month-End Cleanup: Adjustments and Accruals

**Story**: End of month. Your accountant aunt explains adjusting entries:
the stand depreciates, prepaid insurance must be spread across months,
and that neighbor who bought on credit moved away (bad debt). You also
learn the difference between accrual and cash accounting.

**Accounting concepts**:
- Adjusting entries: events recorded at period-end, not when cash moves
- Depreciation: spreading a fixed asset's cost over its useful life
- Prepaid expenses: you paid $6 for 3-month insurance, only $2 is this
  month's expense
- Bad debt: accounts receivable that will never be collected
- Accrual vs cash method

**jq features introduced**:
- `foreach` with running state ("like a column where each row depends
  on the row above -- running depreciation schedule")
- Generators and multiple outputs: `.[]` as a stream
- `empty` and backtracking (`select` is `if cond then . else empty end`)
- **Destructuring bind**: `. as {name, age}` and `. as [$first, $rest]`
  ("like unpacking a row into separate named cells")
- **`{$var}` shorthand** (jq 1.8): when you have `$name`, writing
  `{$name}` is equivalent to `{name: $name}`

**Data file**: `accounting/src/data/08-adjusting-entries.json`
- Depreciation schedule, prepaid insurance allocation, bad debt write-off

**jq program**: `accounting/src/programs/08-apply-adjustments.jq`
- Process each adjusting entry using destructuring
- Compute monthly depreciation using `foreach`
- Show before/after balance sheet

---

### Lesson 09 -- Following the Money: Cash Flow Statement

**Story**: Your aunt asks the critical question: "You made a profit, but
do you have enough cash?" The income statement says profit, but cash is
tight because it's tied up in inventory and receivables. You build the
third financial statement: the Cash Flow Statement.

**Accounting concepts**:
- The three sections: Operating, Investing, Financing
- Operating: cash from selling lemonade, paying for supplies
- Investing: buying the stand, the wagon
- Financing: bank loan received, loan repayment
- Net change in cash = beginning cash + all movements
- Profitable but cash-poor is possible (and dangerous)

**jq features introduced**:
- `reduce` with complex state (object accumulator)
- `foreach` for cumulative cash balance over time
- `group_by` + `map` pipeline ("SQL-style GROUP BY + aggregate")
- String formatting for reports
- **`while(cond; update)`**: loop while condition is true
  ("like filling cells down while a condition holds")
- **`until(cond; update)`**: loop until condition is true
  ("like Goal Seek -- keep adjusting until you hit the target")
- **`recurse(f; cond)`**: recursive iteration
- **Date functions**: `now`, `todate`, `strftime`, `strptime`,
  `mktime`, `fromdateiso8601`, `todateiso8601`, `gmtime`,
  `localtime`, `strflocaltime`
  ("like TODAY(), TEXT(date,format), DATEVALUE() in Excel")
- **`indices` / `index` / `rindex`**: finding positions in arrays
  and strings ("like MATCH() or FIND() in Excel")

**Data file**: `accounting/src/data/09-cash-movements.json`
- Every cash transaction tagged with section (operating/investing/financing)
- Transactions include dates for date-based grouping

**jq program**: `accounting/src/programs/09-cash-flow.jq`
- Classify and group cash movements
- Compute subtotals per section
- Show running cash balance using `while`/`until`
- Produce formatted cash flow statement
- Group cash movements by month using date functions

---

### Lesson 10 -- Checking Your Work: Trial Balance and Validation

**Story**: Before finalizing the books, you must verify everything.
Debits must equal credits. Account codes must follow the naming
convention. You find and fix errors in the ledger.

**Accounting concepts**:
- Trial balance: list all accounts, verify total debits = total credits
- Account number conventions (1xxx = assets, 2xxx = liabilities, etc.)
- Finding errors: transposition, omission, wrong account
- The general ledger as the single source of truth

**jq features introduced**:
- Regular expressions: `test`, `match`, `capture`
  ("like SEARCH() on steroids")
- **`scan`**: find all regex matches ("like extracting all matches")
- **`sub` / `gsub`**: regex replacement ("like SUBSTITUTE() in Excel")
- Error handling: `error("message")`
- Path expressions: `path()`, `paths()`, `getpath()`, `setpath()`
- **`delpaths`**: remove multiple paths at once
- **`..`**: recursive descent ("search all levels of nested data")

**Data file**: `accounting/src/data/10-general-ledger.json`
- Full ledger with some deliberate errors to find

**jq program**: `accounting/src/programs/10-validate-ledger.jq`
- Validate account codes match pattern `^[1-5]\d{3}$`
- Check every entry has debit == credit
- Use `gsub` to clean up malformatted account names
- Use `..` to find all amounts at any nesting level
- List all errors found
- Produce trial balance

---

### Lesson 11 -- The Full Picture: Financial Statements

**Story**: Month-end close. You generate all three statements from the
single ledger. You also export to CSV so your aunt can review in Excel.
You create a lookup table to join account names with codes.

**Accounting concepts**:
- The accounting cycle: transactions -> ledger -> trial balance ->
  adjustments -> financial statements
- How the three statements connect to each other
- Closing entries: resetting revenue/expense accounts for next period

**jq features introduced**:
- `INDEX(stream; key)` for lookup tables ("like VLOOKUP/XLOOKUP")
- `IN(stream)` for membership testing
- **`JOIN`**: SQL-style join of two arrays by key ("like VLOOKUP
  joining two tables")
- **`inside` and `contains`**: inclusion testing
- `@csv` and `@tsv` format strings ("export to Excel!")
- `input` / `inputs` for multi-file processing
- **`--rawfile`**: read a raw text file into a variable
- Advanced: `walk(f)` for tree-wide transformations
- **`ascii_downcase` / `ascii_upcase`**: case conversion
  ("like LOWER() / UPPER() in Excel")
- **`ltrimstr` / `rtrimstr` / `trimstr`**: trimming string
  prefixes/suffixes (`trimstr` trims from both ends, jq 1.8)
- **`trim` / `ltrim` / `rtrim`** (jq 1.8): whitespace trimming
  ("like TRIM() in Excel")
- **`startswith` / `endswith`**: string prefix/suffix testing

**Data file**: `accounting/src/data/11-full-month.json`
- Complete month: all transactions, all accounts, all adjustments

**jq program**: `accounting/src/programs/11-full-statements.jq`
- Build account lookup with INDEX
- Generate balance sheet, income statement, cash flow statement
- Normalize account names with `ascii_downcase` and `trim`
- Export each as CSV

---

### Lesson 12 -- Year in Review: Analysis and Comparison

**Story**: Summer is over. You compare all three months: June was
learning, July was growth, August was peak. You compute financial ratios
and see trends. You close the books for the season.

**Accounting concepts**:
- Comparative financial statements (month-over-month)
- Financial ratios: gross margin, net margin, current ratio, ROE
- Trend analysis: is the business improving?
- Closing the books for the season

**jq features introduced**:
- Multi-file processing with `jq -s` (slurp) and `inputs`
- **`--slurpfile`**: load a JSON file into a variable
- Modules: `import`, `include`, `def` in .jq library files
- Advanced `reduce` patterns
- `-c` (compact output) flag
- Streaming with `--stream`, `tostream`, `fromstream`,
  `truncate_stream` for large data
- `@base64`, `@base64d`, `@uri`, `@json` format strings
- `$ENV` and `env` for environment variables
- `debug` and `stderr` for troubleshooting
- **`transpose`**: zip arrays side by side ("like putting months in
  columns for side-by-side comparison")

**Data file**: `accounting/src/data/12-multi-period.json`
- Three months of data in one file (array of monthly summaries)

**jq program**: `accounting/src/programs/12-ratio-analysis.jq`
- Compute ratios per month
- Show month-over-month changes using `transpose`
- Generate comparative income statements
- Export final report

---

### Lesson 13 -- Appendix: Extra jq Features (Optional Reference)

**Story**: Your lemonade stand is closed for winter, but you keep
tinkering with jq. This appendix covers features that are useful to
know about but didn't fit naturally into the accounting workflow.

This lesson is **reference material**, not a linear tutorial. Dip into
the sections you need.

**Features covered**:

**String / Encoding**:
- `explode` / `implode`: convert strings to/from Unicode codepoint arrays
- `tojson` / `fromjson`: serialize/deserialize JSON within JSON
- `@sh`: shell-safe quoting for piping to bash
- `@html`: HTML entity escaping
- `splits(sep)`: generator version of `split` (produces each part as
  a separate output instead of an array)
- `utf8bytelength`: byte length of a string

**Math**:
- `nan`, `isinfinite`, `isnan`, `infinite`, `isfinite`, `isnormal`:
  IEEE float specials
- `fabs`, `floor`, `ceil`, `round`, `sqrt`, `pow`, `log`, `exp`
- `significand`, `exponent`, `logb`
- `remainder`, `fma`
- `atan`, `acos`, `asin`, `sin`, `cos`, `tan`, `cbrt`, etc.

**Array / Object Niche**:
- `combinations`: cartesian product of arrays
- `bsearch(val)`: binary search on sorted arrays
- `nth(n; expr)`: get the nth output of a generator
- `isempty(expr)`: test if a generator produces any output
- `finites` / `normals`: type selectors for finite / normal numbers
  (jq 1.8)
- `builtins`: list all built-in functions

**Advanced Control Flow**:
- `label-break`: early exit from generators -- how `limit` and `first`
  work internally
- `repeat(f)`: infinite loop that stops on error
- `$__loc__`: get current source location (for debugging)
- `halt` / `halt_error`: terminate jq execution

**I/O and Multi-File**:
- `--jsonargs`: pass JSON values as positional arguments
- `input_line_number` / `input_filename`: debugging streaming input
- `modulemeta`: inspect module metadata

**Data file**: `accounting/src/data/13-appendix-samples.json`
- Small standalone examples for each feature

**jq program**: `accounting/src/programs/13-appendix-demos.jq`
- Runnable demos of niche features

---

## Cross-Referencing Convention

**In tutorials (.md files)**, reference runnable examples like:

```
Try it yourself (from the project root):
  jq -f accounting/src/programs/03-sales-summary.jq accounting/src/data/03-daily-sales.json
```

**In jq programs (.jq files)**, include a header comment:

```jq
# Lesson 03 -- Sales Summary
# Tutorial: accounting/03-first-sales.md
# Data:     accounting/src/data/03-daily-sales.json
# Run:      jq -f accounting/src/programs/03-sales-summary.jq accounting/src/data/03-daily-sales.json
```

**In data files (.json)**, no comments (JSON doesn't support them), but
the filename matches the lesson number.

**Cross-links to developer tutorials**: When an accounting lesson
introduces a feature also covered in the developer track, include a
"Deep Dive" link: _"For more on `reduce`, see
[06-reduce-foreach.md](../06-reduce-foreach.md) in the developer
tutorials."_

---

## jq Feature Progression Map

| Lesson | jq Features | Excel Equivalent |
|--------|-------------|------------------|
| 01 | `.` `.field` `\|` `-r` `-n` `.field1.field2` | `=A1`, VLOOKUP, chaining formulas |
| 02 | `+ - * / %` `== != < >` `and or not` truthiness `type` `\(...)` `--arg` `tonumber` `tostring` `toboolean` `abs` `length` | Formulas, comparisons, AND/OR, TYPE(), VALUE(), ABS() |
| 03 | `.[]` `.[n]` `.[m:n]` `map` `select` `add` `length` `[...]` `,` `range` type selectors (`numbers` `strings` `iterables` etc) `first` `last` `limit` | INDEX, FILTER, SUM, COUNTA, SEQUENCE, drag-down |
| 04 | `sort_by` `sort` `reverse` `group_by` `unique` `unique_by` `min_by` `max_by` `min` `max` `to_entries` `from_entries` `{shorthand}` `skip` | Sort, Pivot Table, Remove Duplicates, MIN/MAX |
| 05 | `reduce` `as $var` `with_entries` `map_values` `keys` `values` `keys_unsorted` `has` `in` `//` `any` `all` `flatten` `add(gen)` `pick` `{($var): value}` | SUMIF, named cells, IFERROR, AND/OR, column headers |
| 06 | `if-then-else` `if` (no else) `def` `def f(x)` `try-catch` `split` `join` | IF/IFS, named formulas, IFERROR, TEXTSPLIT |
| 07 | `\|=` `+=` `-=` `del` `.path = val` `//=` `?` `try` (no catch) | Edit cell, delete column, defaults, IFERROR |
| 08 | `foreach` `empty` generators destructuring `{$var}` shorthand | Running totals, unpacking rows |
| 09 | `while` `until` `recurse` `reduce` (complex) `foreach` (cumulative) `group_by\|map` date functions (`strftime` `gmtime` `localtime` `strflocaltime` etc) `indices/index/rindex` | Goal Seek, running balance, MATCH, date functions |
| 10 | `test` `match` `capture` `scan` `sub` `gsub` `path` `paths` `getpath` `setpath` `delpaths` `..` `error` | SEARCH, SUBSTITUTE, data validation |
| 11 | `INDEX` `IN` `JOIN` `contains` `inside` `@csv` `@tsv` `input/inputs` `--rawfile` `walk` `ascii_downcase/upcase` `ltrimstr/rtrimstr/trimstr` `trim/ltrim/rtrim` `startswith/endswith` | VLOOKUP, JOIN, export CSV, LOWER/UPPER, TRIM |
| 12 | `-s` `-c` `--slurpfile` modules `--stream` `tostream/fromstream/truncate_stream` `@base64` `@uri` `@json` `$ENV` `debug` `stderr` `transpose` | Multi-sheet, Power Query, ZIP columns |
| 13 | `explode/implode` `tojson/fromjson` `@sh` `@html` `splits` math builtins `nth` `isempty` `finites` `normals` `combinations` `bsearch` `repeat` `label-break` `builtins` `$__loc__` `halt` | (Reference appendix) |

---

## Accounting Concept Progression Map

| Lesson | Accounting Concepts | Book Chapter |
|--------|---------------------|--------------|
| 01 | Accounting equation, chart of accounts, journal entry | Ch 1 |
| 02 | Assets change form, cost tracking | Ch 1 |
| 03 | Revenue recognition, sales recording | Ch 1-2 |
| 04 | Transaction classification, period reporting | Ch 1-2 |
| 05 | Balance sheet, A=L+OE, snapshot in time | Ch 1-2 |
| 06 | Income statement, Sales-COGS-Expenses=NI | Ch 2 |
| 07 | Liabilities, loans, A/R, credit sales, retained earnings | Ch 3-4 |
| 08 | Adjusting entries, depreciation, prepaid, bad debt, accrual vs cash | Ch 4 |
| 09 | Cash flow statement, operating/investing/financing | Ch 7 |
| 10 | Trial balance, general ledger, error detection | Ch 6 |
| 11 | Full accounting cycle, closing entries | Ch 7 |
| 12 | Comparative statements, financial ratios, trend analysis | Ch 8-9 |

> **Note on ordering**: In the standard accounting cycle, trial balance
> (L10) comes before adjusting entries (L08). This plan deliberately
> teaches the individual financial statements first (L05-L09) so the
> reader has something meaningful to validate. Trial balance is presented
> as "checking your work" after the reader understands what the statements
> should look like.

---

## Implementation Order

Phase 1 -- Foundation (lessons 01-03):
  Create data files first, then jq programs, then tutorials.
  These cover basic jq and basic accounting.

Phase 2 -- Core Statements (lessons 04-06):
  The pivot from raw transactions to financial statements.
  Most important section for both audiences.

Phase 3 -- Complexity (lessons 07-09):
  Business grows, accounting gets real.
  jq features match the complexity.

Phase 4 -- Mastery (lessons 10-13):
  Validation, full cycle, analysis, and reference appendix.
  Advanced jq for professional-grade work.

Each lesson should be implementable independently once its
data file exists, since later data files build on earlier ones.

---

## Open Questions

1. Should the data files use double-entry (debit/credit objects) from
   the start, or introduce that gradually? **Recommendation**: Start
   with simple {account, amount, type} in lessons 1-4, introduce
   proper debit/credit in lesson 5 when balance sheet demands it.

2. Should there be a `accounting/src/lib/` directory for shared jq
   functions? **Recommendation**: Yes, add `accounting/src/lib/accounting.jq`
   in lesson 11 when modules are taught. Earlier lessons keep functions inline.

3. How much narrative prose vs code? **Recommendation**: Follow the
   book's style -- short narrative paragraphs that set up "now try
   this" code blocks. Never more than 3 paragraphs before a code example.
