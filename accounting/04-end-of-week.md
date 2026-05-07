# Lesson 04 -- End of the Week: Sorting and Grouping

## The Story

It is Friday evening. Five days of lemonade sales, and your pockets are full of
crumpled receipts -- 20 transactions on scraps of paper. Your mom says: "Sort
them, group them by type, and figure out your totals."

In Excel you would sort the rows and build a pivot table. In jq you do the same
with `sort_by`, `group_by`, and `to_entries`.

**Previous lesson**: [03 -- First Sales](03-first-sales.md) (`.[]`, `map`,
`select`, `add`, `first`, `last`, `limit`).

**Data file**: `accounting/src/data/04-week1-transactions.json` -- 20
transactions covering June 1-5. Types: `investment`, `purchase`, `sale`,
`wage`, `advertising`. Amounts are always positive; the type tells direction.

---

## Sorting: `sort_by`, `sort`, `reverse`

### sort_by(.field) -- "Data > Sort"

> **Excel analogy**: Select your data, click **Data > Sort**, pick a column.
> `sort_by(.field)` does exactly that. Pass multiple fields for a multi-key sort.

```bash
jq 'sort_by(.date, .id)' accounting/src/data/04-week1-transactions.json
```

### sort and reverse

`sort` works on flat arrays (no `.field` needed). `reverse` flips the order.

> **Excel analogy**: `sort` = sorting a single column of numbers. `reverse` =
> the descending sort button (Z-A).

Combine them to get the biggest transactions first:

```bash
jq '[sort_by(.amount) | reverse[] | {id, type, amount}]' \
  accounting/src/data/04-week1-transactions.json
```

---

## Unique Values: `unique` and `unique_by`

### unique -- "Remove Duplicates"

> **Excel analogy**: Select a column, **Data > Remove Duplicates**. One value
> per distinct entry, sorted.

```bash
jq '[.[] | .type] | unique' accounting/src/data/04-week1-transactions.json
```

```json
["advertising", "investment", "purchase", "sale", "wage"]
```

### unique_by(.field) -- unique rows by one column

> **Excel analogy**: Remove Duplicates checking only one column. Keep the first
> row for each distinct value.

```bash
jq '[unique_by(.date)[] | .date]' accounting/src/data/04-week1-transactions.json
```

```json
["2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05"]
```

---

## Min and Max: `min_by` / `max_by`, `min` / `max`

> **Excel analogy**: `max_by(.amount)` is like
> `=INDEX(data, MATCH(MAX(amount), amount, 0))` -- find the row where a column
> hits its extreme. One step instead of a nested formula.

```bash
jq 'max_by(.amount) | {id, type, amount}' \
  accounting/src/data/04-week1-transactions.json
```

```json
{ "id": 1, "type": "investment", "amount": 50.00 }
```

For flat arrays, `min` and `max` work without the `_by` suffix:

```bash
jq '[.[] | .amount] | min' accounting/src/data/04-week1-transactions.json  # 1
```

---

## Grouping: `group_by` -- The Pivot Table

This is the big one.

> **Excel analogy**: Insert a Pivot Table. Drag "type" to Rows. Drag "amount"
> to Values and set it to SUM. One row per type with a subtotal. `group_by`
> does the same: it splits your array into sub-arrays, one per distinct value.

`group_by(.type)` alone produces an array of arrays -- 5 groups. The real power
comes from summarizing each group:

```bash
jq '[group_by(.type)[] | {
  type:  .[0].type,
  count: length,
  total: (map(.amount) | add)
}]' accounting/src/data/04-week1-transactions.json
```

```json
[
  { "type": "advertising", "count": 1, "total": 2 },
  { "type": "investment",  "count": 1, "total": 50 },
  { "type": "purchase",    "count": 3, "total": 10 },
  { "type": "sale",        "count": 14, "total": 22 },
  { "type": "wage",        "count": 1, "total": 3 }
]
```

| jq expression        | What it does                          | Excel Pivot equivalent |
|----------------------|---------------------------------------|------------------------|
| `group_by(.type)[]`  | Split into groups, iterate each       | Row labels             |
| `.[0].type`          | Type name (same for all in group)     | Row label text         |
| `length`             | Count of items in this group          | COUNT in Values        |
| `map(.amount) | add` | Sum the amounts                       | SUM in Values          |

### Revenue by day (nested grouping)

Filter to sales first, then group by date:

```bash
jq '[map(select(.type == "sale")) | group_by(.date)[] | {
  date:    .[0].date,
  cups:    length,
  revenue: (map(.amount) | add)
}]' accounting/src/data/04-week1-transactions.json
```

```json
[
  { "date": "2024-06-01", "cups": 3, "revenue": 5 },
  { "date": "2024-06-02", "cups": 5, "revenue": 8 },
  { "date": "2024-06-03", "cups": 3, "revenue": 6 },
  { "date": "2024-06-04", "cups": 2, "revenue": 2 },
  { "date": "2024-06-05", "cups": 1, "revenue": 1 }
]
```

Sunday was the best day. Wednesday was the slowest.

---

## Object Construction Shorthand: `{name, amount}`

> **Excel analogy**: Selecting columns to copy to a new sheet without renaming
> them. `{type, amount}` = "show me just these two columns."

```bash
jq '[.[:3][] | {type, amount}]' accounting/src/data/04-week1-transactions.json
```

```json
[
  { "type": "investment", "amount": 50.00 },
  { "type": "purchase",   "amount": 6.00 },
  { "type": "purchase",   "amount": 3.00 }
]
```

