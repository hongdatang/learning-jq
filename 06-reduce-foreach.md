# Tutorial 06 — Reduce and Foreach

## `reduce` — jq's Fold

`reduce` accumulates a value by iterating over a generator's outputs.

Syntax:

```
reduce GENERATOR as $var (INIT; UPDATE)
```

- `GENERATOR` produces a stream of values
- `$var` binds each value in turn
- `INIT` is the starting accumulator
- `UPDATE` runs for each value; `.` is the accumulator, `$var` is the current element

> **The Python mapping**: `reduce EXPR as $x (init; update)` is exactly
> `functools.reduce(lambda acc, x: update, EXPR, init)` where `.` plays the role of `acc`.
> In Excel, `SUM(A1:A10)` is a reduce with `+` as the update and `0` as init.

### Sum

```bash
echo '[1, 2, 3, 4, 5]' | jq 'reduce .[] as $x (0; . + $x)'
# 15
# Python: functools.reduce(lambda acc, x: acc + x, [1,2,3,4,5], 0)
# Excel:  =SUM(A1:A5)
```

Step by step:
- Start: `.` = `0`
- `$x` = `1`: `.` = `0 + 1` = `1`
- `$x` = `2`: `.` = `1 + 2` = `3`
- `$x` = `3`: `.` = `3 + 3` = `6`
- `$x` = `4`: `.` = `6 + 4` = `10`
- `$x` = `5`: `.` = `10 + 5` = `15`

### Product

```bash
echo '[1, 2, 3, 4, 5]' | jq 'reduce .[] as $x (1; . * $x)'
# 120
# Python: functools.reduce(lambda acc, x: acc * x, [1,2,3,4,5], 1)
# Excel:  =PRODUCT(A1:A5)
```

### String Join (Manual)

```bash
echo '["hello", "world", "jq"]' | jq 'reduce .[] as $s (""; if . == "" then $s else . + " " + $s end)'
# "hello world jq"
# Python: " ".join(["hello", "world", "jq"])
# Excel:  =TEXTJOIN(" ", TRUE, A1:A3)
```

In practice, use `join(" ")` — but this demonstrates the pattern.

### Count Occurrences (Frequency Map)

```bash
echo '["a", "b", "a", "c", "b", "a"]' | jq '
  reduce .[] as $x ({}; .[$x] = ((.[$x] // 0) + 1))'
# {"a": 3, "b": 2, "c": 1}
# Python: collections.Counter(["a","b","a","c","b","a"])
# Excel:  =COUNTIF(A1:A6, "a") for each unique value
```

> **Familiar?** This is Python's `collections.Counter(xs)`, or Excel's `COUNTIF()`
> applied to each unique value.

### Building an Index/Lookup Map

```bash
echo '[{"id": "x", "val": 1}, {"id": "y", "val": 2}]' | jq '
  reduce .[] as $item ({}; .[$item.id] = $item)'
# {"x": {"id": "x", "val": 1}, "y": {"id": "y", "val": 2}}
# Python: {item["id"]: item for item in data}
# Excel:  =VLOOKUP("x", A1:B2, 2, FALSE) — lookup only, no direct index-building
```

Or use the builtin `INDEX`:

```bash
echo '[{"id": "x", "val": 1}, {"id": "y", "val": 2}]' | jq 'INDEX(.[]; .id)'
# same result
# Python: {item["id"]: item for item in data}
# Excel:  no direct equivalent (use VLOOKUP/XLOOKUP for individual lookups)
```

### Accumulator with Complex State

Use an array or object as the accumulator for multi-value state:

```bash
# Running average: track [sum, count]
echo '[10, 20, 30, 40]' | jq '
  reduce .[] as $x ([0, 0]; [.[0] + $x, .[1] + 1])
  | .[0] / .[1]'
# 25
# Python: sum(data) / len(data)  (or statistics.mean(data))
# Excel:  =AVERAGE(A1:A4)

# Partition into [evens, odds]
echo '[1, 2, 3, 4, 5, 6]' | jq '
  reduce .[] as $x ([[], []];
    if $x % 2 == 0 then .[0] += [$x]
    else .[1] += [$x] end)'
# [[2, 4, 6], [1, 3, 5]]
# Python: ([x for x in data if x%2==0], [x for x in data if x%2!=0])
# Excel:  =FILTER(A1:A6, MOD(A1:A6,2)=0) and =FILTER(A1:A6, MOD(A1:A6,2)<>0)
```

