# Lesson 10 -- Checking Your Work: Trial Balance and Validation

> **Prerequisites**: Lessons [01](01-opening-day.md) through
> [08](08-adjustments-and-accruals.md).

## The Story So Far

June is over.  Before closing the books, you need to **check your
work**.  In accounting this check is called a **trial balance**: add up
every debit balance and every credit balance -- the totals must match.

Your mom says: "First we make sure every account code is valid.  Then
we check that names are consistent.  Then we add up the columns."

Today you will build a validation program that does this automatically,
using jq's **regular expressions** and **path operations**.

---

## Setup

Data: `accounting/src/data/10-general-ledger.json`

```bash
jq '.ledger | length' accounting/src/data/10-general-ledger.json
jq '.ledger[0]' accounting/src/data/10-general-ledger.json
```

The `.ledger` array holds one object per account, each with a code,
name, normal balance, and entries array.  This ledger contains
**deliberate errors** for you to find.

---

## 1. Regex = SEARCH() on Steroids

| Excel | jq | What it does |
|-------|-----|-------------|
| `SEARCH("abc", A1)` | `test("abc")` | Does it match? true/false |
| `FIND("abc", A1)` | `match("abc")` | Where does it match? offset + length |
| `SUBSTITUTE(A1,"a","b")` | `sub("a"; "b")` / `gsub("a"; "b")` | Replace first / all |
| *(none)* | `capture("(?<n>pat)")` | Extract named groups into object |
| *(none)* | `scan("pat")` | Find ALL matches as array |

### `test` -- Does It Match?

```bash
jq -n '"1000" | test("^[1-6]\\d{3}$")'   # true
jq -n '"9999" | test("^[1-6]\\d{3}$")'   # false
```

Pattern `^[1-6]\d{3}$`: start `^`, one digit 1-6, three more digits,
end `$`.  In jq strings, backslashes double: write `\\d` to get `\d`.

**Validate account codes:**

```bash
jq '[.ledger[] | select(.code | test("^[1-6]\\d{3}$") | not) | {code, name}]' \
  accounting/src/data/10-general-ledger.json
```

### `match` and `capture` -- Match Details

```bash
jq -n '"Account 1000" | match("\\d+")'
# {"offset":8,"length":4,"string":"1000","captures":[]}

jq -n '"4000" | capture("^(?<category>[1-6])(?<seq>\\d{3})$")'
# {"category":"4","seq":"000"}
```

`capture` is like `LEFT()` + `MID()` + `RIGHT()` in one step.

### `scan` -- All Matches

```bash
jq -n '"Paid $50 and $12" | [scan("\\$\\d+")]'
# ["$50","$12"]
```

### `sub` / `gsub` -- Find and Replace

```bash
jq -n '"depreciation_expense" | gsub("_"; " ")'
# "depreciation expense"

jq -n '"cash" | sub("^(?<c>.)"; .c | ascii_upcase)'
# "Cash"
```

---

## 2. Recursive Descent `..` -- Search All Levels

**Excel analogy**: Find & Replace across all sheets.  `..` walks into
every level of a JSON structure and produces every value.

```bash
# Every empty string anywhere in the file
jq '[.. | strings | select(. == "")]' \
  accounting/src/data/10-general-ledger.json

# Every number equal to 31
jq '[.. | numbers | select(. == 31)]' \
  accounting/src/data/10-general-ledger.json
```

Use `..` when you do not know where a value lives.  Combine with
`scalars`, `numbers`, `strings`, or `select` to filter.

---

## 3. Path Operations -- Cell Addresses You Can Compute

Every JSON value has a **path** -- an array of keys/indices that
locates it, like a cell address `$B$7`.

| Excel | jq | What it does |
|-------|-----|-------------|
| `$B$7` | `["ledger", 0, "code"]` | Address of a value |
| `INDIRECT("B7")` | `getpath([...])` | Read value at address |
| Writing to a cell | `setpath([...]; val)` | Write value at address |
| *(none)* | `path(.ledger[0].code)` | Compute address of expression |
| *(none)* | `paths(cond)` | Find ALL addresses matching condition |
| *(none)* | `delpaths([...])` | Delete values at multiple addresses |

```bash
# Address of first account's code
jq 'path(.ledger[0].code)' accounting/src/data/10-general-ledger.json
# ["ledger",0,"code"]

# Read value at that address
jq 'getpath(["ledger", 0, "code"])' accounting/src/data/10-general-ledger.json
# "1000"

# Find every path leading to the number 31
jq '[paths(type == "number" and . == 31)]' \
  accounting/src/data/10-general-ledger.json

# Remove all accounts with invalid codes
jq '
  [.ledger | to_entries[] |
    select(.value.code | test("^[1-6]\\d{3}$") | not) |
    ["ledger", .key]
  ] as $bad | delpaths($bad) | .ledger | length
' accounting/src/data/10-general-ledger.json
```

