# Lesson 07 -- Growing the Business: Loans, Equipment, and Credit

> **Prerequisites**: Lessons [01](01-opening-day.md)--[06](06-the-income-statement.md).
> You know `.`, `|`, `map`, `select`, `reduce`, `as $var`, `def`, `if-then-else`, `try-catch`.

## The Story So Far

Week 1 was a success: 20 cups sold, $22 revenue, $6 net income.

| Account           | Balance |
|--------------------|---------|
| Cash               | $56.00  |
| **Total Assets**   | **$56.00** |
| Owner's Equity     | $50.00  |
| Retained Earnings  | $6.00   |
| **Total L + OE**   | **$56.00** |

No debt, no equipment, no customers who owe you money.  But $6 profit
on $50 invested tells you the stand can work.  You decide to grow:
borrow money, buy a real stand, and let your neighbor buy on credit.

---

## Setup

All commands run from the **project root**.  Data file:
`accounting/src/data/07-week2-transactions.json`.

```bash
jq 'keys' accounting/src/data/07-week2-transactions.json
# ["starting_balance_sheet", "transactions"]
```

Two sections: `.starting_balance_sheet` (end of Week 1) and
`.transactions` (eight double-entry journal entries for Week 2).

---

## 1. Update Operators: Editing Cells in Place

Until now you read data and computed new values.  Now you *change*
data -- post transactions to the books.  Think of these as different
ways to edit an Excel cell instead of writing formulas in new ones.

| Operator | What it does | Excel analogy |
|----------|-------------|---------------|
| `.x = 5` | Set directly | Type `5` into A1 |
| `.x \|= . * 2` | Transform current value | `=A1*2` into A1 itself |
| `.x += 10` | Add to current | `=A1+10` into A1 |
| `.x -= 3` | Subtract | `=A1-3` into A1 |
| `.x //= 0` | Set only if blank | `=IF(ISBLANK(A1), 0, A1)` |
| `del(.x)` | Delete entirely | Right-click > Delete cell |

> Full reference: [10-assignment-update.md](../10-assignment-update.md).

```bash
echo '{"cash": 56}' | jq '.notes_payable = 50'
# {"cash": 56, "notes_payable": 50}        -- = creates field if missing

echo '{"cash": 56}' | jq '.cash |= . + 50'
# {"cash": 106}        -- |= transforms value at path (. means 56 here)

echo '{"cash": 56}' | jq '.cash += 50'
# {"cash": 106}        -- shorthand for |= . + 50

echo '{"cash": 56}' | jq '.equipment //= 0'
# {"cash": 56, "equipment": 0}     -- //= sets only if null/missing

echo '{"cash": 56, "equipment": 40}' | jq '.equipment //= 0'
# {"cash": 56, "equipment": 40}    -- no-op, already has a value

echo '{"cash": 56, "temp": "x"}' | jq 'del(.temp)'
# {"cash": 56}                     -- del removes the field entirely
```

`//= 0` is essential for our transaction engine: it creates a new
account at zero, then `+= 50` brings it to 50.

---

## 2. The `?` Operator: IFERROR for Every Cell Reference

`?` silently produces nothing when a field access or iteration fails --
like wrapping every cell reference in `IFERROR()`.

```bash
echo '5' | jq '[.[]?]'
# []          -- iterating a number would error; ? suppresses it

echo '[{"a":1}, "not an object", {"a":3}]' | jq '[.[]? | .a?]'
# [1, null, 3]

echo '"hello"' | jq 'try (. + 1)'
# (no output -- bare try swallows the error, like ? for whole expressions)
```

---

## 3. Nested Updates

Update operators work at any depth.  Chain them to post Transaction #1
(borrow $50) -- `.starting_balance_sheet` is like a tab name, `.assets`
the section, `.cash` the cell:

```bash
jq '
  .starting_balance_sheet.assets.cash += 50 |
  .starting_balance_sheet.liabilities.notes_payable = 50
' accounting/src/data/07-week2-transactions.json
```