### Reduce with Destructuring

```bash
echo '[[1, "a"], [2, "b"], [3, "c"]]' | jq '
  reduce .[] as [$num, $str] ({};
    .[$str] = $num)'
# {"a": 1, "b": 2, "c": 3}
# Python: {s: n for n, s in data}
# Excel:  no direct equivalent
```

### Running Max

```bash
echo '[3, 1, 4, 1, 5, 9, 2, 6]' | jq '
  reduce .[] as $x (.[0]; if $x > . then $x else . end)'
# 9
# Python: max([3,1,4,1,5,9,2,6])
# Excel:  =MAX(A1:A8)
```

Or just use `max` — but the pattern is instructive.

### Grouping Manually

```bash
echo '[{"k": "a", "v": 1}, {"k": "b", "v": 2}, {"k": "a", "v": 3}]' | jq '
  reduce .[] as $item ({};
    .[$item.k] = ((.[$item.k] // []) + [$item.v]))'
# {"a": [1, 3], "b": [2]}
# Python: from collections import defaultdict; d=defaultdict(list); [d[x["k"]].append(x["v"]) for x in data]
# Excel:  no direct equivalent (use pivot tables for grouping)
```

## `foreach` — Reduce with Intermediate Outputs

`foreach` is like `reduce` but emits a value at each step. Think of it as
`itertools.accumulate` in Python, or an Excel column where each row shows the running
total so far.

Syntax:

```
foreach GENERATOR as $var (INIT; UPDATE; EXTRACT)
```

- Same as `reduce` plus an optional `EXTRACT` expression
- At each step, after UPDATE runs, EXTRACT runs and its output is emitted
- If EXTRACT is omitted, the accumulator value is emitted

### Running Sum (ScanLeft)

```bash
echo '[1, 2, 3, 4, 5]' | jq '[foreach .[] as $x (0; . + $x)]'
# [1, 3, 6, 10, 15]
# Python: list(itertools.accumulate([1,2,3,4,5]))
# Excel:  in B1 put =A1, in B2 put =B1+A2, drag down
```

Compare with `reduce`:
- `reduce .[] as $x (0; . + $x)` → `15` (final value only)
- `foreach .[] as $x (0; . + $x)` → `1, 3, 6, 10, 15` (all intermediate values)

> **Familiar?** This is Python's `itertools.accumulate`:
> ```python
> list(itertools.accumulate([1, 2, 3, 4, 5]))
> # [1, 3, 6, 10, 15]
> ```
> In Excel, this is a column where each cell is `=A1+B_previous` — a running total
> that accumulates row by row.

### With Extract Expression

The EXTRACT expression transforms each intermediate state before output:

```bash
echo '[1, 2, 3, 4, 5]' | jq '[foreach .[] as $x (0; . + $x; . > 6)]'
# [false, false, false, true, true]
# Python: [acc > 6 for acc in itertools.accumulate([1,2,3,4,5])]
# Excel:  =B1>6 (where B column has the running sum), drag down
```

Here the accumulator tracks the running sum, but EXTRACT outputs whether it exceeds 6.

### Running Index (Enumerate)

```bash
echo '["a", "b", "c"]' | jq '[foreach .[] as $x (-1; . + 1; {index: ., value: $x})]'
# [{"index": 0, "value": "a"}, {"index": 1, "value": "b"}, {"index": 2, "value": "c"}]
# Python: [{"index": i, "value": x} for i, x in enumerate(["a","b","c"])]
# Excel:  =ROW()-1 in one column, values in another
```

### Early Termination with `foreach` + `label-break`

Combine `foreach` with `label-break` to stop iteration early:

```bash
echo '[1, 2, 3, 4, 5, 6, 7, 8]' | jq '
  [label $out |
   foreach .[] as $x (0; . + $x;
     if . > 10 then ., break $out
     else . end)]'
# [1, 3, 6, 10, 15]
# Python: (approximate) result=[]; acc=0; [result.append(acc:=acc+x) or acc for x in data if acc <= 10]  — exact equivalent needs imperative loop
# Excel:  no direct equivalent
```

Or more practically, use `limit`:

```bash
echo '[1, 2, 3, 4, 5, 6, 7, 8]' | jq '
  [limit(4; foreach .[] as $x (0; . + $x))]'
# [1, 3, 6, 10]
# Python: list(itertools.accumulate(data))[:4]
# Excel:  running sum column, take first 4 rows
```

### Chunking / Windowing

Split an array into chunks of size N:

```bash
echo '[1,2,3,4,5,6,7,8,9]' | jq '
  [foreach .[] as $x ([]; if length == 3 then [$x] else . + [$x] end;
    if length == 3 then . else empty end)]'
# [[1,2,3],[4,5,6],[7,8,9]]
# Python: [data[i:i+3] for i in range(0, len(data), 3)]
# Excel:  no direct equivalent (manual ranges or OFFSET-based formulas)
```

The trick: EXTRACT emits only when the window is full (otherwise `empty`).

### Detecting Changes (Edge Detection)

Emit only when a value changes:

```bash
echo '[1,1,2,2,2,3,3,1]' | jq '
  [foreach .[] as $x (null;
    if . == $x then . else $x end;
    if . != $x then $x else empty end)]'
# wait — that's tricky. Simpler approach:
echo '[1,1,2,2,2,3,3,1]' | jq '
  [foreach .[] as $x ({prev: null, emit: false};
    {prev: $x, emit: (.prev != $x)};
    if .emit then $x else empty end)]'
# [1,2,3,1]
# Python: [k for k, _ in itertools.groupby([1,1,2,2,2,3,3,1])]
# Excel:  =IF(A2<>A1, A2, "") then filter blanks
```

## Practical Aggregation Patterns

### Group-By and Aggregate (SQL-style)

```bash
echo '[
  {"dept": "eng", "name": "Alice", "salary": 120000},
  {"dept": "eng", "name": "Bob", "salary": 110000},
  {"dept": "sales", "name": "Carol", "salary": 95000},
  {"dept": "sales", "name": "Dave", "salary": 105000},
  {"dept": "eng", "name": "Eve", "salary": 130000}
]' | jq '
  group_by(.dept) | map({
    department: .[0].dept,
    count: length,
    avg_salary: (map(.salary) | add / length),
    max_salary: (map(.salary) | max),
    members: map(.name)
  })'
# Python: df.groupby("dept").agg(count=("name","count"), avg_salary=("salary","mean"), max_salary=("salary","max"))
# Excel:  Pivot Table with dept as rows; COUNT, AVERAGE, MAX of salary as values
```

Output:

```json
[
  {"department":"eng","count":3,"avg_salary":120000,"max_salary":130000,"members":["Alice","Bob","Eve"]},
  {"department":"sales","count":2,"avg_salary":100000,"max_salary":105000,"members":["Carol","Dave"]}
]
```

### Histogram

```bash
echo '["apple","banana","apple","cherry","banana","apple"]' | jq '
  reduce .[] as $x ({};
    .[$x] = ((.[$x] // 0) + 1))
  | to_entries | sort_by(.value) | reverse
  | map("\(.key): \("█" * .value)")'
# ["apple: ███","banana: ██","cherry: █"]
# Python: collections.Counter(data).most_common()  (+ "█" * count for bar chars)
# Excel:  =REPT("█", COUNTIF(A:A, D1)) with unique values in D column
```

### Moving Average

```bash
echo '[1, 3, 5, 7, 9, 11, 13]' | jq '
  . as $data |
  [range(2; length) | . as $i | ($data[$i-2:$i+1] | add / length)]'
# [3, 5, 7, 9, 11]
# Python: [sum(data[i-2:i+1])/3 for i in range(2, len(data))]  (or pandas rolling(3).mean())
# Excel:  =AVERAGE(A1:A3) then drag down
```

