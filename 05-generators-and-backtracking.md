# Tutorial 05 — Generators and Backtracking

This is the most important conceptual tutorial. Understanding generators is the key to
thinking in jq.

## The Core Idea

Every jq expression is a **generator** that takes one input and produces **zero, one,
or many** outputs. When you compose generators with `|`, each output of the left side
becomes an input to the right side.

> **The Python mental model**: Think of every jq expression as a generator (like a
> `yield`-based function). The pipe `|` is a nested generator expression. This single
> analogy explains nearly all of jq's behavior. In Excel terms, imagine every formula
> can spill into multiple cells, and the next formula runs once per spilled cell.

## Single-Output Expressions

Most expressions produce exactly one output:

```bash
echo '5' | jq '. + 1'
# 6  — one input, one output
# Python: 5 + 1
# Excel:  =A1+1
```

## Multi-Output Expressions (Generators)

Some expressions produce multiple outputs:

```bash
echo '[10, 20, 30]' | jq '.[]'
# 10
# 20
# 30
# — one input, three outputs
# Python: (x for x in [10, 20, 30])  — a generator yielding each element
# Excel:  no direct equivalent (closest: spilling an array with =A1:A3)
```

The **comma operator** is the simplest generator:

```bash
echo 'null' | jq '1, 2, 3'
# 1
# 2
# 3
# Python: yield 1; yield 2; yield 3  (or simply iter([1, 2, 3]))
# Excel:  ={1;2;3}  — array constant that spills into 3 cells
```

`range` is a generator:

```bash
jq -n 'range(4)'
# 0
# 1
# 2
# 3
# Python: range(4)
# Excel:  =SEQUENCE(4,1,0,1)
```

## Zero-Output Expressions: `empty`

`empty` is the zero-output generator. It produces nothing and triggers **backtracking**:

```bash
jq -n 'empty'
# (no output)

jq -n '1, empty, 3'
# 1
# 3
# — empty produces nothing; execution continues with 3
# Python: (x for x in [1, 3])  — empty is like a generator that yields nothing
# Excel:  no direct equivalent (closest: a blank cell that gets skipped)
```

`select` is defined in terms of `empty`:

```bash
# select(f) = if f then . else empty end
echo '5' | jq 'select(. > 3)'
# 5

echo '2' | jq 'select(. > 3)'
# (no output — select produced empty)
# Python: (x for x in xs if x > 3)  — select is like filtering in a generator/comprehension
# Excel:  =IF(A1>3, A1, "")  or =FILTER(A1, A1>3)
```

## How Pipes Compose Generators

When the left side of `|` produces multiple outputs, the right side runs independently
for **each** output:

```bash
echo '[1, 2, 3]' | jq '.[] | . * 10'
# 10
# 20
# 30
# Python: [x * 10 for x in [1, 2, 3]]
# Excel:  =A1:A3*10  (array formula that spills)
```

This is exactly a nested comprehension:

```python
# Python equivalent:
[x * 10 for x in [1, 2, 3]]
# [10, 20, 30]
```

### Cartesian Products

When both sides are generators, you get a cartesian product:

```bash
jq -n '(1, 2) | (. * 10, . * 100)'
# 10
# 100
# 20
# 200
# Python: [y for x in [1, 2] for y in [x*10, x*100]]
# Excel:  no direct equivalent (no cartesian product formula)
```

The pipeline processes: `1` → `10, 100`, then `2` → `20, 200`.

```python
# Python equivalent:
[y for x in [1, 2] for y in [x * 10, x * 100]]
# [10, 100, 20, 200]
```

## Backtracking

When a downstream filter produces `empty`, jq backtracks to the nearest upstream
generator and asks for the next value:

```bash
echo '[1, 2, 3, 4, 5]' | jq '.[] | select(. % 2 == 0)'
# 2
# 4
# Python: [x for x in [1,2,3,4,5] if x % 2 == 0]
# Excel:  =FILTER(A1:A5, MOD(A1:A5,2)=0)
```

