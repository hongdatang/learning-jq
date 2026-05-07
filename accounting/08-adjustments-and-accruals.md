# Lesson 08 -- Month-End Cleanup: Adjustments and Accruals

> **Prerequisites**: Lessons [01](01-opening-day.md) through 07.
> You know `.`, `|`, `map`, `select`, `reduce`, `as $var`, `def`,
> `if-then-else`, `|=`, `+=`, and `del`.

## The Story So Far

June has been a whirlwind.  You started with $50, bought supplies, sold
lemonade, took a $50 bank loan, bought a $40 lemonade stand (equipment),
paid for 3 months of insurance ($12), and extended $5 credit to the
neighbor kid.

Now it is June 30.  Your accountant aunt stops by to help you "close the
books."

"Before we can produce real financial statements," she says, "we need
adjustments.  Not everything shows up as a cash transaction."

| # | What happened | Debit | Credit | Amount |
|---|---------------|-------|--------|--------|
| 1 | Stand wearing out (depreciation) | Depreciation Expense | Accumulated Depreciation | $4.00 |
| 2 | One month of insurance used | Insurance Expense | Prepaid Insurance | $4.00 |
| 3 | Neighbor moved away | Bad Debt Expense | Accounts Receivable | $5.00 |

---

## Setup

Commands run from the **project root**.  Data file:
`accounting/src/data/08-adjusting-entries.json`.

```bash
jq '.adjusting_entries' accounting/src/data/08-adjusting-entries.json
```

Pre-adjustment balances:

| Account | Balance | | Account | Balance |
|---------|--------:|-|---------|--------:|
| Cash | $62 | | Notes Payable | $50 |
| A/R | $5 | | Owner's Equity | $50 |
| Prepaid Insurance | $12 | | Retained Earnings | $19 |
| Equipment | $40 | | | |
| **Total Assets** | **$119** | | **Total L+OE** | **$119** |

---

## 1. `foreach` -- A Column Where Each Row Depends on the Row Above

**Excel analogy**: Column C is a running total.  C1 starts at some
value.  C2 = C1 + B2.  C3 = C2 + B3.  Each cell depends on the one
above.  That is `foreach`.

```
foreach EXPR as $var (INIT; UPDATE; EXTRACT)
```

- **EXPR** -- the values to loop over (rows in column B)
- **INIT** -- starting state (C1)
- **UPDATE** -- how to change state for each row (C2 = C1 + B2)
- **EXTRACT** -- what to output after each step (show C2)

Simple running total:

```bash
jq -n '[foreach range(1;6) as $n (0; . + $n; .)]'
# [1, 3, 6, 10, 15]
```

| Step | $n | State before | After UPDATE | Output |
|------|----|-------------|-------------|--------|
| 1 | 1 | 0 | 1 | 1 |
| 2 | 2 | 1 | 3 | 3 |
| 3 | 3 | 3 | 6 | 6 |
| 4 | 4 | 6 | 10 | 10 |
| 5 | 5 | 10 | 15 | 15 |

> **Key insight**: `reduce` gives one value (the final state, like
> `SUM`).  `foreach` gives one value *per step* (the running total
> column).  See [Lesson 05](05-the-balance-sheet.md) for `reduce`.

### Applying Adjustments with `foreach`

Process the three adjusting entries, showing retained earnings after
each:

```bash
jq -r '
  foreach .adjusting_entries[] as $entry (
    .pre_adjustment_balances;
    .retained_earnings -= $entry.debit.amount;
    "\($entry.id): \($entry.description) -> RE now: \(.retained_earnings)"
  )
' accounting/src/data/08-adjusting-entries.json
```

```
ADJ-001: Monthly depreciation on lemonade stand -> RE now: 15
ADJ-002: June portion of 3-month insurance -> RE now: 11
ADJ-003: Neighbor moved away - uncollectible receivable -> RE now: 6
```

Retained earnings drops $19 -> $15 -> $11 -> $6.  Each row depends on
the one before.

### Building a Depreciation Schedule

Classic `foreach` -- each month, accumulated depreciation grows and book
value falls:

```bash
jq -r '
  .depreciation_schedule as {$cost, $monthly_depreciation} |
  foreach range(.depreciation_schedule.useful_life_months) as $i (
    { accumulated: 0, book_value: $cost };
    .accumulated += $monthly_depreciation
    | .book_value -= $monthly_depreciation;
    "Month \($i+1): accumulated $\(.accumulated), book value $\(.book_value)"
  )
' accounting/src/data/08-adjusting-entries.json
```

Ten rows, the stand depreciating from $40 to $0.  Two linked columns
carried in the state object, row to row.

---

## 2. Destructuring Bind -- Unpacking a Row into Named Cells

**Excel analogy**: A1 is the date, B1 is the customer, C1 is the
amount.  Destructuring names each piece so you can use it directly.

### Object Destructuring: `. as {key: $var}`

```bash
jq -r '
  .adjusting_entries[0] | . as {
    $id,
    debit: {account: $debit_acct, amount: $debit_amt},
    credit: {account: $credit_acct, amount: $credit_amt}
  } |
  "\($id): DR \($debit_acct) $\($debit_amt), CR \($credit_acct) $\($credit_amt)"
' accounting/src/data/08-adjusting-entries.json
```

```
ADJ-001: DR depreciation_expense $4.00, CR accumulated_depreciation $4.00
```

When the field name matches the variable name, use the shorthand:

```
. as {$id}          # same as . as {id: $id}
. as {$id, $type}   # same as . as {id: $id, type: $type}
```

### Array Destructuring: `. as [$first, $second]`

```bash
jq -n '[10, 20, 30] | . as [$a, $b, $c] | "first: \($a), second: \($b), third: \($c)"'
# "first: 10, second: 20, third: 30"
```

Extra elements are silently ignored:

```bash
jq -n '["cash", 62, "asset"] | . as [$name, $balance] | {$name, $balance}'
# {"name": "cash", "balance": 62}
```

Compare destructuring to the verbose alternative:

```bash
# Without destructuring (repetitive)
.pre_adjustment_balances.cash as $cash |
.pre_adjustment_balances.accounts_receivable as $ar |
.pre_adjustment_balances.prepaid_insurance as $prepaid |
# ... and so on for every field

# With destructuring (one statement)
.pre_adjustment_balances | . as {$cash, accounts_receivable: $ar, prepaid_insurance: $prepaid}
```

---

## 3. `{$var}` Shorthand -- Quick Object Construction (jq 1.8)

**Excel analogy**: Copy named cells into a new table where column
headers match -- just paste, no renaming.

```bash
jq -n '"Alice" as $name | 25 as $age | {$name, $age}'
# {"name": "Alice", "age": 25}
```

Without the shorthand: `{"name": $name, "age": $age}`.  The lesson
program uses this for a compact summary:

```bash
jq '
  (.adjusting_entries | length) as $count |
  (.adjusting_entries | map(.debit.amount) | add) as $total |
  {$count, $total, average: ($total / $count)}
' accounting/src/data/08-adjusting-entries.json
```

```json
{"count": 3, "total": 13, "average": 4.333333333333333}
```

`$count` and `$total` use the shorthand; `average` needs an explicit key
because there is no `$average` variable.

---

## 4. Generators, `empty`, and Backtracking

**Excel analogy**: `FILTER()` removes rows that fail a condition.  In
jq, `empty` is what makes a row disappear.

A **generator** produces zero, one, or many outputs:

| Expression | Outputs |
|-----------|---------|
| `.field` | 1 |
| `.[]` | 0 to many (Lesson 03) |
| `range(5)` | 5 |
| `empty` | 0 -- nothing at all |

```bash
jq -n '1, 2, empty, 4'
# 1
# 2
# 4
```

No third line.  `empty` did not produce a blank -- it produced nothing.

`select(condition)` is built on `empty`: when the condition is false, it
calls `empty` and the value vanishes.  You can use `empty` directly:

```bash
jq -r '
  .adjusting_entries[] |
  .debit as {$account, $amount} |
  if ($account | test("expense"))
  then "\($account): $\($amount)"
  else empty
  end
' accounting/src/data/08-adjusting-entries.json
```

```
depreciation_expense: $4.00
insurance_expense: $4.00
bad_debt_expense: $5.00
```