---

## 4. Accounting Sidebar: What's New in Week 2

**Liabilities** -- money you owe.  Borrowing $50 creates a Notes
Payable account.  The equation still balances: A ($106) = L ($50) + OE ($56).

**Fixed vs. Current Assets** -- Equipment (the stand, $40) is a fixed
asset that lasts months.  Cash and inventory are current assets consumed
within weeks.  Prepaid insurance ($12 for 3 months) is current too --
each month $4 becomes an expense (Lesson 08).

**Accounts Receivable (A/R)** -- Your neighbor buys 5 cups on credit.
Revenue goes up (+$5), A/R goes up (+$5), but cash does not change.
This is why "profitable" does not always mean "cash in the bank."

**Retained Earnings** -- Net income flows here at period end.  Week 1's
$6 is already in RE.  Week 2's $13 will join it.

---

## 5. Transaction-by-Transaction

| # | Event | Cash | Other account |
|---|-------|------|---------------|
| 1 | Bank loan +$50 | $56 -> $106 | notes_payable +$50 |
| 2 | Buy stand -$40 | $106 -> $66 | equipment +$40 |
| 3 | Buy insurance -$12 | $66 -> $54 | prepaid_insurance +$12 |
| 4 | Buy supplies -$15 | $54 -> $39 | inventory +$15 |
| 5 | Cash sales (25 cups) +$25 | $39 -> $64 | revenue +$25 |
| 6 | Credit sale (5 cups) | no change | A/R +$5, revenue +$5 |
| 7 | Record COGS | no change | cogs +$15, inventory -$15 |
| 8 | Pay interest -$2 | $64 -> $62 | interest_expense +$2 |

Transaction 6 is the key new idea.  No cash moves -- only A/R and
revenue change.  In jq:

```bash
echo '{}' | jq '.accounts_receivable = 5 | .revenue = 5'
# {"accounts_receivable": 5, "revenue": 5}
```

---

## 6. The Full Program: Posting with `reduce`

`07-post-transactions.jq` uses nested `reduce` to apply every
transaction to a flat ledger:

```jq
reduce .transactions[] as $txn (
  { "ledger": $opening_ledger, "log": [] };

  reduce $txn.entries[] as $entry (
    .;
    .ledger[$entry.account] //= 0 |     # create account if new
    .ledger[$entry.account] += $entry.change   # adjust balance
  )
  | .log += [{ id: $txn.id, snapshot: .ledger }]
)
```

The `//= 0` + `+=` pair is the engine: ensure the cell exists, then
edit it.  The outer reduce walks transactions; the inner one walks
entries within each transaction.

Run it:

```bash
jq -f accounting/src/programs/07-post-transactions.jq \
  accounting/src/data/07-week2-transactions.json
```

You see the ledger after each transaction and a final balance sheet
verifying A = L + OE.

---

## 7. End of Week 2

| Account              | Balance |
|----------------------|---------|
| **Assets**           |         |
| Cash                 | $62.00  |
| Accounts Receivable  | $5.00   |
| Inventory            | $0.00   |
| Prepaid Insurance    | $12.00  |
| Equipment            | $40.00  |
| **Total Assets**     | **$119.00** |
| **Liabilities**      |         |
| Notes Payable        | $50.00  |
| **Total Liabilities**| **$50.00** |
| **Owner's Equity**   |         |
| Invested Capital     | $50.00  |
| Retained Earnings    | $19.00  |
| **Total L + OE**     | **$119.00** |

Week 2 income: Revenue $30 - COGS $15 - Interest $2 = **$13**.
Retained Earnings: $6 (wk1) + $13 (wk2) = $19.
Books balance: $119 = $50 + $69.

---

## Concept Summary

