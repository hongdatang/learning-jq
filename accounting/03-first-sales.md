# Lesson 03 -- Selling Lemonade: Working with Lists

> **Prerequisites**: You have read Lessons
> [01](01-opening-day.md) and [02](02-buying-supplies.md).  You know
> how to use `.`, `|`, arithmetic, comparisons, and `--arg`.

## The Story So Far

After buying supplies in Lesson 02 your books look like this:

| Account         | Balance |
|-----------------|---------|
| Cash            | $40.00  |
| Inventory       | $10.00  |
| Owner's Equity  | $50.00  |

Twenty cups of lemonade are ready to sell (each cup costs $0.50 in
supplies).  You set up your stand on Saturday morning and open for
business.

Over five days -- Saturday through Wednesday -- customers come and go.
Some buy one cup, some buy two or three.  You write down every single
sale in a notebook: the date, the customer (if you know their name), how
many cups, and the price.

By Wednesday night you have a **list** of 13 transactions.  Time to
learn how jq works with lists.

---

## Setup

All commands below run from the **project root**.  The data file is at
`accounting/src/data/03-daily-sales.json`.

Quick check -- print the whole file:

```bash
jq '.' accounting/src/data/03-daily-sales.json
```

The file has two main sections:

- `.sales` -- an array of 13 individual sale objects
- `.summary` -- pre-computed day totals (we will reproduce these with jq)

Each sale looks like this:

```json
{ "id": 1, "date": "2024-06-01", "customer": "walk-in", "quantity": 2, "unit_price": 1.00, "total": 2.00 }
```

---

## 1. The Iterator `.[]` -- Looping Through Every Row

**Excel analogy**: Imagine column A has 13 rows of data.  When you write
a formula that starts with `=A1` and drag it down, every row gets the
same formula applied.  `.[]` does the same thing -- it takes an array
and hands you each element, one at a time.

```bash
jq '.sales[]' accounting/src/data/03-daily-sales.json
```

This prints all 13 sale objects, one after another -- like reading each
row in your notebook.

Without `.[]` you get the array as a single blob.  With `.[]` you get
each element individually, ready for further processing.

```bash
# The whole array (one output)
jq '.sales' accounting/src/data/03-daily-sales.json

# Each element (13 outputs)
jq '.sales[]' accounting/src/data/03-daily-sales.json
```

> **Key insight**: `.[]` is a *generator*.  It produces multiple
> outputs from one input.  Everything downstream of `.[]` in the pipe
> runs once per element -- exactly like dragging a formula down a column.

---

## 2. Array Indexing -- Picking a Specific Row

**Excel analogy**: `=INDEX(A:A, 1)` picks the first row.
`=INDEX(A:A, ROWS(A:A))` picks the last.

In jq, arrays are zero-indexed (the first element is position 0):

```bash
# First sale
jq '.sales[0]' accounting/src/data/03-daily-sales.json
# {"id":1,"date":"2024-06-01","customer":"walk-in","quantity":2,"unit_price":1,"total":2}

# Last sale (negative index counts from the end)
jq '.sales[-1]' accounting/src/data/03-daily-sales.json
# {"id":13,"date":"2024-06-05","customer":"walk-in","quantity":1,"unit_price":1,"total":1}

# Third sale (index 2)
jq '.sales[2]' accounting/src/data/03-daily-sales.json
```

Think of `.[0]` as "row 1" and `.[-1]` as "the very last row."

---

## 3. Array Slicing -- Selecting a Range of Rows

**Excel analogy**: Highlighting rows 3 through 5 in a spreadsheet.

```bash
# Sales at positions 2, 3, and 4 (three elements)
jq '.sales[2:5]' accounting/src/data/03-daily-sales.json
```

The slice `.[2:5]` means "start at index 2, stop *before* index 5."
This gives you exactly 3 elements.

```bash
# First three sales
jq '.sales[:3]' accounting/src/data/03-daily-sales.json

# Last two sales
jq '.sales[-2:]' accounting/src/data/03-daily-sales.json
```

---

## 4. `map(f)` -- Applying a Formula to Every Row

**Excel analogy**: You have sales totals in column F.  You type a SUM
formula in G1, then drag it down.  Every row gets the same transformation.
`map(f)` does exactly that -- it applies `f` to every element and gives
you back a new array.

```bash
# Extract the total from every sale
jq '.sales | map(.total)' accounting/src/data/03-daily-sales.json
# [2, 1, 2, 3, 2, 1, 2, 1, 2, 3, 1, 1, 1]

# Extract the quantity from every sale
jq '.sales | map(.quantity)' accounting/src/data/03-daily-sales.json
# [2, 1, 2, 3, 2, 1, 2, 1, 2, 2, 1, 1, 1]
```