Step by step:
1. `.[]` yields `1` → `select(1 % 2 == 0)` → `select(false)` → `empty` → backtrack
2. `.[]` yields `2` → `select(2 % 2 == 0)` → `select(true)` → `2` → output
3. `.[]` yields `3` → `select(false)` → `empty` → backtrack
4. `.[]` yields `4` → `select(true)` → `4` → output
5. `.[]` yields `5` → `select(false)` → `empty` → backtrack
6. `.[]` exhausted → done

> **Familiar?** This is like Python's generator protocol:
> ```python
> (x for x in [1,2,3,4,5] if x % 2 == 0)  # yields 2, 4
> ```
> When the `if` fails, the generator simply moves to the next element.
> In Excel, this is like `FILTER(A1:A5, MOD(A1:A5,2)=0)` — rows that don't match
> simply don't appear in the output.

## Collecting Generator Outputs

Wrap a generator in `[...]` to collect all its outputs into an array:

```bash
jq -n '[1, 2, 3]'
# [1, 2, 3]  — [expr] collects the three outputs of "1, 2, 3"

echo '[1, 2, 3, 4, 5]' | jq '[.[] | select(. > 3)]'
# [4, 5]

echo '[1, 2, 3]' | jq '[.[] | ., . * 10]'
# [1, 10, 2, 20, 3, 30]
# Python: list(gen)  — wrapping a generator in list() collects all values
# Excel:  no direct equivalent (arrays are already "collected" in Excel)
```

## Generator Idioms

### Map-Filter-Collect

This is the most common jq pattern:

```bash
echo '[1, 2, 3, 4, 5]' | jq '[.[] | select(. > 2) | . * 10]'
# [30, 40, 50]
# Python: [x*10 for x in [1,2,3,4,5] if x > 2]
# Excel:  =FILTER(A1:A5*10, A1:A5>2)  (Excel 365 dynamic array)
```

Which is: iterate → filter → transform → collect. Equivalent to:

```scala
List(1,2,3,4,5).filter(_ > 2).map(_ * 10)
```

### FlatMap via Generators

When a filter produces multiple outputs per input, pipes automatically flatten:

```bash
echo '[[1, 2], [3, 4], [5]]' | jq '[.[] | .[]]'
# [1, 2, 3, 4, 5]
# Python: [item for sublist in [[1,2],[3,4],[5]] for item in sublist]  (or itertools.chain.from_iterable)
# Excel:  =TOCOL(A1:C2)  (Excel 365 — flattens a range into a single column)
```

This is `flatMap` — each `.[0]` yields `[1, 2]`, whose `.[]` yields `1, 2`, etc.

### Multiple Fields as Generator

```bash
echo '{"first": "John", "last": "Doe", "age": 30}' | jq '.first, .last'
# "John"
# "Doe"

echo '[{"a":1,"b":2},{"a":3,"b":4}]' | jq '[.[] | .a, .b]'
# [1, 2, 3, 4]
# Python: [v for d in lst for v in (d["a"], d["b"])]
# Excel:  =TOCOL(CHOOSECOLS(table, 1, 2))  (flatten selected columns)
```

### Generating from `if`

Conditionals can be generators too:

```bash
echo '[1, 2, 3, 4, 5]' | jq '[.[] | if . % 2 == 0 then "even:\(.)" else "odd:\(.)" end]'
# ["odd:1","even:2","odd:3","even:4","odd:5"]
# Python: [f"even:{x}" if x%2==0 else f"odd:{x}" for x in [1,2,3,4,5]]
# Excel:  =IF(MOD(A1:A5,2)=0, "even:"&A1:A5, "odd:"&A1:A5)  (array formula)
```

## Variable Binding: `as`

`as` captures a value into a variable without consuming it from the pipeline:

```bash
echo '{"multiplier": 10, "data": [1, 2, 3]}' | jq '.multiplier as $m | .data | map(. * $m)'
# [10, 20, 30]
# Python: m = d["multiplier"]; [x * m for x in d["data"]]
# Excel:  =A1:A3 * B1  (where B1 holds the multiplier)
```