---

## 4. `error("message")` -- Stopping on Bad Data

```bash
jq -n '"9999" | if test("^[1-6]\\d{3}$") then . else error("Bad code: " + .) end'
# jq: error (at <stdin>:0): Bad code: 9999
```

Use `error` when bad data should halt the pipeline.  Use `try-catch`
(Lesson 06) to handle errors gracefully.

---

## 5. The Validation Program

Run it:

```bash
jq -f accounting/src/programs/10-validate-ledger.jq \
  accounting/src/data/10-general-ledger.json
```

The program performs seven checks:

1. **Account code validation** -- `test("^[1-6]\\d{3}$")`
2. **Name consistency** -- `group_by(.code)`, flag different names
3. **Missing descriptions** -- `select(.description == "")`
4. **Suspicious amounts** -- entries in invalid accounts
5. **Path demonstration** -- `paths(. == 31)` shows exact location
6. **Error summary** -- counts all issues
7. **Trial balance** -- computes balances, checks debits = credits

### Understanding the Trial Balance

The program merges accounts by code.  Because the erroneous "cash"
(lowercase) shares code 1000 with the real "Cash", its $13 credit
gets merged in, reducing Cash from $62 to $49.

**Before fixing errors** -- the trial balance is OUT OF BALANCE:

| Code | Account                  | Debit     | Credit    |
|------|--------------------------|-----------|-----------|
| 1000 | Cash                     | $49.00    |           |
| 1300 | Prepaid Insurance        | $8.00     |           |
| 1400 | Equipment                | $40.00    |           |
| 1410 | Accumulated Depreciation |           | $4.00     |
| 2100 | Notes Payable            |           | $50.00    |
| 3000 | Owner's Equity           |           | $50.00    |
| 4000 | Revenue                  |           | $51.00    |
| 5000 | Cost of Goods Sold       | $25.00    |           |
| 6000 | Wages Expense            | $3.00     |           |
| 6100 | Advertising Expense      | $2.00     |           |
| 6200 | Insurance Expense        | $4.00     |           |
| 6300 | Depreciation Expense     | $4.00     |           |
| 6400 | Bad Debt Expense         | $5.00     |           |
| 6500 | Interest Expense         | $2.00     |           |
|      | **TOTALS**               | **$142.00** | **$155.00** |

The $13 gap is the smoking gun.  **After fixing** (remove the erroneous
duplicate), Cash returns to $62 and totals balance at **$155 = $155**.

> This is a **pre-closing** trial balance.  Income accounts are still
> open.  Exercise 5 generates the closing entry.

---

## Accounting Sidebar: Trial Balance and Error Detection

A trial balance verifies **total debits = total credits**.  It does not
prove the books are perfect (you could post to the wrong account), but
it catches one-sided entries, transpositions ($31 vs $13), and miskeyed
amounts.

**Account code conventions:**

| Range | Category |
|-------|----------|
| 1xxx | Assets |
| 2xxx | Liabilities |
| 3xxx | Equity |
| 4xxx | Revenue |
| 5xxx | Cost of Goods Sold |
| 6xxx | Expenses |

Code "9999" does not fit any category -- invalid.

---

## Deep Dive

- **Regex**: [08-regex.md](../08-regex.md)
- **Path operations**: [09-path-operations.md](../09-path-operations.md)

---

## Exercises

### Exercise 1: Find the Four Errors

The ledger has four deliberate errors.  Use jq to find all four.

<details>
<summary>Solution</summary>

```bash
# Error 1: Invalid code
jq '[.ledger[] | select(.code | test("^[1-6]\\d{3}$") | not) | {code, name}]' \
  accounting/src/data/10-general-ledger.json

# Error 2: Transposed amount ($31 instead of $13)
jq '.ledger[] | select(.code == "9999") | .entries[]' \
  accounting/src/data/10-general-ledger.json

# Error 3: Missing description
jq '[.ledger[].entries[] | select(.description == "")]' \
  accounting/src/data/10-general-ledger.json

# Error 4: Inconsistent casing ("Cash" vs "cash")
jq '[.ledger[] | {code, name}] | group_by(.code) |
  map(select(length > 1)) |
  map({code: .[0].code, names: [.[].name] | unique}) |
  map(select(.names | length > 1))' \
  accounting/src/data/10-general-ledger.json
```

1. Code "9999" (Suspense) -- not in 1xxx-6xxx range
2. $31.00 debit in Suspense -- should be $13.00
3. Empty description in the duplicate "1000/cash" entry
4. "cash" (lowercase) vs "Cash" for code 1000