You can put any expression inside `map(...)`:

```bash
# Calculate profit per sale (revenue minus cost at $0.50/cup)
jq '.sales | map(.total - (.quantity * 0.50))' accounting/src/data/03-daily-sales.json
# [1, 0.5, 1, 1.5, 1, 0.5, 1, 0.5, 1, 2, 0.5, 0.5, 0.5]
```

> **Technical note**: `map(f)` is shorthand for `[.[] | f]`.  It
> iterates (`.[]`), applies `f`, and collects the results back into an
> array (`[...]`).  You will see both forms in practice.

---

## 5. `select(f)` -- Filtering Rows

**Excel analogy**: `=FILTER(A:F, F:F > 2)` keeps only the rows where
column F is greater than 2.  In jq, `select(condition)` does the same
thing.

```bash
# Sales where quantity > 1
jq '.sales | map(select(.quantity > 1))' accounting/src/data/03-daily-sales.json
```

```bash
# Premium sales: unit_price above the standard $1.00
jq '.sales | map(select(.unit_price > 1.00))' accounting/src/data/03-daily-sales.json
# [{"id":10,"date":"2024-06-03","customer":"walk-in","quantity":2,"unit_price":1.5,"total":3}]
```

```bash
# All of Mrs. Henderson's purchases
jq '.sales | map(select(.customer == "Mrs. Henderson"))' accounting/src/data/03-daily-sales.json
```

You can combine conditions with `and`/`or`:

```bash
# Weekend sales (Saturday and Sunday) with total >= 2
jq '.sales | map(select((.date == "2024-06-01" or .date == "2024-06-02") and .total >= 2))' \
  accounting/src/data/03-daily-sales.json
```

> **How it works**: `select(f)` passes the element through if `f` is
> true, and drops it silently if `f` is false.  Combined with `map`, it
> filters an array just like `FILTER()` in Excel.

Find the biggest single sale (like `=MAX()` on the total column, but
returning the whole row):

```bash
jq '.sales | max_by(.total)' accounting/src/data/03-daily-sales.json
# {"id":10, "date":"2024-06-03", ... "total":3.00}
```

---

## 6. `add` -- Summing a Column

**Excel analogy**: `=SUM(F:F)` adds up every value in column F.

```bash
# Total revenue
jq '.sales | map(.total) | add' accounting/src/data/03-daily-sales.json
# 22

# Total cups sold
jq '.sales | map(.quantity) | add' accounting/src/data/03-daily-sales.json
# 21
```

The pattern `map(.field) | add` is your `SUM()`.  You will use it
constantly.

You can combine `select` and `add` for conditional sums -- like
`SUMIF()` in Excel:

```bash
# Revenue from just Saturday (2024-06-01)
jq '.sales | map(select(.date == "2024-06-01")) | map(.total) | add' \
  accounting/src/data/03-daily-sales.json
# 5
```

---

## 7. `length` -- Counting Rows

**Excel analogy**: `=COUNTA(A:A)` counts non-empty cells.

```bash
# How many sales transactions?
jq '.sales | length' accounting/src/data/03-daily-sales.json
# 13

# How many premium-price sales?
jq '[.sales[] | select(.unit_price > 1.00)] | length' accounting/src/data/03-daily-sales.json
# 1
```

---

## 8. Collecting with `[...]` -- Turning Outputs Back into an Array

When `.[]` scatters an array into individual outputs, wrapping an
expression in `[...]` gathers them back into an array.

**Excel analogy**: Think of it as taking a column of formula results and
pasting them into a new column.

```bash
# Without [...]: 13 separate outputs
jq '.sales[] | .total' accounting/src/data/03-daily-sales.json

# With [...]: one array
jq '[.sales[] | .total]' accounting/src/data/03-daily-sales.json
# [2,1,2,3,2,1,2,1,2,3,1,1,1]
```

This is essential when you want to feed results into `add`, `length`,
`sort`, or any function that expects an array:

```bash
# Unique customer names
jq '[.sales[].customer] | unique' accounting/src/data/03-daily-sales.json
# ["Coach Davis","Mr. Park","Mrs. Henderson","walk-in"]
```

---

## 9. The Comma Operator -- Selecting Multiple Columns

**Excel analogy**: Selecting columns B and F at the same time.

The comma `,` in jq produces multiple outputs:

```bash
# Date and total for each sale
jq '.sales[] | .date, .total' accounting/src/data/03-daily-sales.json
```

This alternates: date, total, date, total, date, total...  That is
useful but often hard to read.  Wrap it in an object or array for
structure:

```bash
# Neat two-column output
jq '.sales[] | {date, total}' accounting/src/data/03-daily-sales.json

# Or as arrays (like two-column rows)
jq '.sales[] | [.date, .total]' accounting/src/data/03-daily-sales.json
```

