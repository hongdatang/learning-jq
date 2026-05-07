# Lesson 06 -- Did We Make Money? The Income Statement

## The Story So Far

In the last five lessons you set up your lemonade stand, bought supplies, made
sales, grouped them by day, and produced a balance sheet. The balance sheet told
you what you **have** at one moment in time -- a photograph of your finances.

But a photograph does not tell you whether the business is working. Did the
lemonade stand actually make money this week, or did you lose your shirt?

That question is what the **income statement** answers.

> **The analogy**: The balance sheet is a **photograph** -- a snapshot frozen at
> one instant. The income statement is a **movie** -- it covers a span of time
> (a week, a month, a quarter) and shows the flow of money in and out.

Your mom looks at your notebook at the end of Week 1 and says: "Let's figure
out if we actually made money."

---

## Accounting Sidebar: The Income Statement

The income statement follows a simple top-to-bottom structure. Each line
subtracts something from the line above:

```
  Sales Revenue               $22.00    (what customers paid you)
- Cost of Goods Sold          $10.00    (what those cups of lemonade cost to make)
= Gross Profit                $12.00    (revenue minus direct costs)
- Operating Expenses           $5.00    (wages, advertising, etc.)
= Net Income                   $7.00    (the bottom line -- your actual profit)
```

> **Excel analogy**: Think of this as a spreadsheet with five rows. Each row is
> a formula:
> - B1 = SUM of all sales
> - B2 = total ingredients cost
> - B3 = B1 - B2
> - B4 = SUM of expense items
> - B5 = B3 - B4

Two ratios tell you how efficient the business is:

- **Gross Margin** = Gross Profit / Revenue = $12 / $22 = 54.5%
  (How much of each dollar is left after paying for ingredients)
- **Net Margin** = Net Income / Revenue = $7 / $22 = 31.8%
  (How much of each dollar is actual profit)

---

## The Data

Open `accounting/src/data/06-income-data-week1.json`. Here is what Week 1
looks like:

```json
{
  "period": "Week 1",
  "start_date": "2024-06-01",
  "end_date": "2024-06-05",
  "sales": [
    { "date": "2024-06-01", "cups": 5,  "unit_price": 1.00, "revenue": 5.00 },
    { "date": "2024-06-02", "cups": 8,  "unit_price": 1.00, "revenue": 8.00 },
    { "date": "2024-06-03", "cups": 3,  "unit_price": 1.00, "revenue": 3.00 },
    { "date": "2024-06-03", "cups": 2,  "unit_price": 1.50, "revenue": 3.00 },
    { "date": "2024-06-04", "cups": 2,  "unit_price": 1.00, "revenue": 2.00 },
    { "date": "2024-06-05", "cups": 1,  "unit_price": 1.00, "revenue": 1.00 }
  ],
  "cost_of_goods": { "cups_sold": 21, "cost_per_cup": 0.50, "total_cogs": 10.00 },
  "expenses": [
    { "category": "Wages",       "description": "Friend helped Monday", "amount": 3.00 },
    { "category": "Advertising", "description": "Cardboard sign",       "amount": 2.00 }
  ]
}
```

Notice June 3 has two entries (regular and premium cups), and June 5 was a
slow day -- only one cup sold. These will become useful when we learn `if`.

---

## New jq Feature: Defining Functions (`def`)

So far, every jq expression has been a one-off formula. That is like typing a
formula directly into a cell every time you need it. But what if you use the
same calculation in ten places?

> **Excel analogy**: `def` is like creating a named formula in VBA, or defining
> a Name in the Name Manager. Instead of typing `=SUM(B2:B10)-SUM(C2:C10)`
> everywhere, you give it a name and reuse it.

### A Function With No Arguments

```bash
jq -n 'def greet: "Hello, Lemonade Stand!"; greet'
# "Hello, Lemonade Stand!"
```

The syntax: `def NAME: BODY;` -- note the **semicolon** at the end.

A function receives its input through `.` (the dot), just like every jq
filter:

```bash
jq 'def total_revenue: .sales | map(.revenue) | add; total_revenue' \
  accounting/src/data/06-income-data-week1.json
# 22
```

This reads: "define `total_revenue` as: take `.sales`, extract each
`.revenue`, and `add` them up." Then call it.

### Functions With Arguments

Separate arguments with **semicolons** (not commas -- commas mean something
else in jq):

```bash
jq -n 'def margin(part; whole): part / whole * 100; margin(12; 22)'
# 54.54545454545454
```

> **Excel analogy**: `def margin(part; whole)` is like `Function margin(part,
> whole)` in VBA. The semicolons are jq's separator -- just pretend they are
> commas.