When `empty` fires, jq "backtracks" -- returns to the nearest generator
for the next value.  Like a toll booth: each car is checked, and
rejected cars simply leave the lane.  For more, see
[05-generators-and-backtracking.md](../05-generators-and-backtracking.md).

---

## Accounting Sidebar: Why Adjusting Entries Exist

### Accrual vs. Cash Basis

| | Cash Basis | Accrual Basis |
|--|-----------|---------------|
| Record revenue when... | Cash arrives | You earn it |
| Record expense when... | Cash leaves | You incur it |
| Required for real businesses? | No | Yes (GAAP) |

Your lemonade stand has been using a mix.  Cash sales were easy.  But
equipment, insurance, and bad debt do not fit "cash in / cash out."
Adjusting entries bridge the gap.

### Depreciation

Your $40 stand lasts 10 months.  Rather than expensing $40 in month 1,
spread the cost: $40 / 10 = **$4/month**.

**Accumulated Depreciation** is a contra-asset -- it offsets Equipment
on the balance sheet.  Equipment stays at $40 (original cost); Accum.
Depr. grows each month.  The difference is **book value**:

| Month | Equipment | Accum. Depr. | Book Value |
|-------|-----------|-------------|------------|
| 0 | $40 | $0 | $40 |
| 1 | $40 | $4 | $36 |
| 5 | $40 | $20 | $20 |
| 10 | $40 | $40 | $0 |

### Prepaid Expenses

You paid $12 for 3 months of insurance.  Each month, $4 moves from
Prepaid Insurance (asset) to Insurance Expense.  After 3 months the
asset reaches $0 and the full $12 is expensed.

### Bad Debt

The neighbor owed $5 but moved away.  "Write off" the receivable:
Bad Debt Expense $5, A/R -$5.  The money is gone -- better to
acknowledge it than carry a phantom asset.

### Net Effect

| Adjustment | RE Impact | Asset Impact |
|-----------|-----------|-------------|
| Depreciation | -$4 | Accum. Depr. +$4 |
| Insurance | -$4 | Prepaid Insurance -$4 |
| Bad debt | -$5 | A/R -$5 |
| **Total** | **-$13** | **Net assets -$13** |

Retained Earnings: $19 -> $6.  Total assets: $119 -> $106.
Books still balance.

---

## Putting It All Together

```bash
jq -rf accounting/src/programs/08-apply-adjustments.jq \
  accounting/src/data/08-adjusting-entries.json
```

The program demonstrates:

1. **`foreach`** -- adjusting entries with running RE balance
2. **`foreach`** + `range` -- 10-month depreciation schedule
3. **Destructuring** -- unpacking balances into named variables
4. **`empty`** -- filtering to expense-only debits
5. **`{$var}` shorthand** -- compact summary object
6. **`reduce`** -- final post-adjustment balances

### Post-Adjustment Balance Sheet

| Account | Before | Adj. | After |
|---------|-------:|-----:|------:|
| Cash | $62 | -- | $62 |
| A/R | $5 | -$5 | $0 |
| Prepaid Insurance | $12 | -$4 | $8 |
| Equipment | $40 | -- | $40 |
| Accum. Depreciation | $0 | +$4 | -$4 |
| **Net Assets** | **$119** | **-$13** | **$106** |
| Notes Payable | $50 | -- | $50 |
| Owner's Equity | $50 | -- | $50 |
| Retained Earnings | $19 | -$13 | $6 |
| **Total L+OE** | **$119** | **-$13** | **$106** |

---

## Deep Dive

For more on `foreach`, generators, `empty`, and backtracking, see
[05-generators-and-backtracking.md](../05-generators-and-backtracking.md)
and [06-reduce-foreach.md](../06-reduce-foreach.md).

---

## Exercises

### Exercise 1: Insurance Amortization Table

Use `foreach` to generate a 3-month table for the $12 prepaid insurance,
showing the remaining balance after each month.

<details>
<summary>Solution</summary>

```bash
jq -r '
  foreach range(1;4) as $month (
    12;
    . - 4;
    "Month \($month): expense $4, remaining prepaid $\(.)"
  )
' accounting/src/data/08-adjusting-entries.json
```