Shorthand for `{type: .type, amount: .amount}`. Mix and match to rename some
fields: `{type, cost: .amount}`.

---

## `to_entries` / `from_entries` -- Pivoting and Unpivoting

### to_entries -- "Unpivot"

> **Excel analogy**: You have a summary row `{sale: 22, purchase: 10, wage: 3}`.
> Turn it into a tall table with "key" and "value" columns. In Power Query this
> is "Unpivot Columns."

Build a summary object, then unpivot it:

```bash
jq '[group_by(.type)[] | {(.[0].type): (map(.amount) | add)}] | add
  | to_entries' accounting/src/data/04-week1-transactions.json
```

```json
[
  { "key": "advertising", "value": 2 },
  { "key": "investment",  "value": 50 },
  { "key": "purchase",    "value": 10 },
  { "key": "sale",        "value": 22 },
  { "key": "wage",        "value": 3 }
]
```

### from_entries -- "Pivot" back

The reverse: collapse a `[{key, value}]` array back into an object.

```bash
jq -n '[{"key": "revenue", "value": 22}, {"key": "expenses", "value": 15}]
  | from_entries'
# { "revenue": 22, "expenses": 15 }
```

---

## `skip` -- Skip the First N Results (jq 1.8)

> **Excel analogy**: Using OFFSET to start reading from row 6 instead of row 1.
> Hide the header/setup rows and get straight to the data.

The first 5 transactions are setup (investment, purchases, sign). Skip them:

```bash
jq '[skip(5; .[])] | length' accounting/src/data/04-week1-transactions.json
```

```
15
```

Compare with `limit` from Lesson 03: `limit(3; .[])` keeps the first 3;
`skip(5; .[])` drops the first 5 and keeps the rest.

---

## Combining It All: Best and Worst Revenue Days

```bash
jq '
  [map(select(.type == "sale")) | group_by(.date)[] | {
    date:    .[0].date,
    revenue: (map(.amount) | add)
  }] as $days |
  "Best day:  \($days | max_by(.revenue) | "\(.date) ($\(.revenue))")",
  "Worst day: \($days | min_by(.revenue) | "\(.date) ($\(.revenue))")"
' accounting/src/data/04-week1-transactions.json
```

```
"Best day:  2024-06-02 ($8)"
"Worst day: 2024-06-05 ($1)"
```

---

## Accounting Sidebar: Period Reporting

### Transaction Classification

Every transaction maps to a financial statement:

| Type        | Statement              | Direction |
|-------------|------------------------|-----------|
| investment  | Balance Sheet (Equity) | Money in  |
| sale        | Income Statement (Revenue) | Money in  |
| purchase    | Income Statement (Expense) | Money out |
| wage        | Income Statement (Expense) | Money out |
| advertising | Income Statement (Expense) | Money out |

### Your Week 1 Results

```
Revenue (sales):      $22
Supplies purchased:  -$10
Wages paid:          -$3
Advertising:         -$2
Total expenses:      -$15
─────────────────────────
Net income:           $7
```

The stand made $7 in its first week. You will build the full income statement in
[Lesson 06](06-the-income-statement.md).

Run the complete lesson program to see all sections together:

```bash
jq -f accounting/src/programs/04-weekly-totals.jq \
  accounting/src/data/04-week1-transactions.json
```

---

## Exercises

All use `accounting/src/data/04-week1-transactions.json`.

1. **Sort by amount descending.** Show all 20 transactions sorted largest to
   smallest. Display only `{id, type, amount}`.

2. **Unique accounts.** What distinct `account` values appear in the data?

3. **Daily expense report.** Group non-sale, non-investment transactions by
   date. Show `{date, count, total}` per date.

4. **Highest-revenue sale.** Find the single sale with the largest amount. Show
   `{date, description, amount}`. Use `max_by`, not sorting.

5. **Pivot and unpivot.** Build an object where each key is a date and each
   value is the transaction count for that date. Pipe to `to_entries`.

<details>
<summary>Solutions</summary>

```bash
# 1. Sort by amount descending
jq '[sort_by(.amount) | reverse[] | {id, type, amount}]' \
  accounting/src/data/04-week1-transactions.json

# 2. Unique accounts
jq '[.[] | .account] | unique' \
  accounting/src/data/04-week1-transactions.json
# ["Advertising", "Cash", "Sales", "Supplies", "Wages"]

# 3. Daily expense report
jq '[
  map(select(.type != "sale" and .type != "investment"))
  | group_by(.date)[]
  | { date: .[0].date, count: length, total: (map(.amount) | add) }
]' accounting/src/data/04-week1-transactions.json
# [{"date":"2024-06-01","count":4,"total":12},
#  {"date":"2024-06-03","count":1,"total":3}]

# 4. Highest-revenue sale
jq 'map(select(.type == "sale")) | max_by(.amount)
  | {date, description, amount}' \
  accounting/src/data/04-week1-transactions.json
# {"date":"2024-06-03","description":"2 cups to walk-in (premium price)","amount":3}

# 5. Pivot and unpivot
jq '[group_by(.date)[] | {(.[0].date): length}] | add
  | to_entries' \
  accounting/src/data/04-week1-transactions.json
# [{"key":"2024-06-01","value":8},{"key":"2024-06-02","value":5},
#  {"key":"2024-06-03","value":4},{"key":"2024-06-04","value":2},
#  {"key":"2024-06-05","value":1}]
```

</details>