### Functions Calling Functions (Composability)

This is where things get powerful. Build small functions, then combine them:

```bash
jq '
  def total_revenue: .sales | map(.revenue) | add;
  def cogs:          .cost_of_goods.total_cogs;
  def gross_profit:  total_revenue - cogs;

  gross_profit
' accounting/src/data/06-income-data-week1.json
# 12
```

`gross_profit` calls `total_revenue` and `cogs` -- just like a cell formula
referencing other named cells. Each function is small and readable on its own,
and you assemble them into bigger calculations.

For a deeper dive into function definitions, see
[07-functions.md](../07-functions.md) in the developer tutorials.

---

## New jq Feature: `if-then-elif-else-end`

> **Excel analogy**: `if-then-elif-else-end` is exactly like nested `IF()`
> formulas:
> ```
> =IF(A1=0, "No sales", IF(A1>=8, "Great", IF(A1>=5, "Good", "Slow")))
> ```

### Basic `if`

```bash
echo '8' | jq 'if . >= 8 then "Great day!" elif . >= 5 then "Good day" else "Slow day" end'
# "Great day!"
```

The full form: `if CONDITION then VALUE elif CONDITION then VALUE else VALUE end`.

Let's classify each sales day:

```bash
jq '.sales[] | if .revenue >= 8 then "Great"
               elif .revenue >= 5 then "Good"
               elif .revenue >= 3 then "Okay"
               else "Slow"
               end' accounting/src/data/06-income-data-week1.json
# "Good"
# "Great"
# "Okay"
# "Okay"
# "Slow"
# "Slow"
```

### `if` Without `else` (jq 1.8)

New in jq 1.8: if you leave out `else`, the input passes through unchanged
when the condition is false. This is called the **identity default**.

```bash
echo '5' | jq 'if . > 10 then "big" end'
# 5  -- condition false, input (5) passes through unchanged
```

> **Excel analogy**: `=IF(A1>10, "big", A1)` -- when the condition is false,
> you get the original value back. The `if`-without-`else` does this
> automatically.

This is handy for selectively transforming data. Here is a pattern: use
`if-without-else` to convert matching items to strings, then filter with
`strings` to keep only the converted ones:

```bash
jq '[.sales[] | if .revenue > 0 then .date end | strings]' \
  accounting/src/data/06-income-data-week1.json
# ["2024-06-01","2024-06-02","2024-06-03","2024-06-03","2024-06-04","2024-06-05"]
```

In our data all days had at least one sale, so every date passes through. If
a day had zero revenue, its full object would pass through instead -- and
`strings` would filter it out because an object is not a string. The code is
still valid and would filter correctly if a zero-revenue day appeared.

For more on conditionals, see [04-control-flow.md](../04-control-flow.md) in
the developer tutorials.

---

## New jq Feature: `try-catch`

> **Excel analogy**: `try-catch` is `IFERROR()`. Try a formula; if it errors,
> use a fallback value instead of crashing.
> ```
> =IFERROR(A1/B1, "Cannot divide")
> ```

```bash
echo 'null' | jq 'try (100 / 0) catch "Cannot divide"'
# "Cannot divide"
```

Without `try`, dividing by zero would crash. With `try-catch`, you get a
graceful fallback.

This is useful in accounting when data might be missing or a denominator might
be zero:

```bash
jq '
  def safe_divide(numerator; denominator):
    try (numerator / denominator) catch "N/A";
  safe_divide(.cost_of_goods.total_cogs; .cost_of_goods.cups_sold)
' accounting/src/data/06-income-data-week1.json
# 0.5
```

If `cups_sold` were zero, you would get `"N/A"` instead of an error.

### `try` Without `catch`

You can also use `try` alone. If the expression errors, it silently produces
no output (like a row that gets filtered out):

```bash
echo '["1", "two", "3"]' | jq '[.[] | try tonumber]'
# [1, 3]
```

`"two"` could not be converted to a number, so `try` silently skipped it.

---

## New jq Feature: `split` and `join`

> **Excel analogy**: `split` is `TEXTSPLIT()` -- break a string apart at a
> delimiter. `join` is `TEXTJOIN()` -- glue an array of strings together.

### `split`: String to Array

```bash
echo '"Wages, Advertising, Rent"' | jq 'split(", ")'
# ["Wages", "Advertising", "Rent"]
```

### `join`: Array to String

```bash
echo '["Wages", "Advertising", "Rent"]' | jq 'join(" + ")'
# "Wages + Advertising + Rent"
```

### Together: Reshape Text

