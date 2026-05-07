# The jq Accounting Game

Learn jq by running a lemonade stand.

Inspired by Darrell Mullis's *The Accounting Game*, this tutorial series
teaches jq through a continuous story: you start with $50 in savings and
build a lemonade business over a summer. Along the way you learn every
commonly-used jq feature — and the fundamentals of accounting.

**Who is this for?**

- **Accountants** who want to learn jq for data processing. Every
  programming concept is explained through Excel analogies.
- **Programmers** who want to understand double-entry bookkeeping,
  financial statements, and the accounting cycle.

## Prerequisites

- [jq 1.8+](https://jqlang.github.io/jq/download/) installed
- A terminal (macOS Terminal, Windows PowerShell, Linux shell)
- Familiarity with Excel (formulas, VLOOKUP, pivot tables)
- No programming experience required

## How to Use

Each lesson has three parts:

1. **Tutorial** (`.md` file) — read this first
2. **Data file** (`src/data/*.json`) — the lemonade stand's books
3. **jq program** (`src/programs/*.jq`) — run it, modify it, experiment

Run examples from the project root:

```bash
# Read the data
jq '.' accounting/src/data/01-opening-day.json

# Run a program against its data
jq -f accounting/src/programs/01-view-accounts.jq accounting/src/data/01-opening-day.json
```

## Lessons

| # | Lesson | Accounting | jq |
|---|--------|------------|-----|
| 01 | [Opening Day](01-opening-day.md) | Accounting equation, chart of accounts | `.` `.field` `\|` `-r` |
| 02 | [Buying Supplies](02-buying-supplies.md) | Assets change form | Types, arithmetic, comparisons |
| 03 | [First Sales](03-first-sales.md) | Revenue recognition | `.[]` `map` `select` `add` |
| 04 | [End of the Week](04-end-of-week.md) | Period reporting | `sort_by` `group_by` `to_entries` |
| 05 | [The Balance Sheet](05-the-balance-sheet.md) | A = L + OE | `reduce` `as $var` `keys` `//` |
| 06 | [The Income Statement](06-the-income-statement.md) | Revenue - COGS - Expenses | `if-then-else` `def` `try-catch` |
| 07 | [Growing the Business](07-growing-the-business.md) | Loans, A/R, credit | `\|=` `+=` `del` `?` |
| 08 | [Adjustments](08-adjustments-and-accruals.md) | Depreciation, accruals | `foreach` `empty` destructuring |
| 09 | [Cash Flow](09-cash-flow-statement.md) | Operating/Investing/Financing | `while` `until` `recurse` dates |
| 10 | [Trial Balance](10-trial-balance.md) | Debit = Credit validation | Regex, path operations |
| 11 | [Financial Statements](11-financial-statements.md) | Full accounting cycle | `INDEX` `@csv` `walk` modules |
| 12 | [Year in Review](12-year-in-review.md) | Ratios, trend analysis | `-s` `--stream` `transpose` |
| 13 | [Appendix](13-appendix-extra-features.md) | — | Niche features reference |

## The Story

You save $50 from chores and open a lemonade stand. Over three summer
months the stand grows: you take a bank loan, buy equipment, hire a
friend, deal with customers who don't pay, and learn why "profitable"
doesn't always mean "cash in the bank." By the end, you produce
real financial statements and analyze your summer's performance.

## Developer Tutorials

This is a parallel track. For a developer-focused jq tutorial (with
Python analogies instead of Excel), see the files in the
[project root](../00-overview.md): `00-overview.md` through
`12-real-world-recipes.md`.
