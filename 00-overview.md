# Learning jq 1.8.1 — Tutorial Series

A progressive tutorial series for developers with Python and Excel experience.

## What is jq?

jq is a lightweight, functional programming language designed for JSON transformation.
Think of it as `sed` or `awk` but for JSON — you pipe JSON in, apply filters, and get
transformed JSON out.

jq is also a Turing-complete language with closures, recursion, a module system, and a
rich standard library. Under the surface, it's closer to a functional language like Haskell
than to a simple query tool.

## Why Learn jq?

- **Shell glue**: Extract fields from API responses, config files, or logs in one line
- **Pipeline-native**: Composes naturally with `curl`, `kubectl`, `aws`, `gh`, `docker`
- **Fast**: Starts instantly (unlike Python), handles moderate data sizes efficiently
- **Functional**: If you enjoy Python's `map`/`filter`/`reduce`, jq will feel familiar

## Prerequisites

- jq 1.8.1 installed (`jq --version` should show `jq-1.8.1`)
- Familiarity with JSON format
- A terminal

## Tutorial Structure

| # | File | Topic |
|---|------|-------|
| 01 | [01-basics.md](01-basics.md) | Identity, field access, indexing, pipes, CLI flags |
| 02 | [02-types-and-operators.md](02-types-and-operators.md) | Types, arithmetic, comparison, logic, string operations |
| 03 | [03-array-object-operations.md](03-array-object-operations.md) | Constructing, transforming, and querying arrays and objects |
| 04 | [04-control-flow.md](04-control-flow.md) | Conditionals, try/catch, error handling, the alternative operator |
| 05 | [05-generators-and-backtracking.md](05-generators-and-backtracking.md) | The core mental model — generators, `empty`, multiple outputs |
| 06 | [06-reduce-foreach.md](06-reduce-foreach.md) | Folding and scanning — `reduce`, `foreach`, aggregation patterns |
| 07 | [07-functions.md](07-functions.md) | Defining functions, recursion, closures, arguments as filters |
| 08 | [08-regex.md](08-regex.md) | Regular expressions — `test`, `match`, `capture`, `scan`, `sub`, `gsub` |
| 09 | [09-path-operations.md](09-path-operations.md) | Path expressions, `getpath`, `setpath`, recursive descent |
| 10 | [10-assignment-update.md](10-assignment-update.md) | Assignment operators — `=`, `\|=`, `+=`, `//=` and update patterns |
| 11 | [11-advanced-patterns.md](11-advanced-patterns.md) | Streaming, SQL-style operators, format strings, modules |
| 12 | [12-real-world-recipes.md](12-real-world-recipes.md) | Practical recipes — API responses, CSV, aggregation, config merging |

## Conventions Used

- All examples use `echo '...' | jq '...'` so you can copy-paste directly
- Comments after `#` explain what each part does
- Analogies to Python and Excel appear in **Familiar?** callout boxes
- Each tutorial builds on previous ones but can be read independently

## Quick Reference: jq vs Your Languages

| Concept | Python | Excel | jq |
| --- | --- | --- | --- |
| Map | `[f(x) for x in xs]` | drag formula down column | `map(f)` |
| Filter | `[x for x in xs if p(x)]` | `FILTER()` | `map(select(p))` |
| Reduce | `functools.reduce(f, xs, init)` | `SUM()`, `PRODUCT()` | `reduce .[] as $x (init; f)` |
| FlatMap | `[y for x in xs for y in f(x)]` | — | `.[]\|f` or `map(f)\|flatten` |
| GroupBy | `itertools.groupby(...)` | pivot table | `group_by(f)` |
| Null-safe | `x if x else default` | `IFERROR(x, default)` | `.field // default` |
| Pipeline | `pipe(op1, op2)` | nested functions | `op1\|op2` |