```bash
echo '"2024-06-01"' | jq 'split("-") | join("/")'
# "2024/06/01"
```

In the income statement program, we use these to format expense categories:

```bash
jq '[.expenses[].category] | join(", ")' \
  accounting/src/data/06-income-data-week1.json
# "Wages, Advertising"
```

### Dollar Formatting With `split`

The `dollars` function in the program uses `split(".")` to ensure two decimal
places -- a practical use of `split` and `join` together:

```bash
jq -n '22 | tostring | split(".")
         | if length == 1 then .[0] + ".00"
           elif (.[1] | length) == 1 then join(".") + "0"
           else join(".")
           end'
# "22.00"
```

This handles all cases: `22` becomes `"22.00"`, `10.5` becomes `"10.50"`, and
`1.05` stays `"1.05"`.

---

## Putting It All Together: The Income Statement Program

Run the full program:

```bash
jq -rf accounting/src/programs/06-income-statement.jq \
  accounting/src/data/06-income-data-week1.json
```

Expected output:

```
==================================================
  INCOME STATEMENT
  Week 1: 2024-06-01 to 2024-06-05
==================================================

--- Revenue ---
  Sales Revenue:        $22.00

--- Cost of Goods Sold ---
  COGS (21 cups x $0.50/cup): $10.00

--- Gross Profit ---
  Gross Profit:         $12.00
  Gross Margin:         54.5%

--- Operating Expenses ---
  Wages: $3.00  (Friend helped Monday)
  Advertising: $2.00  (Cardboard sign)
  --------------------------
  Total Expenses:       $5.00

==================================================
  NET INCOME:           $7.00
  Net Margin:           31.8%
==================================================

--- Daily Breakdown ---
  2024-06-01: 5 cups, $5.00 -- Good day
  2024-06-02: 8 cups, $8.00 -- Great day!
  2024-06-03: 3 cups, $3.00 -- Okay day
  2024-06-03: 2 cups, $3.00 -- Okay day
  2024-06-04: 2 cups, $2.00 -- Slow day
  2024-06-05: 1 cups, $1.00 -- Slow day

--- Active Sales Days (if-without-else demo) ---
  Days with sales: 2024-06-01, 2024-06-02, 2024-06-03, 2024-06-04, 2024-06-05

--- Expense Categories (split/join demo) ---
  All categories: Wages, Advertising
  Reversed:       Advertising + Wages

--- Safe Division (try-catch demo) ---
  Revenue per cup: $1.05
  Division by zero test: Error: division failed
```

### Walking Through the Program

Open `accounting/src/programs/06-income-statement.jq` and follow along:

**Functions (lines 10-56)** -- Six `def` statements at the top, each one
small and composable:

| Function | Does | Calls |
|----------|------|-------|
| `total_revenue` | Sums `.sales[].revenue` | -- |
| `cogs` | Reads `.cost_of_goods.total_cogs` | -- |
| `gross_profit` | Revenue minus COGS | `total_revenue`, `cogs` |
| `total_expenses` | Sums `.expenses[].amount` | -- |
| `net_income` | Gross profit minus expenses | `gross_profit`, `total_expenses` |
| `dollars` | Formats `7` as `"$7.00"` | uses `split`, `join` |
| `margin(part; whole)` | Calculates a percentage | uses `if-then-else` |
| `day_rating` | Classifies a day | uses `if-then-elif-else` |
| `safe_divide(n; d)` | Division with error handling | uses `try-catch` |

**Output (lines 58+)** -- Each section calls the functions and formats the
result. The pattern is always: bind a value with `as $var`, then use
string interpolation `\($var | dollars)` to format it.

---

## What We Learned

| jq | Excel equivalent | What it does |
|----|-------------------|-------------|
| `def name: body;` | Named formula / VBA Function | Define a reusable calculation |
| `def f(x; y): ...;` | Function with parameters | Reusable calculation with inputs |
| `if-then-elif-else-end` | Nested `IF()` | Branch based on conditions |
| `if ... then ... end` | `IF(cond, val, cell)` | Branch; false returns input unchanged |
| `try EXPR catch VAL` | `IFERROR(expr, val)` | Handle errors gracefully |
| `try EXPR` | (skip errored rows) | Silently drop errors |
| `split(sep)` | `TEXTSPLIT(text, sep)` | Break a string into an array |
| `join(sep)` | `TEXTJOIN(sep, TRUE, arr)` | Glue an array into a string |

---

## Exercises

All exercises use `accounting/src/data/06-income-data-week1.json`.

### 1. Write a Profit Check Function

Define a function `def profitable:` that returns `true` if `net_income > 0`
and `false` otherwise. Call it.

