# Lesson 05 -- Counting the Money: The Balance Sheet

## The Story

It is Wednesday evening, June 5th. Your first week running the lemonade stand
is done. You sold 20 cups of lemonade, paid your friend $3 for helping out, and
spent $2 on a cardboard sign. Your mom sits down with you at the kitchen table.

"Good week," she says. "Now let's count everything. How much cash do you have?"

You dump out the cash box and count: $57.

"And how much lemonade mix is left?"

You check the pitcher. Empty -- all 20 cups' worth of supplies got used up.
Inventory: $0.

"OK," she says. "Now let's build your first balance sheet. Think of it as a
**photograph** of the business -- everything you own, everything you owe, and
where the money came from, frozen at one moment in time."

---

## The Data

Open `accounting/src/data/05-balance-sheet-week1.json` and look at it:

```bash
jq '.' accounting/src/data/05-balance-sheet-week1.json
```

```json
{
  "period": "Week 1",
  "date": "2024-06-05",
  "accounts": {
    "cash":              { "code": "1000", "type": "asset",   "balance": 57.00 },
    "inventory":         { "code": "1200", "type": "asset",   "balance": 0.00 },
    "owners_equity":     { "code": "3000", "type": "equity",  "balance": 50.00 },
    "retained_earnings": { "code": "3100", "type": "equity",  "balance": 7.00 }
  },
  "income_summary": {
    "revenue": 22.00,
    "cogs": 10.00,
    "wages": 3.00,
    "advertising": 2.00,
    "net_income": 7.00
  }
}
```

Where did these numbers come from?

| Event | Cash effect |
|-------|-------------|
| Started with savings | +$50.00 |
| Bought supplies (lemons, sugar, cups) | -$10.00 |
| Sold 20 cups at various prices | +$22.00 |
| Paid friend for helping | -$3.00 |
| Bought a sign | -$2.00 |
| **Cash on hand** | **$57.00** |

And the net income: $22.00 revenue - $10.00 supplies - $3.00 wages - $2.00
sign = **$7.00 profit**.

---

## Accounting Sidebar: The Balance Sheet

A balance sheet answers three questions at a specific moment:

1. **What does the business own?** (Assets)
2. **What does the business owe?** (Liabilities)
3. **Where did the money come from?** (Owner's Equity)

The fundamental rule of accounting -- the one that must always hold:

```
Assets = Liabilities + Owner's Equity
```

For our lemonade stand at June 5th:

```
$57 = $0 + $57
```

Assets are $57 (cash $57 + inventory $0). Liabilities are $0 (you do not owe
anyone anything). Owner's equity is $57: the $50 you invested plus $7 in
retained earnings (profit the business kept).

> **Key distinction**: The income statement (Lesson 06) covers a *period* of
> time ("How did we do this week?"). The balance sheet is a *snapshot* at one
> moment ("What do we have right now?"). The income statement is a movie; the
> balance sheet is a photograph.

---

## New jq Concept: `reduce`

Up to now, you have used `add` to sum arrays. `add` is convenient, but what if
you need more control -- like summing only certain items, or building an object
instead of a number? That is what `reduce` does.

> **Excel analogy**: `add` is like the `SUM()` function -- one step, one answer.
> `reduce` is like writing your own SUM by hand in a helper column: start with
> 0 in cell B1, then B2 = B1 + A1, B3 = B2 + A2, and so on. You control what
> happens at each step.

### Syntax

```
reduce GENERATOR as $var (INIT; UPDATE)
```

- **GENERATOR** -- produces a stream of values (like `.[]` or `range(5)`)
- **$var** -- the name for the current value (like "the cell I am looking at")
- **INIT** -- the starting value (like the 0 in your helper column)
- **UPDATE** -- what to do each step (`.` is the running total, `$var` is the current item)

### Example: sum an array

```bash
echo '[57, 0, 50, 7]' | jq 'reduce .[] as $x (0; . + $x)'
```

```
114
```

Step by step:

| Step | $x | Running total (`.`) | After update |
|------|----|---------------------|--------------|
| Start | -- | 0 | 0 |
| 1 | 57 | 0 | 0 + 57 = 57 |
| 2 | 0 | 57 | 57 + 0 = 57 |
| 3 | 50 | 57 | 57 + 50 = 107 |
| 4 | 7 | 107 | 107 + 7 = 114 |

That is identical to `[57, 0, 50, 7] | add`. The power of `reduce` shows when
the logic gets more interesting.

### Example: classify accounts by type

This is the core of our balance sheet program. We loop through each account and
drop it into a bucket based on its type:

```bash
jq '
  .accounts | to_entries
  | reduce .[] as $acct (
      { "asset": {}, "liability": {}, "equity": {} };
      .[$acct.value.type] += { ($acct.key): $acct.value.balance }
    )
' accounting/src/data/05-balance-sheet-week1.json
```

```json
{
  "asset": {
    "cash": 57,
    "inventory": 0
  },
  "liability": {},
  "equity": {
    "owners_equity": 50,
    "retained_earnings": 7
  }
}
```

> **Excel analogy**: This is like building a pivot table by hand. You start with
> three empty sections (asset, liability, equity), then go through each account
> and write its balance in the correct section.

Two new things appear in that `reduce`:

1. **Computed keys `{($acct.key): $acct.value.balance}`** -- the parentheses
   around `$acct.key` tell jq "use the *value* of this variable as the key
   name." Without parentheses, jq would literally use the text `$acct.key` as
   the key.

2. **`+=`** -- adds to the existing object at that position. Each step
   accumulates one more account into the right bucket.

---

## New jq Concept: `as $var` (Variable Binding)

You have already seen `$var` inside `reduce`. But you can also use `as $var`
anywhere in a pipeline to name a result for later use.

> **Excel analogy**: `as $var` is like naming a cell. In Excel, you might name
> cell B10 as `TotalAssets` so you can write `=TotalAssets` in formulas instead
> of `=$B$10`. Same idea: compute something, give it a name, use the name.

### Syntax

```
EXPRESSION as $name | ... rest of pipeline ...
```

The value of EXPRESSION gets stored in `$name`. The original input (`.`) flows
through unchanged -- `as` does not consume or modify the data.

### Example: name and reuse multiple totals

```bash
jq '
  .accounts | map_values(.balance)
  | (.cash + .inventory) as $total_assets
  | (.owners_equity + .retained_earnings) as $total_equity
  | "Assets: $\($total_assets), Equity: $\($total_equity)"
' accounting/src/data/05-balance-sheet-week1.json
```

```
"Assets: $57, Equity: $57"
```

Each `as $var |` is a step that *names* a result. You can stack as many as you
need -- the pipeline reads top to bottom like a series of Excel formulas that
reference each other.

---

## New jq Concept: `//` (The Alternative Operator)

What happens when you look up an account that does not exist?

```bash
jq '.accounts.loan' accounting/src/data/05-balance-sheet-week1.json
```

```
null
```

You get `null` -- jq's version of a blank cell. But `null` can cause problems
in math (`null + 5` is `5`, which is fine, but `null == 0` is `false`, which
can surprise you).

The `//` operator provides a fallback value when the left side is `null` or
`false`.

> **Excel analogy**: `//` is like `IFERROR()` or `IFNA()`. In Excel, you write
> `=IFERROR(VLOOKUP(...), 0)` to get 0 when the lookup fails. In jq, you write
> `.accounts.loan // 0` to get 0 when the account does not exist.

```bash
jq '.accounts.loan.balance // 0' accounting/src/data/05-balance-sheet-week1.json
```

```
0
```

```bash
jq '.accounts.cash.balance // 0' accounting/src/data/05-balance-sheet-week1.json
```

```
57
```

The cash account exists, so `//` does nothing. The loan account does not exist,
so `//` kicks in and returns 0.

### Common pattern: safe summation

```bash
jq '
  .accounts | [to_entries[] | select(.value.type == "liability") | .value.balance]
  | add // 0
' accounting/src/data/05-balance-sheet-week1.json
```

```
0
```

Without `// 0`, `add` on an empty array returns `null`. With it, you get a
clean 0. This is the same reason you write `=IFERROR(SUM(range), 0)` in Excel
when a range might be empty.

---

## Object Inspection: `keys`, `values`, `has`, `in`

These functions let you look at the structure of your data.

### `keys` -- list all the column headers (sorted alphabetically)

```bash
jq '.accounts | keys' accounting/src/data/05-balance-sheet-week1.json
```

```json
["cash", "inventory", "owners_equity", "retained_earnings"]
```

> **Excel analogy**: `keys` is like reading the column headers across row 1.

### `keys_unsorted` -- same thing, but in original order

```bash
jq '.accounts | keys_unsorted' accounting/src/data/05-balance-sheet-week1.json
```

```json
["cash", "inventory", "owners_equity", "retained_earnings"]
```

In this file the keys happen to be in alphabetical order already, but
`keys_unsorted` preserves whatever order the JSON file used. Use it when order
matters (like printing a report where you want "cash" before "inventory").

### `values` -- list all the cell values (no headers)

```bash
jq '.accounts | map_values(.balance) | values' accounting/src/data/05-balance-sheet-week1.json
```

```json
[57, 0, 50, 7]
```

### `has(key)` -- does this column exist?

```bash
jq '.accounts | has("cash")' accounting/src/data/05-balance-sheet-week1.json
```

```
true
```

```bash
jq '.accounts | has("loan")' accounting/src/data/05-balance-sheet-week1.json
```

```
false
```

> **Excel analogy**: `has("cash")` is like `=NOT(ISNA(MATCH("cash", headers, 0)))`.

### `in(object)` -- reverse of `has`

`has` asks "does this object have that key?" `in` asks "is this key in that
object?" Same question, different direction:

```bash
jq -n '"cash" | in({"cash": 57, "inventory": 0})'
```

```
true
```

---

## Transforming Objects: `map_values` and `with_entries`

### `map_values(f)` -- apply a formula to every cell in a row

```bash
jq '.accounts | map_values(.balance)' accounting/src/data/05-balance-sheet-week1.json
```

```json
{
  "cash": 57,
  "inventory": 0,
  "owners_equity": 50,
  "retained_earnings": 7
}
```

> **Excel analogy**: `map_values(.balance)` is like having a formula that
> extracts one field from each column. If your accounts are in columns B through
> E and each column has "code", "type", and "balance" rows, `map_values` grabs
> just the "balance" row from every column at once. It is like dragging a
> formula across a row.

### `with_entries(f)` -- filter or transform key-value pairs

`with_entries` is the power tool. It converts each key-value pair into an object
`{"key": ..., "value": ...}`, lets you modify or filter them, and converts back.

```bash
jq '.accounts | with_entries(select(.value.type == "asset"))' \
  accounting/src/data/05-balance-sheet-week1.json
```

```json
{
  "cash": {
    "code": "1000",
    "type": "asset",
    "balance": 57
  },
  "inventory": {
    "code": "1200",
    "type": "asset",
    "balance": 0
  }
}
```

> **Excel analogy**: `with_entries(select(...))` is like using AutoFilter on a
> spreadsheet. You set a filter on the "type" column to show only "asset" rows,
> and everything else is hidden.

---

## Checking Conditions: `any(f)` and `all(f)`

### `any(f)` -- is at least one item true? (like `OR()` in Excel)

```bash
jq '[.accounts[].balance] | any(. > 0)' accounting/src/data/05-balance-sheet-week1.json
```

```
true
```

At least one account has a positive balance. That is `=OR(B2>0, C2>0, D2>0, E2>0)`.

### `all(f)` -- are all items true? (like `AND()` in Excel)

```bash
jq '[.accounts[].balance] | all(. >= 0)' accounting/src/data/05-balance-sheet-week1.json
```

```
true
```

No negative balances. That is `=AND(B2>=0, C2>=0, D2>=0, E2>=0)`.

### Verifying the accounting equation

```bash
jq '
  .accounts | map_values(.balance)
  | (.cash + .inventory) as $a
  | 0 as $l
  | (.owners_equity + .retained_earnings) as $oe
  | [($a == $l + $oe)]
  | all
' accounting/src/data/05-balance-sheet-week1.json
```

```
true
```

---

## Working with Nested Arrays: `flatten`

Sometimes data comes in nested layers. `flatten` removes the nesting.

```bash
echo '[[1, 2], [3, [4, 5]]]' | jq 'flatten'
```

```json
[1, 2, 3, 4, 5]
```

Control how deep to flatten with `flatten(depth)`:

```bash
echo '[[1, 2], [3, [4, 5]]]' | jq 'flatten(1)'
```

```json
[1, 2, 3, [4, 5]]
```

> **Excel analogy**: Imagine you have sub-totals within groups. `flatten` is
> like removing the grouping to get one flat list of all the numbers.

### Accounting use: combining account lists from multiple categories

```bash
jq '
  [
    [.accounts | with_entries(select(.value.type == "asset"))  | keys],
    [.accounts | with_entries(select(.value.type == "equity")) | keys]
  ] | flatten
' accounting/src/data/05-balance-sheet-week1.json
```

```json
["cash", "inventory", "owners_equity", "retained_earnings"]
```

---

## jq 1.8 Features: `pick` and `add(generator)`

### `pick(.field1, .field2)` -- extract a subset of fields

```bash
jq '.accounts | pick(.cash, .inventory)' accounting/src/data/05-balance-sheet-week1.json
```

```json
{
  "cash": {
    "code": "1000",
    "type": "asset",
    "balance": 57
  },
  "inventory": {
    "code": "1200",
    "type": "asset",
    "balance": 0
  }
}
```

> **Excel analogy**: `pick` is like hiding columns you do not need. Select
> columns B and C, right-click, "Hide" the rest. You keep the data for just the
> columns you picked.

### `add(generator)` -- sum a stream without collecting it first

In earlier lessons, you wrote `[.sales[].total] | add` -- collect into an
array, then sum. With jq 1.8, you can skip the array:

```bash
jq -n 'add(range(1; 6))'
```

```
15
```

That sums 1 + 2 + 3 + 4 + 5 without ever building an array. For large data
sets, this is more efficient.

```bash
jq 'add(.accounts[].balance)' accounting/src/data/05-balance-sheet-week1.json
```

```
114
```

That is the sum of all account balances (57 + 0 + 50 + 7 = 114). Of course,
that number is not meaningful on its own -- you would not add assets and equity
together in real accounting -- but it shows how `add(generator)` works.

---

## Run the Program

```bash
jq -rf accounting/src/programs/05-build-balance-sheet.jq \
  accounting/src/data/05-balance-sheet-week1.json
```

Expected output:

```
=========================================
  LEMONADE STAND -- BALANCE SHEET
  Week 1 -- June 5, 2024
=========================================

ASSETS
------------------------------
  cash          $57
  inventory          $0
                        ----------
  TOTAL ASSETS            $57

LIABILITIES
------------------------------
  (none)
                        ----------
  TOTAL LIABILITIES       $0

OWNER'S EQUITY
------------------------------
  owners equity   $50
  retained earnings   $7
                        ----------
  TOTAL EQUITY            $57

=========================================
  TOTAL L + OE            $57
=========================================

The books balance! A ($57) = L + OE ($57)

-- Income Summary (Week 1) --
  Revenue:       $22.00
  COGS:         -$10.00
  Wages:        -$3.00
  Advertising:  -$2.00
                 ------
  Net Income:    $7.00

-- Data Inspection --
  Asset accounts:  cash, inventory
  Equity accounts: owners_equity, retained_earnings
  Has cash?        true
  A/R balance:     $0 (used // to default missing account to 0)
```

Open `accounting/src/programs/05-build-balance-sheet.jq` and read through it.
Every technique in the program was covered in this lesson:

- `reduce` to classify accounts into asset/liability/equity buckets
- `as $var` to name computed totals for reuse
- Computed keys `{($acct.key): ...}` inside the reduce
- `map_values` to round balances
- `keys` to list account names
- `has` to check for a specific account
- `//` to safely default a missing account to 0
- String interpolation and `if-then-else` for formatting

---

## Walking Through the Program

Let's trace the key sections of `05-build-balance-sheet.jq` step by step.

### Step 1: Save the original input

```jq
. as $input |
```

The program needs the original data later (for `income_summary`), but the
`reduce` below changes what `.` refers to. Saving the whole input to `$input`
is like copying your source spreadsheet to a reference tab before you start
building formulas.

### Step 2: Classify with reduce

```jq
.accounts | to_entries
| reduce .[] as $acct (
    { "asset": {}, "liability": {}, "equity": {} };
    .[$acct.value.type] += { ($acct.key): $acct.value.balance }
  )
```

The accumulator starts as three empty buckets. Each account gets filed into the
correct bucket. After the reduce finishes, you have a clean summary grouped by
type.

### Step 3: Name the totals

```jq
| ($classified.asset   | values | add // 0) as $total_assets      |
  ($classified.liability | values | add // 0) as $total_liabilities |
  ($classified.equity   | values | add // 0) as $total_equity      |
```

Three named totals, each using `values | add // 0`. The `// 0` ensures that
an empty category (like liabilities) gives 0 instead of `null`.

### Step 4: Verify the equation

```jq
($total_assets == $total_liabilities + $total_equity) as $balanced |
```

One boolean: do the books balance? This is used later in the `if-then-else` at
the bottom of the output.

---

## Deep Dive

For a developer-focused treatment of `reduce`, `foreach`, and accumulators, see
[06-reduce-foreach.md](../06-reduce-foreach.md) in the developer tutorials.

---

## Exercises

All exercises use `accounting/src/data/05-balance-sheet-week1.json`.

### Exercise 1: Sum assets with reduce

Use `reduce` (not `add`) to compute the total asset balance. Start with 0 and
add each asset's balance.

*Hint*: First filter to asset accounts with `with_entries(select(...))`, then
use `to_entries` and `reduce`.

### Exercise 2: Safe lookup with //

Write a jq expression that looks up the balance of the `"equipment"` account.
If it does not exist, return the string `"No equipment yet"`.

### Exercise 3: Find the largest account

Use `map_values(.balance)` and `to_entries` to find the account with the
highest balance. Return just its key (name).

*Hint*: After `to_entries`, use `sort_by(.value)` and `last`.

### Exercise 4: Verify equation with all

Write a jq expression that computes total assets, total liabilities, and total
equity separately, then uses `all` to check whether `assets == liabilities + equity`.
Use `as $var` bindings for each total. The output should be `true`.

### Exercise 5: Build a mini report with pick

Use `pick` to extract just the `cash` and `owners_equity` accounts from
`.accounts`. Then use `map_values(.balance)` on the result to get a simple
`{"cash": 57, "owners_equity": 50}` object.

<details>
<summary>Solutions</summary>

```bash
# Exercise 1: Sum assets with reduce
jq '
  .accounts
  | with_entries(select(.value.type == "asset"))
  | to_entries
  | reduce .[] as $acct (0; . + $acct.value.balance)
' accounting/src/data/05-balance-sheet-week1.json
# 57

# Exercise 2: Safe lookup with //
jq '
  .accounts.equipment.balance // "No equipment yet"
' accounting/src/data/05-balance-sheet-week1.json
# "No equipment yet"

# Exercise 3: Find the largest account
jq '
  .accounts
  | map_values(.balance)
  | to_entries
  | sort_by(.value)
  | last
  | .key
' accounting/src/data/05-balance-sheet-week1.json
# "cash"

# Exercise 4: Verify equation with all
jq '
  (.accounts | to_entries) as $all
  | ([$all[] | select(.value.type == "asset")    | .value.balance] | add // 0) as $a
  | ([$all[] | select(.value.type == "liability") | .value.balance] | add // 0) as $l
  | ([$all[] | select(.value.type == "equity")   | .value.balance] | add // 0) as $oe
  | [$a == $l + $oe]
  | all
' accounting/src/data/05-balance-sheet-week1.json
# true

# Exercise 5: Build a mini report with pick
jq '
  .accounts | pick(.cash, .owners_equity) | map_values(.balance)
' accounting/src/data/05-balance-sheet-week1.json
# {
#   "cash": 57,
#   "owners_equity": 50
# }
```

</details>

---

## What You Learned

| jq feature | Excel equivalent | What it does |
|-------------|-----------------|--------------|
| `reduce .[] as $x (init; update)` | SUM/PRODUCT (hand-built) | Loop through items, accumulate a result |
| `EXPR as $var \| ...` | Named cell / `=$A$1` | Name a value for reuse |
| `{($var): value}` | (no direct equivalent) | Use a variable's value as an object key |
| `keys` / `keys_unsorted` | Column headers | List an object's field names |
| `values` | Column values | List an object's field values |
| `has("key")` | `NOT(ISNA(MATCH(...)))` | Check if a key exists |
| `"key" \| in(obj)` | Same as above, reversed | Check if a key exists (other direction) |
| `map_values(f)` | Drag formula across row | Apply a function to every value |
| `with_entries(f)` | AutoFilter / edit rows | Transform or filter key-value pairs |
| `// default` | `IFERROR()` / `IFNA()` | Provide a fallback for null/false |
| `any(f)` / `all(f)` | `OR(range)` / `AND(range)` | Test if any/all items match |
| `flatten` / `flatten(n)` | Remove grouping | Flatten nested arrays |
| `pick(.a, .b)` (1.8) | Hide columns | Extract a subset of fields |
| `add(gen)` (1.8) | SUM on a range | Sum a stream directly |

---

## Next Lesson

In [Lesson 06 -- The Income Statement](06-the-income-statement.md), you will
build the income statement (Revenue - Expenses = Net Income), learning
`if-then-else`, `def` (custom functions), and `try-catch` along the way.