| jq Feature | What You Learned | Excel Parallel |
|-------------|-----------------|----------------|
| `.x = val` | Direct assignment | Type into cell |
| `.x \|= f` | Transform existing value | `=A1*2` in A1 |
| `.x += n` | Add to existing | `=A1+n` in A1 |
| `.x //= 0` | Set only if null/missing | `IF(ISBLANK(A1),0,A1)` |
| `del(.x)` | Remove a field | Delete cell |
| `.foo?` | Suppress errors on access | IFERROR wrapper |
| `try expr` | Suppress errors on expr | IFERROR on formula |
| Nested `.a.b.c += 1` | Deep update | Edit cell on another tab |

---

## Exercises

### Exercise 1: Manual Posting

Without `reduce`, apply Transactions #1-2 to the starting balance
sheet using chained update operators.  Output `{assets, liabilities}`.

<details>
<summary>Solution</summary>

```bash
jq '
  .starting_balance_sheet
  | .assets.cash += 50
  | .liabilities.notes_payable = 50
  | .assets.cash -= 40
  | .assets.equipment = 40
  | {assets, liabilities}
' accounting/src/data/07-week2-transactions.json
# {"assets":{"cash":66,"equipment":40},"liabilities":{"notes_payable":50}}
```

</details>

### Exercise 2: Defaults with `//=`

Starting from `{"cash": 62}`, use `//=` to ensure `accounts_receivable`,
`inventory`, and `equipment` exist (default 0).  Set `equipment` to 40.
Verify `cash` stays 62.

<details>
<summary>Solution</summary>

```bash
echo '{"cash": 62}' | jq '
  .cash //= 0 | .accounts_receivable //= 0 |
  .inventory //= 0 | .equipment //= 0 |
  .equipment = 40'
# {"cash":62,"accounts_receivable":0,"inventory":0,"equipment":40}
```

`//=` on `.cash` is a no-op -- it already has a value.

</details>

### Exercise 3: Double-Entry Proof with `?`

Sum every `change` across all transactions.  The answer must be 0
(double-entry guarantee).  Use `?` for safety.

<details>
<summary>Solution</summary>

```bash
jq '[.transactions[]?.entries[]?.change] | add' \
  accounting/src/data/07-week2-transactions.json
# 0
```

</details>

### Exercise 4: Close the Books with `del`

Given the final ledger state, `del()` the income accounts and fold
net income into retained earnings.

<details>
<summary>Solution</summary>

```bash
echo '{
  "cash":62,"accounts_receivable":5,"inventory":0,
  "prepaid_insurance":12,"equipment":40,"notes_payable":50,
  "invested_capital":50,"retained_earnings":6,
  "revenue":30,"cogs":15,"interest_expense":2
}' | jq '
  (.revenue - .cogs - .interest_expense) as $ni |
  del(.revenue, .cogs, .interest_expense) |
  .retained_earnings += $ni'
# retained_earnings becomes 19 (6 + 13)
```

</details>

### Exercise 5: Cash vs. Accrual Revenue

Calculate revenue two ways: (a) accrual = sum all `revenue` entries;
(b) cash-basis = sum cash inflows from transactions that have a revenue
entry.  Why are they different?

<details>
<summary>Solution</summary>

```bash
# Accrual: $30
jq '[.transactions[].entries[] | select(.account == "revenue") | .change] | add' \
  accounting/src/data/07-week2-transactions.json

# Cash-basis: $25 (only Transaction #5 has both cash and revenue)
jq '[.transactions[] | select(.entries[] | .account == "revenue") |
     .entries[] | select(.account == "cash") | .change] | add' \
  accounting/src/data/07-week2-transactions.json
```

The $5 gap is the credit sale -- earned but not yet collected.

</details>

---

## Deep Dive

Full reference on update operators:
[10-assignment-update.md](../10-assignment-update.md).

---

**Next up**: [Lesson 08 -- Adjustments and Accruals](08-adjustments-and-accruals.md),
where you depreciate equipment, recognize insurance expense, and learn
`foreach`.