### 2. Classify Expenses

Use `if-then-elif-else` to classify each expense as `"labor"` (Wages) or
`"marketing"` (Advertising) or `"other"`. Print each expense with its
classification.

### 3. Safe Margin Calculation

Write a function `def safe_margin:` that takes the whole data as input and
returns the net margin as a string (e.g., `"31.8%"`), but returns `"N/A"` if
revenue is zero. Use `try-catch` or an `if` check.

Test it on the real data, then test it with: `echo '{"sales":[], "cost_of_goods":{"total_cogs":0}, "expenses":[]}' | jq 'YOUR_EXPRESSION'`

### 4. Reformat Dates With `split` and `join`

Take each sales date (`"2024-06-01"`) and reformat it as `"Jun 01"`. Hint:
`split("-")` to get `["2024","06","01"]`, then use `if` to convert the month
number to a name, then `join` the pieces.

### 5. Daily Revenue With Fallback

Print each day's revenue per cup. Use `try-catch` so that if any day had
zero cups, you would get `"N/A"` instead of crashing on division by zero.

<details>
<summary>Solutions</summary>

```bash
# 1. Profit check function
jq '
  def total_revenue: .sales | map(.revenue) | add;
  def cogs: .cost_of_goods.total_cogs;
  def gross_profit: total_revenue - cogs;
  def total_expenses: .expenses | map(.amount) | add;
  def net_income: gross_profit - total_expenses;
  def profitable: net_income > 0;
  profitable
' accounting/src/data/06-income-data-week1.json
# true

# 2. Classify expenses
jq '.expenses[] |
  if .category == "Wages" then . + {"type": "labor"}
  elif .category == "Advertising" then . + {"type": "marketing"}
  else . + {"type": "other"}
  end |
  "\(.category) (\(.type)): $\(.amount)"
' accounting/src/data/06-income-data-week1.json
# "Wages (labor): $3.00"
# "Advertising (marketing): $2.00"

# 3. Safe margin calculation
jq '
  def total_revenue: .sales | map(.revenue) | add;
  def cogs: .cost_of_goods.total_cogs;
  def gross_profit: total_revenue - cogs;
  def total_expenses: .expenses | map(.amount) | add;
  def net_income: gross_profit - total_expenses;
  def safe_margin:
    total_revenue as $rev |
    if $rev == 0 or $rev == null then "N/A"
    else ((net_income / $rev * 1000 | floor) / 10 | tostring) + "%"
    end;
  safe_margin
' accounting/src/data/06-income-data-week1.json
# "31.8%"

# Test with empty data:
echo '{"sales":[],"cost_of_goods":{"total_cogs":0},"expenses":[]}' | jq '
  def total_revenue: .sales | map(.revenue) | add;
  def cogs: .cost_of_goods.total_cogs;
  def gross_profit: total_revenue - cogs;
  def total_expenses: .expenses | map(.amount) | add;
  def net_income: gross_profit - total_expenses;
  def safe_margin:
    total_revenue as $rev |
    if $rev == 0 or $rev == null then "N/A"
    else ((net_income / $rev * 1000 | floor) / 10 | tostring) + "%"
    end;
  safe_margin
'
# "N/A"

# 4. Reformat dates
jq '.sales[].date | split("-") | .[1:] |
  (if .[0] == "06" then "Jun" elif .[0] == "07" then "Jul" else .[0] end)
    as $month |
  "\($month) \(.[1])"
' accounting/src/data/06-income-data-week1.json
# "Jun 01"
# "Jun 02"
# "Jun 03"
# "Jun 03"
# "Jun 04"
# "Jun 05"

# 5. Daily revenue with fallback
jq '.sales[] |
  "\(.date): " + (try "\(.revenue / .cups | . * 100 | round / 100)/cup"
                   catch "N/A (no sales)")
' accounting/src/data/06-income-data-week1.json
# "2024-06-01: 1/cup"
# "2024-06-02: 1/cup"
# "2024-06-03: 1/cup"
# "2024-06-03: 1.5/cup"
# "2024-06-04: 1/cup"
# "2024-06-05: 1/cup"
```

</details>

---

## Next Lesson

In [Lesson 07 -- Growing the Business](07-growing-the-business.md), the
lemonade stand takes out a loan and starts selling on credit. You will learn
`|=`, `+=`, `del`, and the optional operator `?` -- tools for updating and
reshaping data in place.

---

## Deep Dive

- Conditionals: [04-control-flow.md](../04-control-flow.md)
- Functions: [07-functions.md](../07-functions.md)
- The developer tutorials cover these features with Python analogies and
  additional edge cases.