</details>

### Exercise 2: Regex Account Classifier

Use `capture` and `group_by` to classify valid accounts by their
first digit.  Output: `{"Assets": ["1000",...], "Revenue": ["4000"], ...}`

<details>
<summary>Solution</summary>

```bash
jq '
  def category_name:
    if   . == "1" then "Assets"
    elif . == "2" then "Liabilities"
    elif . == "3" then "Equity"
    elif . == "4" then "Revenue"
    elif . == "5" then "COGS"
    elif . == "6" then "Expenses"
    else "Unknown" end;

  [.ledger[] | select(.code | test("^[1-6]\\d{3}$")) | .code] | unique |
  group_by(.[0:1]) |
  map({key: (.[0] | capture("^(?<d>.)") | .d | category_name), value: .}) |
  from_entries
' accounting/src/data/10-general-ledger.json
```

</details>

### Exercise 3: Fix Errors with Path Operations

Remove invalid-code accounts with `delpaths`, normalize names with
`gsub`, merge duplicate-code accounts.

<details>
<summary>Solution</summary>

```bash
jq '
  # Remove invalid codes
  ([.ledger | to_entries[] |
    select(.value.code | test("^[1-6]\\d{3}$") | not) |
    ["ledger", .key]
  ]) as $bad | delpaths($bad) |

  # Normalize names and merge duplicates
  .ledger |= (
    map(.name |= gsub("(?<w>\\b\\w)"; .w | ascii_upcase)) |
    group_by(.code) |
    map(if length == 1 then .[0]
        else .[0] + {entries: [.[].entries[]]}
        end)
  ) |
  {accounts: (.ledger | length), codes: [.ledger[].code]}
' accounting/src/data/10-general-ledger.json
```

</details>

### Exercise 4: Detect Transposition Errors

Find every amount where reversing digits produces a different number
that also appears in the ledger.

<details>
<summary>Solution</summary>

```bash
jq '
  [.. | numbers | select(. > 0)] | unique as $all |
  [$all[] |
    . as $n |
    (tostring | explode | reverse | implode | tonumber) as $rev |
    select($rev != $n and ($all | index($rev) != null)) |
    {original: $n, reversed: $rev}
  ] | unique_by(.original)
' accounting/src/data/10-general-ledger.json
```

Finds (13, 31): the $31 in Suspense is likely a transposition of $13.

</details>

### Exercise 5: Generate the Closing Entry

Generate the journal entry that closes income accounts to Retained
Earnings.  Debit Revenue, credit each expense, credit RE for net income.

<details>
<summary>Solution</summary>

```bash
jq '
  [.ledger[] |
    select(.code | test("^[1-6]\\d{3}$")) |
    { code, name,
      bal: (([.entries[].debit] | add // 0) - ([.entries[].credit] | add // 0)) }
  ] |
  (map(select(.code | test("^4"))) | map(.bal) | add // 0 | fabs) as $rev |
  (map(select(.code | test("^[56]"))) | map(.bal) | add // 0) as $exp |
  ($rev - $exp) as $net |
  {
    description: "Close income accounts to Retained Earnings",
    entries: (
      [.[] | select(.code | test("^4")) |
        {account: .code, name, debit: (.bal | fabs), credit: 0}] +
      [.[] | select(.code | test("^[56]")) |
        {account: .code, name, debit: 0, credit: .bal}] +
      [{account: "3100", name: "Retained Earnings", debit: 0, credit: $net}]
    )
  }
' accounting/src/data/10-general-ledger.json
```

Revenue ($51) - Expenses ($45) = Net Income ($6).

</details>

---

## Summary

| Feature | What It Does | Excel Analogy |
|---------|-------------|---------------|
| `test("regex")` | Returns true/false | `ISNUMBER(SEARCH(...))` |
| `match("regex")` | Match details | `FIND()` + `MID()` |
| `capture("(?<n>...)")` | Named groups | Multiple `MID()` calls |
| `scan("regex")` | All matches | *(none)* |
| `sub` / `gsub` | Replace first / all | `SUBSTITUTE()` |
| `..` | Recursive descent | Find across all sheets |
| `path` / `paths` | Compute addresses | Cell reference / Find All |
| `getpath` / `setpath` | Read / write at address | `INDIRECT()` |
| `delpaths` | Delete at addresses | Delete multiple cells |
| `error("msg")` | Halt on bad data | `#VALUE!` |

---

**Next up**: [Lesson 11 -- Financial Statements](11-financial-statements.md),
where you produce a complete set of financial statements using `INDEX`,
`@csv`, `walk`, and modules.