> **Familiar?** `expr as $x | body` is like:
> - Python: `x = expr; body` (or walrus `:=`)
> - Excel: naming a cell (`Define Name`) so you can reference it elsewhere
>
> But with a crucial difference: the pipeline input (`.`) continues to flow through.
> `as` binds a side value, it doesn't redirect the pipeline.

### Destructuring with `as`

Array destructuring:

```bash
echo '[[1, 2], [3, 4], [5, 6]]' | jq '.[] | . as [$a, $b] | "\($a) + \($b) = \($a + $b)"'
# "1 + 2 = 3"
# "3 + 4 = 7"
# "5 + 6 = 11"
# Python: [f"{a} + {b} = {a+b}" for a, b in [[1,2],[3,4],[5,6]]]
# Excel:  =A1&" + "&B1&" = "&(A1+B1)  (with rows of paired data)
```

Object destructuring:

```bash
echo '{"name": "Alice", "age": 30}' | jq '. as {name: $n, age: $a} | "\($n) is \($a)"'
# "Alice is 30"
# Python: n, a = d["name"], d["age"]; f"{n} is {a}"
# Excel:  =B1&" is "&C1  (where B1=name, C1=age)
```

### `as` with Generators — The Pattern-Matching Crossjoin

When the right side of `as` is a generator, you get multiple bindings:

```bash
echo 'null' | jq '(1, 2, 3) as $x | $x * 10'
# 10
# 20
# 30
# Python: [x * 10 for x in [1, 2, 3]]
# Excel:  ={1;2;3}*10  (array formula)
```

This enables a "loop variable" pattern:

```bash
echo '{"a": 1, "b": 2}' | jq 'to_entries[] | .key as $k | .value as $v | "\($k)=\($v)"'
# "a=1"
# "b=2"
# Python: [f"{k}={v}" for k, v in {"a":1,"b":2}.items()]
# Excel:  no direct equivalent (no key-value iteration in formulas)
```

## `limit`, `first`, `last` — Controlling Generators

### `first(expr)` — Take Only the First Output

```bash
jq -n 'first(range(1000000))'
# 0  — does NOT generate all million values

jq -n 'first(empty)'
# (no output)
# Python: next(iter(range(1000000)))  → 0
# Excel:  =INDEX(array, 1)
```

### `last(expr)` — Take the Last Output

```bash
jq -n 'last(range(5))'
# 4  — must consume the entire generator to find the last value
# Python: collections.deque(range(5), maxlen=1)[0]  (or just list(range(5))[-1])
# Excel:  =INDEX(array, ROWS(array))
```

### `limit(n; expr)` — Take First N Outputs

```bash
jq -n '[limit(3; range(1000))]'
# [0, 1, 2]

jq -n '[limit(5; repeat(1))]'
# [1, 1, 1, 1, 1]  — limit stops the infinite generator
# Python: list(itertools.islice(range(1000), 3))  → [0, 1, 2]
# Excel:  =SEQUENCE(3,1,0,1)  or =TAKE(array, 3)
```

### `nth(n; expr)` — Take the Nth Output

```bash
jq -n 'nth(3; range(100))'
# 3
# Python: list(range(100))[3]  (or next(itertools.islice(range(100), 3, 4)))
# Excel:  =INDEX(array, 4)  (1-based indexing)
```

### `skip(n; expr)` — Skip First N Outputs (New in jq 1.8)

```bash
jq -n '[skip(3; range(8))]'
# [3, 4, 5, 6, 7]
# Python: list(itertools.islice(range(8), 3, None))
# Excel:  =DROP(SEQUENCE(8,1,0,1), 3)
```

> **Familiar?** These map to Python's `itertools` and Excel:
> - `first(expr)` → `next(iter(expr))` / Excel `INDEX(...,1)`
> - `last(expr)` → `deque(expr, maxlen=1)[0]` / Excel `INDEX(...,ROWS(...))`
> - `limit(n; expr)` → `itertools.islice(expr, n)` / Excel top-N rows
> - `skip(n; expr)` → `itertools.islice(expr, n, None)` / Excel skip first N rows
> - `nth(n; expr)` → `list(expr)[n]` / Excel `INDEX(...,n)`