### Cumulative Sum

```bash
echo '[100, -20, 50, -30, 10]' | jq '[foreach .[] as $x (0; . + $x)]'
# [100, 80, 130, 100, 110]
# Python: list(itertools.accumulate([100,-20,50,-30,10]))
# Excel:  =SUM($A$1:A1) in B1, drag down
```

## When to Use `reduce` vs `foreach` vs `map`

| Need | Use |
|------|-----|
| Transform each element independently | `map(f)` |
| Filter elements | `map(select(f))` |
| Single summary value (sum, count, max) | `reduce` or builtin (`add`, `length`, `max`) |
| Intermediate accumulations (running total) | `foreach` |
| Build a lookup table | `INDEX(.[]; .key)` or `reduce` |
| Complex multi-pass aggregation | `group_by` + `map` |

## Exercises

1. Use `reduce` to implement `join("-")` manually for `["a","b","c"]`.
2. Use `foreach` to compute a running product of `[2, 3, 4]` (expect `[2, 6, 24]`).
3. Given sales data, compute total revenue per region:
   ```json
   [{"region":"US","amount":100},{"region":"EU","amount":200},{"region":"US","amount":150},{"region":"EU","amount":50}]
   ```
4. Use `reduce` to reverse an array `[1, 2, 3, 4, 5]` (without using `reverse`).
5. Use `foreach` to mark each element as "new high" or "not" compared to all
   previous elements: `[3, 1, 4, 1, 5, 9, 2, 6]`

<details>
<summary>Solutions</summary>

```bash
# 1
echo '["a","b","c"]' | jq '
  reduce .[] as $x (""; if . == "" then $x else "\(.)-\($x)" end)'
# "a-b-c"
# Python: "-".join(["a","b","c"])
# Excel:  =TEXTJOIN("-", TRUE, A1:A3)

# 2
echo '[2, 3, 4]' | jq '[foreach .[] as $x (1; . * $x)]'
# [2, 6, 24]
# Python: list(itertools.accumulate([2,3,4], operator.mul))
# Excel:  =B1*A2 in B2 (with B1=A1), drag down

# 3
echo '[{"region":"US","amount":100},{"region":"EU","amount":200},{"region":"US","amount":150},{"region":"EU","amount":50}]' \
  | jq 'group_by(.region) | map({region: .[0].region, total: map(.amount) | add})'
# [{"region":"EU","total":250},{"region":"US","total":250}]
# or with reduce:
echo '[{"region":"US","amount":100},{"region":"EU","amount":200},{"region":"US","amount":150},{"region":"EU","amount":50}]' \
  | jq 'reduce .[] as $x ({}; .[$x.region] = ((.[$x.region] // 0) + $x.amount))'
# {"US":250,"EU":250}
# Python: df.groupby("region")["amount"].sum()
# Excel:  =SUMIF(A:A, "US", B:B) per region

# 4
echo '[1,2,3,4,5]' | jq 'reduce .[] as $x ([]; [$x] + .)'
# [5,4,3,2,1]
# Python: list(reversed([1,2,3,4,5]))
# Excel:  =SORTBY(A1:A5, SEQUENCE(5,1,5,-1))  (reverse row order; SORT descending is not the same as reversing)

# 5
echo '[3,1,4,1,5,9,2,6]' | jq '
  [foreach .[] as $x (-infinite;
    if $x > . then $x else . end;
    if $x >= . then {value: $x, new_high: true}
    else {value: $x, new_high: false} end)]'
# [{value:3,new_high:true},{value:1,new_high:false},{value:4,new_high:true},
#  {value:1,new_high:false},{value:5,new_high:true},{value:9,new_high:true},
#  {value:2,new_high:false},{value:6,new_high:false}]
# Python: [{"value": x, "new_high": x > max(data[:i]) if i else True} for i, x in enumerate(data)]
# Excel:  =IF(A2>MAX($A$1:A1), "new high", "not") in B2, drag down
```

</details>
