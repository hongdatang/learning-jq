# Lesson 09 -- Following the Money: Cash Flow Statement

> **Prerequisites**: You have read Lessons
> [01](01-opening-day.md) through [08](08-adjustments-and-accruals.md). You know
> `reduce`, `foreach`, `group_by`, `map`, `select`, `def`, `if-then-else`,
> `try-catch`, `|=`, `+=`, and `del`.

## The Story So Far

Two weeks have passed. Your lemonade stand is booming -- you took out a $50 bank
loan, bought a $40 cooler, started selling on credit, and even paid for
insurance. After adjustments (depreciation, prepaid insurance, bad debt), your
income statement shows **$6 in retained earnings**.

Then Aunt Rosa visits. She looks at your books and asks the question every
business owner dreads:

*"You say you made money. But do you actually have enough cash to pay your
bills next week?"*

You open the cash box and count: **$62.**

That is strange. You only earned $6 in profit, but you have $62 in cash. Where
did the extra $56 come from? And could you be profitable but *broke*?

This is the question the **cash flow statement** answers. It traces every dollar
that physically entered or left your cash box -- not what you earned, not what
you are owed, but what you can actually spend.

---

## Setup

All commands run from the **project root**. The data file is at
`accounting/src/data/09-cash-movements.json`.

Quick check -- print the whole file:

```bash
jq '.' accounting/src/data/09-cash-movements.json
```

The file contains a `beginning_cash` balance ($0 -- the stand started from
nothing) and a `movements` array: 20 cash transactions across June, each tagged
with a `section` (operating, investing, or financing).

```json
{ "id": 1, "date": "2024-06-01", "description": "Owner investment", "amount": 50.00, "section": "financing" }
```

Three things are deliberately **missing** from this data:

1. The **$5 credit sale** from Week 2 -- Coach Davis bought lemonade on credit.
   Revenue was recognized on the income statement, but no cash changed hands.
2. **Depreciation** ($4 on the cooler) -- an adjusting entry that reduces book
   value but does not move cash.
3. **Bad debt expense** ($5 write-off) -- another adjustment, no cash moved.

The cash flow statement only cares about cash that physically moved.

---

## Accounting Sidebar: The Three Sections of Cash Flow

Every cash flow statement divides cash movements into three sections:

| Section | What it covers | Our examples |
|---------|----------------|--------------|
| **Operating** | Day-to-day business | Sales, supplies, wages, insurance, interest |
| **Investing** | Buying/selling long-term assets | Equipment purchase |
| **Financing** | Owners and lenders | Owner investment, bank loan |

The bottom line adds up all three:

```
  Net Operating        $2.00
+ Net Investing      -$40.00
+ Net Financing     +$100.00
= Net Change in Cash  $62.00
+ Beginning Cash       $0.00
= Ending Cash         $62.00
```

> **Why profit does not equal cash**: You have $6 in retained earnings but $62 in
> cash. The $56 gap comes from non-income cash: the owner put in $50
> (financing), the bank loaned $50 (financing), and you spent $40 on equipment
> (investing). Loans and investments are not income -- they do not appear on the
> income statement -- but they absolutely affect your cash.

This is the single most important lesson in accounting: **a profitable business
can run out of cash, and a cash-rich business can be unprofitable.** The income
statement tells you what you *earned*. The cash flow statement tells you what
you can *spend*.

---

## 1. `group_by` + `map` Pipeline -- Section Subtotals

**Excel analogy**: You have a column of transactions with a "Section" label in
column D. You create a pivot table: group by Section, sum the Amount column.
`group_by` + `map` is that pivot table.

```bash
jq '.movements | group_by(.section) | map({
  section: .[0].section,
  subtotal: (map(.amount) | add)
})' accounting/src/data/09-cash-movements.json
```

```json
[
  { "section": "financing", "subtotal": 100 },
  { "section": "investing", "subtotal": -40 },
  { "section": "operating", "subtotal": 2 }
]
```

How it works:

1. `.movements` -- start with the flat list of 20 transactions.
2. `group_by(.section)` -- sort and split into three sub-arrays, one per
   section. Like grouping rows by a label.
3. `map({...})` -- for each group, extract the section name and sum the amounts.

> **Cross-reference**: `group_by` was introduced in
> [Lesson 04](04-end-of-week.md). The pattern here is the same, just applied to
> cash flow sections instead of days of the week.

---

## 2. `reduce` With a Complex Accumulator

In [Lesson 05](05-the-balance-sheet.md) you used `reduce` with an object to
classify accounts into asset/liability/equity buckets. Here we do the same
thing, but the accumulator tracks **multiple counters per section**: inflows,
outflows, and transaction count.

**Excel analogy**: Imagine three helper rows at the bottom of your pivot table --
one for total inflows, one for total outflows, one for count. `reduce` builds
all three in a single pass.

```bash
jq '
  reduce .movements[] as $m (
    { operating: {in: 0, out: 0, n: 0},
      investing: {in: 0, out: 0, n: 0},
      financing: {in: 0, out: 0, n: 0} };
    .[$m.section].n += 1 |
    if $m.amount >= 0
    then .[$m.section].in += $m.amount
    else .[$m.section].out += $m.amount
    end
  )
' accounting/src/data/09-cash-movements.json
```

```json
{
  "operating": { "in": 46, "out": -44, "n": 17 },
  "investing": { "in": 0,  "out": -40, "n": 1  },
  "financing": { "in": 100, "out": 0,  "n": 2  }
}
```

The accumulator is a nested object. Each step:

1. Increments the transaction count: `.[$m.section].n += 1`
2. Routes the amount to `.in` or `.out` based on sign

This is more powerful than `group_by` because you control exactly what gets
accumulated. Use `group_by` when you want sub-arrays to process later; use
`reduce` when you want a single summary object.

---

## 3. `foreach` -- Running Cash Balance

**Excel analogy**: Column A has each transaction amount. Cell C1 starts at the
beginning balance. C2 = C1 + A2, C3 = C2 + A3, and so on. Each cell shows the
running balance *after* that transaction. `foreach` does exactly this -- it is
`reduce` that outputs at every step, not just at the end.

```bash
jq '[foreach .movements[] as $m (
  .beginning_cash;
  . + $m.amount;
  { id: $m.id, description: $m.description, amount: $m.amount, balance: . }
)]' accounting/src/data/09-cash-movements.json
```

```json
[
  { "id": 1,  "description": "Owner investment",  "amount": 50,  "balance": 50 },
  { "id": 2,  "description": "Buy lemons",        "amount": -6,  "balance": 44 },
  { "id": 3,  "description": "Buy sugar",         "amount": -3,  "balance": 41 },
  ...
  { "id": 20, "description": "Interest payment",  "amount": -2,  "balance": 62 }
]
```

The syntax: `foreach GENERATOR as $var (INIT; UPDATE; EXTRACT)`.

| Part | Purpose | Our example |
|------|---------|-------------|
| GENERATOR | Stream of inputs | `.movements[]` |
| $var | Current item | `$m` (one cash movement) |
| INIT | Starting state | `.beginning_cash` (0) |
| UPDATE | How state changes each step | `. + $m.amount` |
| EXTRACT | What to output each step | `{id, description, amount, balance: .}` |

> **Key difference from `reduce`**: `reduce` gives you one output (the final
> state). `foreach` gives you one output *per step*. Use `reduce` when you want
> a total; use `foreach` when you want a running column.

> **Cross-reference**: `foreach` was introduced in
> [Lesson 08](08-adjustments-and-accruals.md). Here we use the three-argument
> form (with EXTRACT) to shape each output.

---

## 4. `while(cond; update)` -- Projecting Cash Forward

**Excel analogy**: You type a starting value in A1, then a formula in A2
(`=A1+2`), and drag it down. You keep dragging **as long as** the value is under
100. `while` automates that: it keeps producing values as long as the condition
holds, then stops.