```
Month 1: expense $4, remaining prepaid $8
Month 2: expense $4, remaining prepaid $4
Month 3: expense $4, remaining prepaid $0
```

State starts at 12, subtracts $4 each month, reaches $0 after 3 months.

</details>

### Exercise 2: Destructure and Summarize

Use destructuring to print each entry as:
`ADJ-001: DR depreciation_expense $4 / CR accumulated_depreciation $4`

<details>
<summary>Solution</summary>

```bash
jq -r '
  .adjusting_entries[] | . as {
    $id,
    debit: {account: $dr_acct, amount: $dr_amt},
    credit: {account: $cr_acct, amount: $cr_amt}
  } |
  "\($id): DR \($dr_acct) $\($dr_amt) / CR \($cr_acct) $\($cr_amt)"
' accounting/src/data/08-adjusting-entries.json
```

```
ADJ-001: DR depreciation_expense $4.00 / CR accumulated_depreciation $4.00
ADJ-002: DR insurance_expense $4.00 / CR prepaid_insurance $4.00
ADJ-003: DR bad_debt_expense $5.00 / CR accounts_receivable $5.00
```

</details>

### Exercise 3: Filter with `empty`

Print only adjustments where the amount >= $5.  Use `if/else empty/end`
(not `select`).

<details>
<summary>Solution</summary>

```bash
jq -r '
  .adjusting_entries[] |
  if .debit.amount >= 5
  then "\(.id): $\(.debit.amount) - \(.description)"
  else empty
  end
' accounting/src/data/08-adjusting-entries.json
```

```
ADJ-003: $5.00 - Neighbor moved away - uncollectible receivable
```

ADJ-001 and ADJ-002 ($4 each) are swallowed by `empty`.

</details>

### Exercise 4: Summary with `{$var}` Shorthand

Compute total assets and total L+OE from pre-adjustment balances.
Build `{"total_assets": 119, "total_l_oe": 119, "balanced": true}`.

<details>
<summary>Solution</summary>

```bash
jq '
  .pre_adjustment_balances | . as {
    $cash, accounts_receivable: $ar, $inventory,
    prepaid_insurance: $prepaid, $equipment,
    accumulated_depreciation: $accum_dep,
    notes_payable: $notes, owners_equity: $oe,
    retained_earnings: $re
  } |
  ($cash + $ar + $inventory + $prepaid + $equipment - $accum_dep) as $total_assets |
  ($notes + $oe + $re) as $total_l_oe |
  ($total_assets == $total_l_oe) as $balanced |
  {$total_assets, $total_l_oe, $balanced}
' accounting/src/data/08-adjusting-entries.json
```

```json
{"total_assets": 119, "total_l_oe": 119, "balanced": true}
```

</details>

### Exercise 5: Verify Balance After Each Adjustment

Use `foreach` to track *both* total assets and total L+OE after each
step.  Confirm they stay equal.

<details>
<summary>Solution</summary>

```bash
jq -r '
  .pre_adjustment_balances as $bal |
  ($bal.cash + $bal.accounts_receivable + $bal.inventory
   + $bal.prepaid_insurance + $bal.equipment
   - $bal.accumulated_depreciation) as $starting_assets |
  ($bal.notes_payable + $bal.owners_equity
   + $bal.retained_earnings) as $starting_l_oe |
  foreach .adjusting_entries[] as $entry (
    { assets: $starting_assets, l_oe: $starting_l_oe };
    .assets -= $entry.debit.amount
    | .l_oe -= $entry.debit.amount;
    "\($entry.id): Assets=\(.assets), L+OE=\(.l_oe), balanced=\(.assets == .l_oe)"
  )
' accounting/src/data/08-adjusting-entries.json
```

```
ADJ-001: Assets=115, L+OE=115, balanced=true
ADJ-002: Assets=111, L+OE=111, balanced=true
ADJ-003: Assets=106, L+OE=106, balanced=true
```

The books balance after every adjustment -- the fundamental invariant
of double-entry bookkeeping.

</details>

---

**Next up**: [Lesson 09 -- Cash Flow](09-cash-flow-statement.md), where
you build a cash flow statement and learn `while`, `until`, `recurse`,
and date operations.
