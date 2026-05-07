# Lesson 02 -- Buying Supplies: Numbers and Calculations

> **Previously**: You invested $50 in your lemonade stand (Lesson 01).
> Cash $50, Owner's Equity $50. The books balance.
>
> **Today**: You go shopping. You spend $10 of your $50 cash -- but you
> didn't *lose* $10. You traded one asset (cash) for another (inventory).

## The Shopping Trip

| Item    | Qty | Unit Price | Total |
|---------|-----|-----------|-------|
| Lemons  |  12 | $0.50     | $6.00 |
| Sugar   |   2 | $1.50     | $3.00 |
| Cups    |  20 | $0.05     | $1.00 |
| **Total** |   | | **$10.00** |

```
Before:  Cash $50  +  Inventory  $0  =  $50 total assets
After:   Cash $40  +  Inventory $10  =  $50 total assets
```

> **Accounting sidebar**: When an asset changes form (cash to inventory),
> the balance sheet still balances. No money was "lost" -- it just
> changed form. The business is still worth $50.

Open the data file and explore: `jq . accounting/src/data/02-purchases.json`

## jq Types: What Kind of Data Is This?

In Excel, a cell holds a number, text, TRUE/FALSE, or is empty. JSON has
similar categories called **types**.

| jq type   | Excel equivalent     | Example                |
|-----------|---------------------|------------------------|
| `number`  | number cell          | `50.00`, `12`, `0.05`  |
| `string`  | text cell            | `"Lemons"`, `"2024-06-01"` |
| `boolean` | TRUE / FALSE         | `true`, `false`        |
| `null`    | empty cell           | `null`                 |
| `array`   | a column of data     | `[6.00, 3.00, 1.00]`  |
| `object`  | a row with headers   | `{"cash": 40}` |

The `type` function tells you what you have, like Excel's `TYPE()`.

```bash
jq '.starting_cash | type' accounting/src/data/02-purchases.json   # "number"
jq '.date | type' accounting/src/data/02-purchases.json             # "string"
jq '.purchases | type' accounting/src/data/02-purchases.json        # "array"
jq '.balance_sheet | type' accounting/src/data/02-purchases.json    # "object"
```

## Arithmetic: Your Calculator

In Excel you write `=A1+B1`. In jq you write `.field1 + .field2`.

```bash
# Total cost of all purchases (Excel: =SUM(D2:D4))
jq '[.purchases[].total] | add' accounting/src/data/02-purchases.json
# 10

# Remaining cash (Excel: =B1-SUM(D2:D4))
jq '.starting_cash - ([.purchases[].total] | add)' accounting/src/data/02-purchases.json
# 40
```

All five arithmetic operators:

```bash
jq -n '6 + 3'     # 9    addition        (Excel: =6+3)
jq -n '6 - 3'     # 3    subtraction      (Excel: =6-3)
jq -n '6 * 3'     # 18   multiplication   (Excel: =6*3)
jq -n '6 / 3'     # 2    division         (Excel: =6/3)
jq -n '7 % 3'     # 1    remainder/modulo (Excel: =MOD(7,3))
```

Cost per cup of lemonade -- total supplies divided by servings:

```bash
jq '([.purchases[].total] | add) / .purchases[2].quantity' \
  accounting/src/data/02-purchases.json
# 0.5
```

Fifty cents per cup. Sell for $1.00 and that's a 50% margin.

## Comparison Operators

In Excel you write `=A1>B1` and get TRUE or FALSE. Same idea in jq, but
"not equal" is spelled `!=` instead of `<>`.

| Excel | jq   | Meaning            |
|-------|------|--------------------|
| `=`   | `==` | equal              |
| `<>`  | `!=` | not equal          |
| `<`   | `<`  | less than          |
| `>`   | `>`  | greater than       |
| `<=`  | `<=` | less than or equal |
| `>=`  | `>=` | greater than or equal |

```bash
# Did lemons cost more than sugar?
jq '.purchases[0].total > .purchases[1].total' accounting/src/data/02-purchases.json
# true

# Is cash still equal to starting cash?
jq '.balance_sheet.assets.cash == .starting_cash' accounting/src/data/02-purchases.json
# false
```

## Logical Operators

Excel has `AND()`, `OR()`, `NOT()`. jq uses keywords: `and`, `or`, `not`.

```bash
jq -n '(6 > 5) and (3 < 100)'    # true   (Excel: =AND(6>5, 3<100))
jq -n '(6 > 5) or (3 > 100)'     # true   (Excel: =OR(6>5, 3>100))
jq -n 'true | not'                # false  (Excel: =NOT(TRUE))
```