Aunt Rosa asks: "If you keep earning $2 per month in net cash, how long until
you have $100?"

```bash
jq -n '[62 | while(. < 100; . + 2)]'
```

```json
[62, 64, 66, 68, 70, 72, 74, 76, 78, 80, 82, 84, 86, 88, 90, 92, 94, 96, 98]
```

The syntax: `while(CONDITION; UPDATE)`.

- Starts with the input (62, your ending cash).
- Outputs the current value.
- Applies the update (add 2).
- Checks the condition. If still true, repeats. If false, stops.

Notice the output ends at 98, not 100. `while` outputs values where the
condition is true *before* the update. Once the value reaches 100, the condition
`< 100` is false and `while` stops without outputting 100.

> **Difference from `foreach`**: `foreach` processes a finite stream (your 20
> transactions). `while` generates its own stream by repeating an update -- it
> is a loop, not a scan. Use `foreach` when you have data to iterate over; use
> `while` when you are projecting forward from a starting point.

### Practical use: monthly cash projection

```bash
jq -n '
  { month: 0, cash: 62 }
  | [., while(.cash < 100;
       .month += 1 | .cash += 2)]
  | .[] | "Month \(.month): $\(.cash)"
'
```

```
"Month 0: $62"
"Month 1: $64"
"Month 2: $66"
...
"Month 18: $98"
```

By wrapping the state in an object, you can track multiple values (month number
and cash balance) simultaneously.

---

## 5. `until(cond; update)` -- Goal Seek

**Excel analogy**: Goal Seek. You set a target (loan balance = 0) and ask Excel
to find the input (how many months of $10 payments?). `until` does the same
thing: it keeps applying an update until a goal condition is met, then returns
the final state.

Your $50 bank loan needs to be paid off. If you save $10 per month for loan
payments, how many months does it take?

```bash
jq -n '
  { balance: 50, months: 0 }
  | until(.balance <= 0; .balance -= 10 | .months += 1)
  | "Loan paid off in \(.months) months"
'
```

```
"Loan paid off in 5 months"
```

The syntax: `until(CONDITION; UPDATE)`.

| Part | Purpose | Our example |
|------|---------|-------------|
| CONDITION | Stop when this is true | `.balance <= 0` |
| UPDATE | What to do each iteration | Subtract $10, increment month |

> **`while` vs `until`**: They are mirrors of each other.
> - `while(cond; f)` -- keep going **while** the condition is true. Outputs
>   every intermediate value. Stops *before* the condition becomes false.
> - `until(cond; f)` -- keep going **until** the condition is true. Outputs
>   only the final value. Stops *when* the condition becomes true.
>
> Rule of thumb: use `while` when you want to see all the steps (like filling
> cells down). Use `until` when you only care about the answer (like Goal Seek).

### Another example: when does cash double?

```bash
jq -n '
  { cash: 62, months: 0 }
  | until(.cash >= 124; .cash += 2 | .months += 1)
  | "Cash doubles in \(.months) months (to $\(.cash))"
'
```

```
"Cash doubles in 31 months (to $124)"
```

---

## 6. `recurse(f; cond)` -- Compound Interest

**Excel analogy**: A recursive formula. Cell A1 = 50, A2 = A1 * 1.04,
A3 = A2 * 1.04, and so on. Each cell depends on the one above. `recurse`
does the same thing: apply a function repeatedly, using the output of each
step as the input to the next.

What happens to your $50 loan at 4% monthly interest if you never pay?

```bash
jq -n '[50 | recurse(. * 1.04; . < 75)] | map(. * 100 | round / 100)'
```

```json
[50, 52, 54.08, 56.24, 58.49, 60.83, 63.27, 65.8, 68.43, 71.17, 74.01]
```

The syntax: `recurse(f; CONDITION)`.

- Starts with the input (50).
- Applies `f` (multiply by 1.04).
- Keeps going while the condition holds (balance under 75).
- Outputs every value in the chain.