## Advanced: How Generators Enable Algorithms

### Generate-and-Test

Generate candidates, test them, take the first that passes:

```bash
jq -n 'first(range(1000) | select(. * . > 50))'
# 8  — first integer whose square exceeds 50
# Python: next(x for x in range(1000) if x*x > 50)
# Excel:  =MATCH(TRUE, (ROW(A1:A1000)-1)^2>50, 0)-1  (array formula, 0-based)
```

### Enumerate (Index + Value)

```bash
echo '["a", "b", "c"]' | jq '[foreach .[] as $x (-1; . + 1; {index: ., value: $x})]'
# [{"index":0,"value":"a"},{"index":1,"value":"b"},{"index":2,"value":"c"}]

echo '["a", "b", "c"]' | jq 'to_entries | map({index: .key, value})'
# same result — often easier when starting from an array
# Python: list(enumerate(["a","b","c"]))  → [(0,"a"),(1,"b"),(2,"c")]
# Excel:  =HSTACK(SEQUENCE(ROWS(A1:A3),1,0,1), A1:A3)  (index column + data)
```

### Unfolding / Anamorphism

Generate a sequence from a seed (Excel has no direct equivalent):

```bash
jq -n '[1 | recurse(. * 2; . < 1000)]'
# [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]

jq -n '[0, 1 | recurse(.[1], .[0] + .[1]; .[1] < 100) | .[0]]'
# won't work directly — use until/reduce for Fibonacci (see Tutorial 06)
# Python: list(itertools.takewhile(lambda x: x<1000, (2**n for n in range(20))))
# Excel:  no direct equivalent (no unfolding/anamorphism in formulas)
```

## Exercises

1. Using generators, produce all pairs `[x, y]` where `x` is in `[1,2,3]` and
   `y` is in `["a","b"]`. (Hint: nested `.[] as $x`)
2. From `[1,2,3,4,5,6,7,8,9,10]`, find the first number whose cube exceeds 500.
3. Given `[{"x":1},{"x":2},{"x":3}]`, use `[.[] | .x]` vs `map(.x)` — verify
   they produce the same result.
4. Use `limit(5; ...)` to get the first 5 powers of 2 starting from 1.
5. Demonstrate backtracking: iterate `[1,2,3,4,5]`, select odd numbers, then
   multiply each by 100.

<details>
<summary>Solutions</summary>

```bash
# 1
jq -n '[[1,2,3][] as $x | ["a","b"][] as $y | [$x, $y]]'
# [[1,"a"],[1,"b"],[2,"a"],[2,"b"],[3,"a"],[3,"b"]]
# Python: [[x, y] for x in [1,2,3] for y in ["a","b"]]
# Excel:  no direct equivalent (no cartesian product formula)

# 2
echo '[1,2,3,4,5,6,7,8,9,10]' | jq 'first(.[] | select(. * . * . > 500))'
# 8
# Python: next(x for x in range(1,11) if x**3 > 500)
# Excel:  =MATCH(TRUE, (ROW(A1:A10))^3>500, 0)

# 3
echo '[{"x":1},{"x":2},{"x":3}]' | jq '[.[] | .x]'
# [1,2,3]
echo '[{"x":1},{"x":2},{"x":3}]' | jq 'map(.x)'
# [1,2,3]
# Python: [d["x"] for d in lst]
# Excel:  =CHOOSECOLS(table, col_with_x)

# 4
jq -n '[limit(5; 1 | recurse(. * 2))]'
# [1,2,4,8,16]
# Python: [2**n for n in range(5)]
# Excel:  =POWER(2, SEQUENCE(5,1,0,1))

# 5
echo '[1,2,3,4,5]' | jq '[.[] | select(. % 2 == 1) | . * 100]'
# [100,300,500]
# Python: [x*100 for x in [1,2,3,4,5] if x%2==1]
# Excel:  =FILTER(A1:A5*100, MOD(A1:A5,2)=1)
```

</details>