Verify an accounting rule -- cash went down AND inventory went up:

```bash
jq '(.balance_sheet.assets.cash < .starting_cash) and
    (([.balance_sheet.assets.inventory | to_entries[].value] | add) > 0)' \
  accounting/src/data/02-purchases.json
# true
```

## Truthiness: The Biggest Gotcha

**In Excel**, `0` is falsy. Empty string `""` is falsy. You know this
from `=IF(A1, "yes", "no")` where a zero cell gives "no".

**In jq, only `false` and `null` are falsy.** Everything else is truthy:

| Value     | jq       | Excel    |
|-----------|:--------:|:--------:|
| `false`   | falsy    | falsy    |
| `null`    | falsy    | falsy    |
| `0`       | **truthy** | falsy  |
| `""`      | **truthy** | falsy  |
| `[]`      | **truthy** | (N/A)  |
| `42`      | truthy   | truthy   |

```bash
jq -n 'if 0 then "truthy" else "falsy" end'      # "truthy" -- different from Excel!
jq -n 'if "" then "truthy" else "falsy" end'      # "truthy" -- different from Excel!
jq -n 'if false then "truthy" else "falsy" end'   # "falsy"
jq -n 'if null then "truthy" else "falsy" end'    # "falsy"
```

> **Why this matters**: If you check whether an account balance is
> "truthy" to see if it has money, $0.00 will still be truthy in jq.
> Use explicit comparisons like `== 0` or `> 0` instead.

## String Interpolation: Building Reports

Excel joins text with `&`: `="Cash: $" & B1`. jq uses `\(...)` inside
a quoted string to embed any expression.

```bash
jq -r '"Cash remaining: $\(.balance_sheet.assets.cash)"' \
  accounting/src/data/02-purchases.json
# Cash remaining: $40

jq -r '"We bought \(.purchases | length) items for $\([.purchases[].total] | add)"' \
  accounting/src/data/02-purchases.json
# We bought 3 items for $10
```

The `-r` flag removes surrounding quotes for clean output.

## `length` on Different Types

`length` adapts to whatever you give it:

```bash
jq '.purchases | length' accounting/src/data/02-purchases.json              # 3 (array: count elements, like COUNTA)
jq '.balance_sheet.assets.inventory | length' accounting/src/data/02-purchases.json  # 3 (object: count keys)
jq '.purchases[0].item | length' accounting/src/data/02-purchases.json      # 6 (string: character count, like LEN)
jq -n '-42 | length'                                                         # 42 (number: absolute value)
jq -n 'null | length'                                                        # 0
```

## `abs`: Absolute Value

Same as Excel's `ABS()`.

```bash
jq -n '-10 | abs'    # 10

# How much did cash change? (always positive)
jq '(.balance_sheet.assets.cash - .starting_cash) | abs' \
  accounting/src/data/02-purchases.json
# 10
```

## Type Conversion: `tonumber`, `tostring`, `toboolean`

Sometimes data arrives as the wrong type -- a price as `"6.00"` instead
of `6.00`. These convert between types.

```bash
jq -n '"42" | tonumber'       # 42     (Excel: VALUE("42"))
jq -n '42 | tostring'         # "42"   (Excel: TEXT(42,"0"))
jq -n '"true" | toboolean'    # true   (jq 1.8, no Excel equivalent)
```

> **Tip**: `\(...)` auto-converts to string, so you rarely need
> `tostring` inside interpolation. But `+` for concatenation requires
> both sides to be the same type.

## `--arg` and `--argjson`: Passing Values In

Pass values from the command line without editing the data file.

```bash
# --arg passes a STRING (like typing into a text cell)
jq -n --arg item "Lemons" '"You bought: \($item)"'
# "You bought: Lemons"

# --argjson passes a NUMBER or JSON value (like typing into a number cell)
jq -n --argjson price 0.75 '"Price per cup: $\($price)"'
# "Price per cup: $0.75"
```

Use `--argjson` when you need arithmetic. `--arg` always gives a string:

```bash
# What-if: profit per cup at a different selling price
jq --argjson sell_price 1.25 \
  '([.purchases[].total] | add) / .purchases[2].quantity |
   "Cost per cup: $\(.). Profit at $\($sell_price): $\($sell_price - .)"' \
  accounting/src/data/02-purchases.json
# "Cost per cup: $0.5. Profit at $1.25: $0.75"
```