Without the condition, `recurse(f)` runs forever (or until jq's stack limit).
Always provide a stopping condition.

> **`recurse` vs `while`**: Both produce a stream of values. The difference is
> subtle:
> - `while(cond; f)` checks the condition *before* outputting.
> - `recurse(f; cond)` outputs the value, *then* checks whether to continue.
>
> For most purposes they are interchangeable. `recurse` reads more naturally
> when the computation is inherently recursive (like compound interest).

### Practical use: how many periods until debt is "dangerous"?

```bash
jq -n '
  [50 | recurse(. * 1.04; . < 100)]
  | length - 1
  | "Debt doubles in \(.) months at 4% interest"
'
```

```
"Debt doubles in 18 months at 4% interest"
```

---

## 7. Date Functions -- Working with Time

**Excel analogy**: Excel has `TODAY()`, `TEXT(date, format)`, `DATEVALUE()`,
`WEEKNUM()`, and `YEAR()`. jq has equivalent functions for parsing, formatting,
and computing with dates.

### The Date Function Cheat Sheet

| jq function | Excel equivalent | What it does |
|-------------|-----------------|--------------|
| `now` | `NOW()` | Current Unix timestamp (seconds since 1970) |
| `todate` | `TEXT(A1, "yyyy-mm-ddThh:mm:ssZ")` | Unix timestamp to ISO 8601 |
| `strftime(fmt)` | `TEXT(A1, format)` | Format a timestamp with custom pattern |
| `strptime(fmt)` | `DATEVALUE(text)` | Parse a date string into a time array |
| `mktime` | (internal) | Convert time array to Unix timestamp |
| `gmtime` | (internal) | Convert Unix timestamp to time array (UTC) |
| `localtime` | (internal) | Convert Unix timestamp to time array (local timezone) |
| `strflocaltime(fmt)` | `TEXT(A1, format)` | Format a timestamp in local timezone |
| `todateiso8601` | `TEXT(A1, "yyyy-mm-ddThh:mm:ssZ")` | Timestamp to ISO 8601 string |
| `fromdateiso8601` | `DATEVALUE(iso_text)` | ISO 8601 string to timestamp |

### Parsing and formatting dates

Our data has dates like `"2024-06-01"`. To do date math, you need to parse
them into a number first:

```bash
# Parse a date string into a time array
jq -n '"2024-06-01" | strptime("%Y-%m-%d")'
# [2024,5,1,0,0,0,6,152]
#  year month day hour min sec weekday yearday
#       (0-indexed: 5 = June)

# Convert the time array to a Unix timestamp
jq -n '"2024-06-01" | strptime("%Y-%m-%d") | mktime'
# 1717200000

# Format it back into a readable string
jq -n '"2024-06-01" | strptime("%Y-%m-%d") | mktime | strftime("Started: %A, %B %d, %Y")'
# "Started: Saturday, June 01, 2024"
```

The pipeline is: **string -> strptime -> time array -> mktime -> timestamp**.
And the reverse: **timestamp -> gmtime -> time array -> strftime -> string**.

### Common format codes

| Code | Meaning | Example |
|------|---------|---------|
| `%Y` | 4-digit year | 2024 |
| `%m` | Month (01-12) | 06 |
| `%d` | Day (01-31) | 01 |
| `%A` | Full weekday name | Saturday |
| `%B` | Full month name | June |
| `%H` | Hour (00-23) | 14 |
| `%M` | Minute (00-59) | 30 |
| `%j` | Day of year (001-366) | 153 |

### Grouping transactions by week

Use `strptime` to extract the day-of-year, then divide by 7 to get a week
number:

```bash
jq '[.movements[] | {
  week: ((.date | strptime("%Y-%m-%d") | .[7]) / 7 | floor + 1),
  amount: .amount
}] | group_by(.week) | map({
  week: .[0].week,
  total: (map(.amount) | add),
  count: length
})' accounting/src/data/09-cash-movements.json
```

```json
[
  { "week": 22, "total": 51, "count": 7 },
  { "week": 23, "total": 18, "count": 10 },
  { "week": 24, "total": -7, "count": 3 }
]
```

Week 22 had a big positive swing (includes the $50 owner investment on June 1),
Week 23 was moderate (the loan and equipment purchase both fell in this week,
plus most sales), and Week 24 was negative (insurance and interest payments with
only Monday sales).

### ISO 8601 round-trip

```bash
# Date string -> ISO 8601 -> back to timestamp -> format
jq -n '
  "2024-06-01"
  | strptime("%Y-%m-%d") | mktime
  | todateiso8601
'
# "2024-06-01T00:00:00Z"
```

```bash
# ISO 8601 -> timestamp -> human-readable
jq -n '
  "2024-06-12T00:00:00Z"
  | fromdateiso8601
  | strftime("%B %d, %Y (%A)")
'
# "June 12, 2024 (Wednesday)"
```

### Extracting date components with `gmtime`

```bash
jq -n '
  "2024-06-01" | strptime("%Y-%m-%d") | mktime | gmtime
  | { year: .[0], month: (.[1] + 1), day: .[2], weekday: .[6], yearday: .[7] }
'
```

```json
{ "year": 2024, "month": 6, "day": 1, "weekday": 6, "yearday": 152 }
```

Note that months in the time array are 0-indexed (January = 0, June = 5), so
we add 1 for the human-readable month number.

### Current time with `now` and `todate`

`now` returns the current Unix timestamp. Pipe it to `todate` for ISO 8601:

```bash
jq -n 'now | todate'
# "2024-07-03T14:22:51Z"   (your output will differ)
```

This is handy for adding timestamps to reports or comparing "how old is this
transaction?"

### Local time with `localtime` and `strflocaltime`

The functions above (`gmtime`, `strftime`) always produce **UTC** times. If you
need the local timezone instead, use `localtime` and `strflocaltime`:

```bash
jq -n 'now | localtime | strflocaltime("%Y-%m-%d %H:%M")'
# "2024-07-03 10:22"   (your local time -- may differ from UTC)
```

| Function | Timezone | Use when... |
|----------|----------|-------------|
| `gmtime` / `strftime` | UTC | Storing dates, APIs, reproducible output |
| `localtime` / `strflocaltime` | Local | Displaying to a human in their timezone |

Both pairs take a Unix timestamp and produce formatted strings; they differ
only in which timezone offset is applied.

---

## 8. `index`, `indices`, and `rindex` -- Finding Transactions

**Excel analogy**: `MATCH("Equipment purchase", A:A, 0)` returns the row number
where a value appears. `index` does the same for arrays. `indices` returns *all*
matching positions (like pressing Ctrl+F and hitting "Find All"). `rindex`
returns the *last* match.

### Find one transaction

```bash
# Where is the equipment purchase in the movements array?
jq '.movements | map(.description) | index("Equipment purchase - cooler")' \
  accounting/src/data/09-cash-movements.json
# 11
```

Position 11 (zero-indexed) -- the 12th transaction.

### Find all matching positions

```bash
# Which positions are supply purchases?
jq '[.movements | to_entries[] | select(.value.description | startswith("Buy")) | .key]' \
  accounting/src/data/09-cash-movements.json
# [1, 2, 3, 12, 13, 14]
```

Six supply purchases -- three in Week 1, three in Week 2.

### `indices` with strings

`indices` also works on strings. Find all positions of a substring:

```bash
jq -n '"Buy lemons, Buy sugar, Buy cups" | indices("Buy")'
# [0, 12, 23]
```

### `rindex` -- find the last occurrence

`rindex` returns the position of the last match. It works on both strings
and arrays:

```bash
jq -n '"lemonade-stand-lemonade" | rindex("lemonade")'
# 15
```

Applied to our data -- find the last sale:

```bash
# Last sale in the movements array
jq '.movements | map(.description | startswith("Sales"))
  | [to_entries[] | select(.value == true) | .key] | last' \
  accounting/src/data/09-cash-movements.json
# 17
```

Position 17 -- the Monday sale in Week 2 (the last cash sale before insurance
and interest payments closed out the month).

---

## Run the Full Program

```bash
jq -rf accounting/src/programs/09-cash-flow.jq \
  accounting/src/data/09-cash-movements.json
```

The program produces the complete cash flow statement, followed by supplemental
sections demonstrating each jq feature.

### Walking Through the Program

Open `accounting/src/programs/09-cash-flow.jq` and follow along:

**Section 1: `group_by` + `map`** (lines 24-35) -- Groups the 20 movements by
section and computes subtotals. This drives the main three-section report.

**Section 2: `reduce` with object accumulator** (lines 42-54) -- A single pass
through all movements, tracking inflows, outflows, and count per section. The
accumulator is a nested object with three keys, each holding `{in, out, n}`.

**Section 3: `foreach`** (lines 61-72) -- Builds the running cash balance. Each
step outputs an object with the transaction details *and* the balance after that
transaction.

**Section 4: Date functions** (lines 78-91) -- Uses `strptime` to parse dates,
extracts the day-of-year, divides by 7 to get week numbers, then groups by week.

**Section 5: `index`/`indices`** (lines 98-110) -- Searches the movements array
for specific transactions by description.

**Section 6: `until`** (lines 116-122) -- Goal Seek: how many $10 payments to
pay off the $50 loan?

**Section 7: `while`** (lines 128-133) -- Projects monthly cash balances forward
while cash stays under $100.

**Section 8: `recurse`** (lines 139-144) -- Compound interest: what does $50
grow to at 4% monthly?

**Section 9: Date formatting** (lines 150-164) -- Demonstrates `strftime`,
`todateiso8601`, and `gmtime` for reformatting dates.

**Section 10: Profit vs Cash** (lines 170-183) -- The key accounting insight:
why $6 in earnings becomes $62 in cash.

---

## Accounting Sidebar: Reading the Cash Flow Statement

The cash flow statement answers a question the income statement cannot: **where
did the cash actually go?**

### The three sections, explained

**Operating Activities** -- Cash from running the business day to day. This is
the most important section because it shows whether the core business generates
cash. Our stand generated $2 net -- barely positive. Revenue from sales ($46)
was almost entirely eaten by supplies ($25), wages ($3), advertising ($2),
insurance ($12), and interest ($2).

**Investing Activities** -- Cash spent on (or received from) long-term assets.
We spent $40 on a cooler. This is not an expense -- it is an asset that will
last for years. But it still took $40 out of the cash box.

**Financing Activities** -- Cash from owners and lenders. The $50 owner
investment and $50 bank loan brought in $100. This money is not income -- you
have to pay back the loan, and the owner investment represents an obligation to
the owner. But it is very real cash.

### Direct vs indirect method

Our cash flow statement uses the **direct method**: list every cash transaction
and add them up. This is intuitive -- you can see every dollar that moved.

In professional accounting, the **indirect method** is more common. It starts
with net income and adjusts for non-cash items:

```
  Net Income                         $6.00
+ Depreciation                       $4.00   (non-cash expense, add back)
+ Bad Debt Expense                   $5.00   (non-cash expense, add back)
- Increase in A/R (credit sale)     -$5.00   (revenue recognized but no cash received)
- Increase in Prepaid Insurance     -$8.00   ($12 cash paid, only $4 expensed)
= Cash from Operations               $2.00
```

The indirect method agrees with our direct method ($2). The key is the prepaid
insurance adjustment: you paid $12 in cash for a three-month policy, but only
$4 was recognized as an expense this month. The remaining $8 sits on the
balance sheet as a prepaid asset -- real cash left the box, but it did not hit
the income statement. The indirect method captures this through the working
capital change (increase in prepaid insurance).

For now, the direct method is clearer: count the cash, sort it into three
buckets, add it up.

---

## What We Learned

| jq feature | Excel equivalent | What it does |
|-------------|-----------------|--------------|
| `while(cond; f)` | Fill down while condition holds | Generate values while a condition is true |
| `until(cond; f)` | Goal Seek | Iterate until a goal is reached; return final state |
| `recurse(f; cond)` | Recursive formula (A2=A1*1.04) | Apply a function repeatedly, output each step |
| `foreach ... as $x (init; update; extract)` | Running total column | Like `reduce` but outputs at every step |
| `reduce` with object accumulator | Multi-row pivot summary | Accumulate complex state in one pass |
| `group_by(.f) \| map(...)` | Pivot table | Group, then summarize each group |
| `strptime(fmt)` | `DATEVALUE()` | Parse a date string into a time array |
| `mktime` | (internal) | Time array to Unix timestamp |
| `strftime(fmt)` | `TEXT(date, format)` | Format a timestamp as a string |
| `gmtime` | (internal) | Unix timestamp to time array (UTC) |
| `todateiso8601` | `TEXT(A1, "yyyy-mm-ddT...")` | Timestamp to ISO 8601 string |
| `fromdateiso8601` | `DATEVALUE(iso_text)` | ISO 8601 string to timestamp |
| `now` | `NOW()` | Current Unix timestamp |
| `todate` | `TEXT(A1, "yyyy-mm-ddT...")` | Unix timestamp to ISO 8601 string |
| `localtime` | (internal) | Unix timestamp to time array (local timezone) |
| `strflocaltime(fmt)` | `TEXT(date, format)` | Format a timestamp in local timezone |
| `index(x)` | `MATCH(x, range, 0)` | Position of first occurrence in array |
| `indices(x)` | Find All | All positions where a value appears |
| `rindex(x)` | `MATCH` from bottom | Position of last occurrence |

---

## Exercises

All exercises use `accounting/src/data/09-cash-movements.json`.

### Exercise 1: Biggest Cash Day

Find the date with the largest total cash inflow (sum of positive amounts only).
Use `group_by(.date)` and `map` to group movements by date, filter to positive
amounts, sum them, then sort to find the winner.

<details>
<summary>Solution</summary>

```bash
jq '
  .movements
  | group_by(.date)
  | map({
      date: .[0].date,
      inflow: ([.[] | select(.amount > 0) | .amount] | add // 0)
    })
  | sort_by(.inflow)
  | last
' accounting/src/data/09-cash-movements.json
```

```json
{ "date": "2024-06-01", "inflow": 55 }
```

June 1st wins because of the $50 owner investment plus $5 in sales. But if you
filter to operating activities only:

```bash
jq '
  [.movements[] | select(.section == "operating")]
  | group_by(.date)
  | map({
      date: .[0].date,
      inflow: ([.[] | select(.amount > 0) | .amount] | add // 0)
    })
  | sort_by(.inflow) | last
' accounting/src/data/09-cash-movements.json
```

```json
{ "date": "2024-06-08", "inflow": 10 }
```

Saturday of Week 2 had the highest operating inflow: $10 in sales.

</details>

### Exercise 2: Running Balance With Alerts

Use `foreach` to build a running cash balance. For each step, add a `warning`
field that says `"LOW CASH"` if the balance drops below $50, and `"OK"`
otherwise. What is the first transaction where cash drops below $50?

<details>
<summary>Solution</summary>

```bash
jq '
  [foreach .movements[] as $m (
    .beginning_cash;
    . + $m.amount;
    { date: $m.date,
      description: $m.description,
      balance: .,
      warning: (if . < 50 then "LOW CASH" else "OK" end) }
  )]
  | map(select(.warning == "LOW CASH"))
  | first
' accounting/src/data/09-cash-movements.json
```

```json
{
  "date": "2024-06-01",
  "description": "Buy lemons",
  "balance": 44,
  "warning": "LOW CASH"
}
```

Cash drops below $50 immediately after the first supply purchase on Day 1.
The owner investment brought in $50, but the very next transaction (buying
lemons for $6) dropped it to $44. Cash does not recover to $50+ until the
Sunday sales come in.

</details>

### Exercise 3: Loan Payoff With Interest

The $50 loan charges 4% monthly interest. If you pay $12/month (enough to cover
interest plus principal), use `until` to find how many months it takes to pay
off. The state should track `{balance, months, total_paid}`. Each month: add
4% interest, then subtract $12 payment.

<details>
<summary>Solution</summary>

```bash
jq -n '
  { balance: 50, months: 0, total_paid: 0 }
  | until(.balance <= 0;
      .balance *= 1.04
      | .balance -= 12
      | .months += 1
      | .total_paid += 12)
  | "Paid off in \(.months) months, total paid: $\(.total_paid)"
'
```

```
"Paid off in 5 months, total paid: $60"
```

You pay $60 total on a $50 loan -- the extra $10 is interest. If you only paid
$2/month (just the interest), use `while` to see how the balance barely moves:

```bash
jq -n '[{balance: 50, month: 0} | while(.month < 6; .balance *= 1.04 | .balance -= 2 | .month += 1)]'
```

The balance grows because $2 does not even cover the monthly interest ($50 *
0.04 = $2). You would be treading water forever.

</details>

### Exercise 4: Reformat All Dates

Use `strptime` and `strftime` to reformat every movement's date from
`"2024-06-01"` to `"Sat, Jun 01"`. Output each movement as a string:
`"Sat, Jun 01 -- Owner investment: $50.00"`.

<details>
<summary>Solution</summary>

```bash
jq -r '
  .movements[] |
  (.date | strptime("%Y-%m-%d") | mktime | strftime("%a, %b %d")) as $fmt |
  "\($fmt) -- \(.description): $\(.amount)"
' accounting/src/data/09-cash-movements.json
```

```
Sat, Jun 01 -- Owner investment: $50
Sat, Jun 01 -- Buy lemons: $-6
Sat, Jun 01 -- Buy sugar: $-3
...
Wed, Jun 12 -- Interest payment: $-2
```

The `-r` flag strips the surrounding quotes for clean output. The pipeline is:
parse the date string, convert to a timestamp, then format with abbreviated
day and month names.

</details>

### Exercise 5: Operating Cash Burn Rate

Calculate the "burn rate" -- how quickly you spend cash on operations. For each
week (using date functions to group by week), calculate the ratio of operating
outflows to operating inflows. Which week had the worst burn rate?

<details>
<summary>Solution</summary>

```bash
jq '
  [.movements[] | select(.section == "operating") | {
    week: ((.date | strptime("%Y-%m-%d") | .[7]) / 7 | floor + 1),
    amount: .amount
  }]
  | group_by(.week)
  | map({
      week: .[0].week,
      inflow: ([.[] | select(.amount > 0) | .amount] | add // 0),
      outflow: ([.[] | select(.amount < 0) | .amount] | add // 0)
    })
  | map(. + {
      burn_rate: (if .inflow == 0 then "no income"
                  else ((.outflow | fabs) / .inflow * 100 | round | tostring) + "%"
                  end)
    })
' accounting/src/data/09-cash-movements.json
```

```json
[
  { "week": 22, "inflow": 13, "outflow": -12, "burn_rate": "92%" },
  { "week": 23, "inflow": 26, "outflow": -18, "burn_rate": "69%" },
  { "week": 24, "inflow": 7,  "outflow": -14, "burn_rate": "200%" }
]
```

Week 24 is the worst -- spending $2 for every $1 earned (insurance and interest
hit in a week with only one day of sales). Week 22 spent 92 cents of every
dollar. Week 23 was the most efficient at 69%, thanks to strong Saturday and
Sunday sales.

</details>

---

## Deep Dive

For a developer-focused treatment of `reduce`, `foreach`, and accumulators, see
[06-reduce-foreach.md](../06-reduce-foreach.md). For conditionals, `while`,
`until`, and `recurse`, see [04-control-flow.md](../04-control-flow.md).

---

**Next up**: [Lesson 10 -- The Trial Balance](10-trial-balance.md), where you
verify that every debit equals every credit using regex and path operations.