---

## 10. `range(n)` -- Generating Number Sequences

**Excel analogy**: `=SEQUENCE(5)` generates {1, 2, 3, 4, 5}.

```bash
# Generate 0 through 4
jq -n '[range(5)]'
# [0, 1, 2, 3, 4]

# Generate 1 through 5 (start; stop)
jq -n '[range(1; 6)]'
# [1, 2, 3, 4, 5]

# Count by 0.50 from 0.50 to 2.00 (start; stop; step)
jq -n '[range(0.50; 2.01; 0.50)]'
# [0.5, 1, 1.5, 2]
```

A practical use -- generate row numbers for your sales:

```bash
jq '[range(.sales | length)] | map(. + 1)' accounting/src/data/03-daily-sales.json
# [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
```

---

## 11. Type Selectors -- Filtering by Data Type

**Excel analogy**: Like `=FILTER(A:A, ISNUMBER(A:A))` -- keep only the
cells that contain numbers.

jq provides built-in filters that pass through values of a specific
type and drop everything else:

| Selector     | Keeps                    |
|------------- |--------------------------|
| `numbers`    | Integers and floats      |
| `strings`    | Text values              |
| `booleans`   | `true` and `false`       |
| `nulls`      | `null` values            |
| `arrays`     | Arrays                   |
| `objects`    | Objects                  |
| `scalars`    | Non-iterables (numbers, strings, booleans, null) |
| `iterables`  | Arrays and objects       |

```bash
# What numeric values does the first sale contain?
jq '[.sales[0][] | numbers]' accounting/src/data/03-daily-sales.json
# [1, 2, 1, 2]    (id, quantity, unit_price, total)

# What string values?
jq '[.sales[0][] | strings]' accounting/src/data/03-daily-sales.json
# ["2024-06-01", "walk-in"]
```

Here is a consolidated demo showing all the selectors on a mixed-type
array:

```bash
jq -n '[42, "hello", true, null, [1,2], {"a":1}] |
  { numbers:   [.[] | numbers],
    strings:   [.[] | strings],
    booleans:  [.[] | booleans],
    nulls:     [.[] | nulls],
    arrays:    [.[] | arrays],
    objects:   [.[] | objects],
    scalars:   [.[] | scalars],
    iterables: [.[] | iterables] }'
# numbers: [42], strings: ["hello"], booleans: [true], nulls: [null]
# arrays: [[1,2]], objects: [{"a":1}]
# scalars: [42,"hello",true,null], iterables: [[1,2],{"a":1}]
```

Type selectors are useful for data validation -- making sure a column
contains only the type you expect:

```bash
# Verify that every "total" field is a number
jq '.sales | map(.total) | all(type == "number")' accounting/src/data/03-daily-sales.json
# true
```

---

## 12. `first(expr)` and `last(expr)` -- Grabbing the Ends

**Excel analogy**: `=INDEX(range, 1)` for first, `=INDEX(range,
ROWS(range))` for last.

```bash
# First sale of the week
jq '.sales | first' accounting/src/data/03-daily-sales.json
# {"id":1,"date":"2024-06-01",...}

# Last sale of the week
jq '.sales | last' accounting/src/data/03-daily-sales.json
# {"id":13,"date":"2024-06-05",...}
```

You can also use `first` and `last` with a generator expression:

```bash
# First sale over $2.00
jq 'first(.sales[] | select(.total > 2))' accounting/src/data/03-daily-sales.json
# {"id":4,...,"total":3}

# Last sale to a named customer (not walk-in)
jq 'last(.sales[] | select(.customer != "walk-in"))' accounting/src/data/03-daily-sales.json
# {"id":12,...,"customer":"Mrs. Henderson"}
```

---

## 13. `limit(n; expr)` -- Taking Just the First N

**Excel analogy**: Showing only the top N rows of a sorted list.

```bash
# First 3 sales
jq '[limit(3; .sales[])]' accounting/src/data/03-daily-sales.json

# First 2 sales worth more than $1.00
jq '[limit(2; .sales[] | select(.total > 1))]' accounting/src/data/03-daily-sales.json
```

Note the semicolon `;` between the count and the expression -- this is
jq's separator inside function arguments (not a comma).

> **Why not just slice?**  `limit` works on *generators*, not just
> arrays.  It stops producing results after `n`, which can be more
> efficient than filtering everything first and then taking a slice.

---

## Putting It All Together

Run the full program:

```bash
jq -f accounting/src/programs/03-sales-summary.jq accounting/src/data/03-daily-sales.json
```

The program chains every concept from this lesson:

1. `map(.quantity) | add` -- total cups (like `SUM(quantity)`)
2. `map(.total) | add` -- total revenue (like `SUM(revenue)`)
3. `length` -- transaction count (like `COUNTA`)
4. `map(select(...))` -- premium sales (like `FILTER`)
5. `first`, `last` -- endpoints of the list
6. `.[0]`, `.[-1]`, `.[2:5]` -- indexing and slicing
7. Comma operator -- multiple fields at once
8. `[...]` -- collecting results
9. Type selectors -- inspecting data types
10. `limit` -- taking the first N

---

## Accounting Sidebar: Revenue Recognition

When do you record a sale?  When the customer hands you money and you
hand them lemonade.  In accounting this is called **revenue
recognition** -- revenue is recognized when the goods are delivered, not
when the order is placed.

For a lemonade stand every sale is immediate: cash in, lemonade out.
But when your business grows (Lesson 07), you will sell on credit --
deliver lemonade today, get paid next week.  The revenue is still
recognized today, even though cash has not arrived.  That distinction
between *earning* revenue and *receiving* cash is fundamental to
accounting.

For now, every sale in this lesson is a cash sale.  The accounting is
simple:

| Account        | Change   |
|----------------|----------|
| Cash           | +$22.00  |
| Inventory      | -$9.50   |
| Sales Revenue  | +$22.00  |
| COGS           | +$9.50   |

We started with $10.00 of inventory (enough for about 20 cups at
$0.50/cup).  We sold 21 cups over the week -- you can stretch supplies
a bit when business is good.  After a physical count on Wednesday night,
you have about one cup's worth of supplies left, valued at $0.50.

So: inventory used = $10.00 - $0.50 = **$9.50 COGS**.

After the week: Cash = $40 + $22 = **$62.00**.
Inventory remaining = **$0.50**.

---

## Deep Dive

For a comprehensive reference on arrays, objects, `map`, `select`,
`add`, `range`, `first`, `last`, `limit`, and more, see
[03-array-object-operations.md](../03-array-object-operations.md) in the
developer tutorials.

---

## Exercises

Try these yourself.  Each one uses only features from this lesson.

### Exercise 1: Sunday Revenue

Calculate the total revenue for Sunday (2024-06-02) only.

<details>
<summary>Solution</summary>

```bash
jq '[.sales[] | select(.date == "2024-06-02")] | map(.total) | add' \
  accounting/src/data/03-daily-sales.json
# 8
```

`select` filters to Sunday rows, `map(.total)` extracts the amounts,
`add` sums them.  Like `=SUMIF(date_column, "2024-06-02",
total_column)` in Excel.

</details>

### Exercise 2: Named Customers

How many sales were to named customers (not "walk-in")?  What was their
total spending?

<details>
<summary>Solution</summary>

```bash
# Count
jq '[.sales[] | select(.customer != "walk-in")] | length' \
  accounting/src/data/03-daily-sales.json
# 4

# Total spending
jq '[.sales[] | select(.customer != "walk-in")] | map(.total) | add' \
  accounting/src/data/03-daily-sales.json
# 6
```

Four transactions to named customers (Mrs. Henderson twice, Mr. Park
once, Coach Davis once) totaling $6.00.

</details>

### Exercise 3: Profit per Cup

Each cup costs $0.50 in supplies.  Create an array of objects showing
`{id, revenue, cost, profit}` for every sale.

<details>
<summary>Solution</summary>

```bash
jq '.sales | map({
  id,
  revenue: .total,
  cost: (.quantity * 0.50),
  profit: (.total - .quantity * 0.50)
})' accounting/src/data/03-daily-sales.json
```

The premium sale (id 10, $1.50/cup) has the highest per-cup profit.
Everyone else sells at $1.00 with a $0.50 profit per cup.

</details>

### Exercise 4: Best Day

Using the `.summary.by_day` array, find the day with the highest
revenue.  Hint: you will need `map`, `select`, and the `max_by` trick
from the reference (or do it with `sort_by` and `.[-1]`).

<details>
<summary>Solution</summary>

```bash
# Using sort_by + last
jq '.summary.by_day | sort_by(.revenue) | last' \
  accounting/src/data/03-daily-sales.json
# {"date":"2024-06-02","day":"Sunday","cups_sold":8,"revenue":8}
```

Sunday was the best day -- $8.00 in revenue from 8 cups.

</details>

### Exercise 5: Type Inspection

Extract all the different data types present in a single sale object.
Print the unique set of type names.

<details>
<summary>Solution</summary>

```bash
jq '[.sales[0][] | type] | unique' accounting/src/data/03-daily-sales.json
# ["number","string"]
```

Each sale contains only numbers and strings.  No booleans, nulls,
arrays, or nested objects -- clean, flat data.

</details>

---

**Next up**: [Lesson 04 -- End of the Week](04-end-of-week.md), where
you sort, group, and summarize a full week of transactions.