## Verifying the Balance Sheet Equation

**Assets = Liabilities + Owner's Equity.** Let's prove it:

```bash
jq '
  (.balance_sheet.assets.cash +
    ([.balance_sheet.assets.inventory | to_entries[].value] | add)
  ) as $assets |
  0 as $liabilities |
  .balance_sheet.owners_equity.invested_capital as $equity |
  {
    assets: $assets,
    liabilities: $liabilities,
    owners_equity: $equity,
    balanced: ($assets == $liabilities + $equity)
  }
' accounting/src/data/02-purchases.json
```

```json
{
  "assets": 50,
  "liabilities": 0,
  "owners_equity": 50,
  "balanced": true
}
```

> **Accounting sidebar**: Assets changed form (cash became inventory)
> but total stayed at $50. The equation holds: $50 = $0 + $50.

## Run the Full Program

```bash
jq -r -f accounting/src/programs/02-calculate-costs.jq accounting/src/data/02-purchases.json
```

> **Deep dive**: For more on types and operators, see
> [02-types-and-operators.md](../02-types-and-operators.md) in the
> developer tutorials.

## What You Learned

| jq concept          | Excel equivalent         | Example                             |
|---------------------|-------------------------|-------------------------------------|
| `type`              | `TYPE()`                | `.starting_cash \| type` -> "number" |
| `+ - * / %`         | `+ - * / MOD()`         | `.starting_cash - 10` -> 40         |
| `== != < > <= >=`   | `= <> < > <= >=`        | `.cash > 0` -> true                |
| `and`, `or`, `not`  | `AND()`, `OR()`, `NOT()`| `(true) and (true)` -> true        |
| Truthiness          | (different!)            | `0` is truthy in jq, falsy in Excel |
| `\(...)`            | `& / CONCAT()`          | `"Cash: $\(.cash)"`               |
| `length`            | `LEN / COUNTA`          | `.purchases \| length` -> 3        |
| `abs`               | `ABS()`                 | `-10 \| abs` -> 10                 |
| `tonumber/tostring` | `VALUE() / TEXT()`      | `"42" \| tonumber` -> 42           |
| `toboolean`         | (no equivalent)         | `"true" \| toboolean` -> true      |
| `--arg`             | typing into a text cell | `--arg item "Lemons"`              |
| `--argjson`         | typing into a number cell | `--argjson price 0.75`           |

## Exercises

**Exercise 1**: What is the average cost per purchase? (Hint: total
divided by number of purchases.)

**Exercise 2**: Using `--argjson`, calculate profit per cup if you sell
at $1.25 instead of $1.00.

**Exercise 3**: Write a jq expression that checks all three: (a) cash
decreased, (b) inventory total equals cash decrease, (c) balance sheet
balances. Output a single `true` or `false`.

**Exercise 4**: What does `0 | not` produce? What about `"" | not`?
Explain why, based on jq's truthiness rules.

<details>
<summary>Solutions</summary>

```bash
# Exercise 1: Average cost per purchase (Excel: =AVERAGE(D2:D4))
jq '([.purchases[].total] | add) / (.purchases | length)' \
  accounting/src/data/02-purchases.json
# 3.3333333333333335

# Exercise 2: Profit per cup at $1.25
jq --argjson sell_price 1.25 \
  '$sell_price - (([.purchases[].total] | add) / .purchases[2].quantity)' \
  accounting/src/data/02-purchases.json
# 0.75

# Exercise 3: All three conditions
jq '
  (.balance_sheet.assets.cash < .starting_cash) as $cash_down |
  (([.balance_sheet.assets.inventory | to_entries[].value] | add)
    == (.starting_cash - .balance_sheet.assets.cash)) as $inv_matches |
  ((.balance_sheet.assets.cash +
    ([.balance_sheet.assets.inventory | to_entries[].value] | add))
    == .balance_sheet.owners_equity.invested_capital) as $balanced |
  $cash_down and $inv_matches and $balanced
' accounting/src/data/02-purchases.json
# true

# Exercise 4: Truthiness
jq -n '0 | not'    # false -- 0 is TRUTHY in jq, so not-truthy = false
jq -n '"" | not'   # false -- "" is TRUTHY in jq, so not-truthy = false
# In Excel, both would give TRUE because 0 and "" are falsy there.
```

</details>

---

**Next up**: [Lesson 03 -- First Sales](03-first-sales.md). You open the
stand, sell lemonade, and learn to work with lists using arrays, `map`,
and `select`.
