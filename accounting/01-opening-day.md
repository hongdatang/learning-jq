# Lesson 01 -- Opening Day: Setting Up the Books

## The Story

You have been saving up from chores all spring -- mowing lawns, walking dogs,
washing cars. By June 1st you have $50 in cash. You decide to start a lemonade
stand.

Your mom agrees to help you keep track of the money properly. "If you are going
to run a business," she says, "you need to keep books." She hands you a notebook
and explains the basics: write down what you own, what you owe, and where the
money came from.

That notebook is your accounting system. In this lesson, you will build it in
JSON and explore it with jq.

---

## What is JSON?

You already know spreadsheets. JSON is similar, but shaped differently.

> **Excel analogy**: A spreadsheet has rows and columns. Column A might be
> "Business," column B might be "Owner," and each row is a record. JSON does
> the same thing, but instead of column letters (A, B, C), every value has a
> **name**. Think of a JSON object as a single spreadsheet row where the column
> headers are written right next to each value.

Here is the data for your lemonade stand on opening day:

```json
{
  "business": "Lemonade Stand",
  "owner": "You",
  "date": "2024-06-01"
}
```

In a spreadsheet, this would be:

| business       | owner | date       |
|----------------|-------|------------|
| Lemonade Stand | You   | 2024-06-01 |

The curly braces `{ }` mean "this is one record." Each `"key": value` pair is a
named column. That is all JSON is -- named data.

---

## Your First jq Command: The Identity Filter `.`

The simplest jq command just shows you what you have. The dot `.` means
"everything" -- pass the input straight through.

> **Excel analogy**: `.` is like clicking on a cell and looking at it in the
> formula bar. You are not changing anything -- just looking. It is `=A1` when
> A1 contains the whole sheet.

```bash
jq '.' accounting/src/data/01-opening-day.json
```

Output (abbreviated -- jq pretty-prints by default):

```json
{
  "business": "Lemonade Stand",
  "owner": "You",
  "date": "2024-06-01",
  "chart_of_accounts": { ... },
  "transactions": [ ... ],
  "balance_sheet": {
    "assets": { "cash": 50 },
    "liabilities": {},
    "owners_equity": { "invested_capital": 50 }
  }
}
```

jq indents and color-codes JSON automatically -- no setup needed. Run it
yourself to see the full output.

---

## Reading One Field: `.field`

To look at a single piece of data, put a dot and then the field name.

> **Excel analogy**: `.business` is like typing `=A1` to get the value in the
> "business" column. In a VLOOKUP, it would be
> `VLOOKUP("business", data, 2, FALSE)` -- look up one named column from your
> record.

```bash
jq '.business' accounting/src/data/01-opening-day.json
# "Lemonade Stand"

jq '.owner' accounting/src/data/01-opening-day.json
# "You"

jq '.date' accounting/src/data/01-opening-day.json
# "2024-06-01"
```

Notice the quotes around the output. jq shows strings with quotes so you know
they are text, not numbers. To remove the quotes, use the `-r` flag.

---

## Raw Output: the `-r` Flag

> **Excel analogy**: In Excel, a cell just shows the value -- no quotes around
> text. The `-r` flag makes jq behave the same way: plain text, no JSON quotes.

```bash
jq -r '.business' accounting/src/data/01-opening-day.json
# Lemonade Stand
```

Without `-r` you get `"Lemonade Stand"` (with quotes). With `-r` you get
`Lemonade Stand` (plain text). Use `-r` whenever you want clean output.

---

## Navigating Deeper: `.field1.field2`

Your data has layers. The balance sheet is inside the main record, and the cash
amount is inside the balance sheet. Chain field names with dots to drill down.

> **Excel analogy**: Imagine your spreadsheet has a sheet called "Balance Sheet,"
> and within that sheet there is a section called "Assets," and within that a
> cell called "Cash." Chained access `.balance_sheet.assets.cash` is like
> clicking through: Sheet tab > Section > Cell. It is a nested INDEX lookup.

```bash
jq '.balance_sheet.assets.cash' accounting/src/data/01-opening-day.json
```

```
50
```

You can also look at the chart of accounts:

```bash
jq '.chart_of_accounts.assets' accounting/src/data/01-opening-day.json
# ["Cash"]
```

The square brackets `[ ]` mean a list (called an "array"). Right now your asset
list has just one item. More accounts will appear in later lessons.

---

## Connecting Steps: The Pipe `|`

Sometimes you want to grab a section first, then look inside it. The pipe `|`
connects two steps: the output of the left side becomes the input to the right
side.

> **Excel analogy**: The pipe is like chaining formulas. If cell B1 contains
> `=A1` and cell C1 contains `=LEN(B1)`, the value flows: A1 -> B1 -> C1.
> With jq, `.balance_sheet | .assets | .cash` flows the same way: grab the
> balance sheet, then grab assets from it, then grab cash from that.

```bash
jq '.balance_sheet | .assets | .cash' accounting/src/data/01-opening-day.json
# 50
```

This gives the same result as `.balance_sheet.assets.cash`. The chained dot
notation is shorthand for piping. Both are useful -- pipes become essential
when you want to do more between steps (as you will see in later lessons).

---

## Null Input: the `-n` Flag

Sometimes you want jq to compute something without reading a file. The `-n` flag
starts with nothing (null) instead of reading input.

> **Excel analogy**: `-n` is like opening a blank spreadsheet and typing a
> formula that does not reference any cells. `=2+3` works even with no data.

```bash
jq -n '"Hello, Lemonade Stand!"'
# "Hello, Lemonade Stand!"

jq -n '50 + 0'
# 50
```

You will use `-n` more in later lessons when building new data from scratch.

---

## Accounting Sidebar: What Just Happened?

Let's step back and understand the financial side of what you set up.

### The Accounting Equation

Every business follows one rule that must always be true:

```
Assets = Liabilities + Owner's Equity
```

- **Assets** -- what the business owns (cash, inventory, equipment).
- **Liabilities** -- what the business owes to others (loans, unpaid bills).
- **Owner's Equity** -- what the owner has invested, plus profits kept in the business.

On opening day:

```
$50 (Cash) = $0 (Liabilities) + $50 (Owner's Equity)
```

The equation balances. It must always balance.

### The Chart of Accounts

A chart of accounts is just a list of category names. Think of it as your
spreadsheet column headers -- before you record anything, you decide what
columns you need. Right now you only need three: Cash, (no liabilities yet),
and Owner's Equity.

### Your First Journal Entry

Every financial event is recorded as a journal entry. Your first one:

| Date       | Description                              | Debit (increase) | Credit (increase) |
|------------|------------------------------------------|-------------------|-------------------|
| 2024-06-01 | Owner investment - saved from chores     | Cash $50          | Owner's Equity $50 |

**Debit** means "left side" and **Credit** means "right side." For now, just
know that debits and credits must always be equal. You put $50 in (Cash goes up)
and that $50 came from the owner (Owner's Equity goes up).

---

## Try It Yourself

Run the lesson's jq program to see all of these concepts together:

```bash
jq -f accounting/src/programs/01-view-accounts.jq accounting/src/data/01-opening-day.json
```

The program reads the business info, navigates to the cash balance, and verifies
the accounting equation -- all using `.field`, chained access, and pipes. Open
`accounting/src/programs/01-view-accounts.jq` to read the code. Every technique
in that program was covered in this lesson.

---

## Deep Dive

For more on the identity filter, field access, pipes, and CLI flags, see
[01-basics.md](../01-basics.md) in the developer tutorials. That tutorial covers
the same jq features with more technical depth and additional examples.

---

## Exercises

Try these in your terminal. All use `accounting/src/data/01-opening-day.json`.

1. **Get the transaction description.** The first transaction is at
   `.transactions[0]`. Use chained access to print just its `description` field.

2. **Raw date.** Print the business date without quotes.

3. **List the equity accounts.** Print the equity array from the chart of
   accounts.

4. **Cash via pipe.** Use two pipes to get the cash amount: first grab
   `.balance_sheet`, then `.assets`, then `.cash`.

5. **No-input greeting.** Using `-n` (no input file), produce the output:
   `Welcome to the Lemonade Stand`

<details>
<summary>Solutions</summary>

```bash
# 1. Get the transaction description
jq '.transactions[0].description' accounting/src/data/01-opening-day.json
# "Owner investment - saved from chores"

# 2. Raw date (no quotes)
jq -r '.date' accounting/src/data/01-opening-day.json
# 2024-06-01

# 3. List the equity accounts
jq '.chart_of_accounts.equity' accounting/src/data/01-opening-day.json
# [
#   "Owner's Equity"
# ]

# 4. Cash via pipe
jq '.balance_sheet | .assets | .cash' accounting/src/data/01-opening-day.json
# 50

# 5. No-input greeting
jq -n '"Welcome to the Lemonade Stand"'
# "Welcome to the Lemonade Stand"
# Or, for clean output:
jq -rn '"Welcome to the Lemonade Stand"'
# Welcome to the Lemonade Stand
```

</details>
