# Tutorial 01 — Basics

## The Evaluation Model

How jq actually executes your code. Read this before anything else confuses you.

### The Two Things Every Filter Has

Every jq expression — called a **filter** — has:

1. An **input**: one JSON value, accessed via `.`
2. An **output**: one or more JSON values

That's it. A filter takes in one value, produces values. Everything in jq is a filter.

```text
        input (.)
           │
           ▼
      ┌─────────┐
      │  filter  │
      └─────────┘
           │
           ▼
       output(s)
```

The simplest filter is `.` — it passes input straight through:

```bash
echo '42' | jq '.'
# input: 42, output: 42
# Python: x = 42; x  → 42 (identity)
# Excel:  =A1 (just references the cell)
```

`.name` is also a filter — it takes an object as input and outputs the value of the
`name` field:

```bash
echo '{"name":"alice"}' | jq '.name'
# input: {"name":"alice"}, output: "alice"
# Python: d["name"]  → "alice"
# Excel:  VLOOKUP("name", A:B, 2, FALSE) or INDEX/MATCH
```

`42` (a literal) is also a filter — it ignores its input and outputs `42`:

```bash
echo '"whatever"' | jq '42'
# input: "whatever", output: 42
# Python: lambda _: 42  (ignores input, returns constant)
# Excel:  =42 (a literal value, ignores any input cell)
```

### Rule 1: Pipe Redefines `.`

`A | B` means:

1. Run filter `A` with the current `.`
2. Take `A`'s output
3. Feed it as the new `.` into filter `B`

```bash
echo '{"user":{"name":"alice"}}' | jq '.user | .name'
# Python: d["user"]["name"]
# Excel:  INDEX(INDIRECT("user_table"), MATCH("name", ...)) — nested lookups
```

Trace:

```text
. = {"user":{"name":"alice"}}      ← initial input from stdin

Step 1: .user
  input:  {"user":{"name":"alice"}}
  output: {"name":"alice"}

  ── pipe: output becomes new . ──

Step 2: .name
  input:  {"name":"alice"}
  output: "alice"

Final output: "alice"
```

**The key rule**: after every `|`, the `.` on the right side is **replaced** by whatever
the left side produced. The previous `.` is gone.

#### Three Pipes

```bash
echo '{"a":{"b":{"c":42}}}' | jq '.a | .b | .c'
# Python: d["a"]["b"]["c"]
# Excel:  no direct equivalent (no native nested structure navigation)
```

```text
. = {"a":{"b":{"c":42}}}

.a          →  . becomes {"b":{"c":42}}
   | .b     →  . becomes {"c":42}
      | .c  →  . becomes 42

Output: 42
```

This is why `.a.b.c` and `.a | .b | .c` are equivalent — both navigate the same way,
just with different syntax.

### Rule 2: Variables Survive Across Pipes, `.` Does Not

`expr as $var` binds a value to `$var`. The variable persists for the rest of the
expression. But `.` gets replaced at every pipe.

```bash
echo '10' | jq '. as $original | . * 2 | . + $original'
# Python: orig = x; x = x * 2; x + orig  (temp var needed to model the pipeline stages)
# Excel:  =A1*2 + A1  (A1 acts like the bound variable, always accessible)
```

Trace:

```text
. = 10                               ← initial input

Step 1: . as $original
  reads .: 10
  binds: $original = 10
  output: 10                         ← . passes through unchanged

  ── pipe: . = 10 ──

Step 2: . * 2
  reads .: 10
  output: 20

  ── pipe: . = 20 ──

Step 3: . + $original
  reads .: 20
  reads $original: 10                ← still available!
  output: 30

Final output: 30
```

|              | after pipe 1 | after pipe 2 |
| ------------ | ------------ | ------------ |
| `.`          | `10`         | `20`         |
| `$original`  | `10`         | `10`         |

**`.` changes at every pipe. `$var` stays until the expression ends.**

> **Familiar?** In Python, `|` is like chaining operations in a pipeline — each one
> gives you a new value. `as $var` is like a `walrus` assignment (`:=`) — it stays in
> scope for the rest of the expression.

### Rule 3: Multiple Outputs

Some filters produce more than one output. When that happens, everything downstream
runs **once per output**.

`.[]` is the most common multi-output filter — it produces each element of an array:

```bash
echo '[1,2,3]' | jq '.[]'
# 1
# 2
# 3
# Python: for x in [1,2,3]: print(x)  — or just iter([1,2,3])
# Excel:  each row of a range (A1:A3 treated individually)
```

The comma `,` also produces multiple outputs:

```bash
echo 'null' | jq '1, 2, 3'
# 1
# 2
# 3
# Python: yield 1; yield 2; yield 3  (a generator producing multiple values)
# Excel:  no direct equivalent (a cell can only hold one value)
```

#### Multiple Outputs + Pipe

When the left side of `|` produces multiple values, the right side runs **once per
value**:

```bash
echo '[1,2,3]' | jq '.[] | . * 10'
# Python: [x * 10 for x in [1,2,3]]
# Excel:  =A1*10 dragged down a column of values
```

Trace:

```text
. = [1,2,3]

Step 1: .[]
  input:  [1,2,3]
  outputs: 1, 2, 3              ← three separate values

  ── pipe: right side runs three times ──

Step 2a: . * 10   with . = 1  →  10
Step 2b: . * 10   with . = 2  →  20
Step 2c: . * 10   with . = 3  →  30

Final outputs: 10, 20, 30
```

> **Familiar?** This is like a nested list comprehension in Python:
> ```python
> [x * 10 for x in [1, 2, 3]]
> # [10, 20, 30]
> ```
> Each output from the left becomes an independent input to the right.

#### Collecting with `[...]`

Multiple outputs are separate values. Wrap in `[...]` to collect them into one array:

```bash
echo '[1,2,3]' | jq '[.[] | . * 10]'
# [10, 20, 30]    ← one array, not three values
# Python: list(x * 10 for x in [1,2,3])  — wrapping a generator in list()
# Excel:  a spill formula like =A1:A3*10 (outputs to a range)
```

### Rule 4: `-n` Sets Initial `.` to `null`

Normally, jq reads JSON from stdin and that becomes `.`. With `-n`, nothing is read —
`.` starts as `null`.

```bash
# without -n: . = whatever comes from stdin
echo '{"a":1}' | jq '.'
# {"a":1}

# with -n: . = null, stdin is ignored
echo '{"a":1}' | jq -n '.'
# null
# Python: x = None  (starting with no input)
# Excel:  an empty cell (no input data)
```

Why use `-n`? When you want to pull inputs manually with `input`/`inputs` instead of
letting jq auto-feed them.

### Rule 5: `input` and `inputs` Pull from the File Queue

When you pass files to jq, they go into a queue. `input` pulls one, `inputs` drains
the rest.

```bash
echo '{"a":1}' > /tmp/f1.json
echo '{"b":2}' > /tmp/f2.json
echo '{"c":3}' > /tmp/f3.json
# Python: writing files — open("f1.json","w").write(...)
# Excel:  no direct equivalent (file I/O is not an Excel concept)
```

Without `-n`, jq auto-feeds each file into `.` and runs the filter once per file:

```bash
jq '.' /tmp/f1.json /tmp/f2.json /tmp/f3.json
# {"a":1}
# {"b":2}
# {"c":3}
# (filter runs three times, once per file)
# Python: for f in files: print(json.load(open(f)))
# Excel:  no direct equivalent (no multi-file iteration)
```

With `-n`, you control the reading:

```bash
# input: pull ONE value from the queue
jq -n 'input' /tmp/f1.json /tmp/f2.json /tmp/f3.json
# {"a":1}

# inputs: pull ALL remaining values
jq -n '[inputs]' /tmp/f1.json /tmp/f2.json /tmp/f3.json
# [{"a":1},{"b":2},{"c":3}]
# Python: next(iter)  vs  list(iter) — pull one vs drain all from an iterator
# Excel:  no direct equivalent
```

### Putting It All Together

```bash
jq -n 'input as $base | [inputs] | map(. + $base)' /tmp/f1.json /tmp/f2.json /tmp/f3.json
# Python: base = next(it); [{**x, **base} for x in it]
# Excel:  no direct equivalent
```

Full trace:

```text
. = null                              ← -n sets this
file queue: [{"a":1}, {"b":2}, {"c":3}]


Step 1: input
  pulls from queue: {"a":1}
  queue is now: [{"b":2}, {"c":3}]
  output: {"a":1}


Step 2: as $base
  binds: $base = {"a":1}
  . passes through unchanged
  output: {"a":1}

  ── pipe: . = {"a":1} ──


Step 3: [inputs]
  inputs drains queue: {"b":2}, {"c":3}
  queue is now: []
  [...] collects them: [{"b":2}, {"c":3}]
  output: [{"b":2}, {"c":3}]

  (note: . was {"a":1} here, but we didn't use it)

  ── pipe: . = [{"b":2}, {"c":3}] ──


Step 4: map(. + $base)
  . = [{"b":2}, {"c":3}]
  $base = {"a":1}

  map iterates:
    element 1: {"b":2} + {"a":1} = {"b":2, "a":1}
    element 2: {"c":3} + {"a":1} = {"c":3, "a":1}

  output: [{"b":2,"a":1}, {"c":3,"a":1}]


Final output: [{"b":2,"a":1}, {"c":3,"a":1}]
```

### Summary: The Five Rules

1. **Every filter has input (`.`) and output(s)** — Everything is `input → filter → output`
2. **Pipe redefines `.`** — `A | B`: output of `A` becomes `.` inside `B`
3. **Variables survive, `.` does not** — `$var` persists across pipes; `.` is replaced at each pipe
4. **Multiple outputs fork execution** — If `A` produces 3 values, `B` runs 3 times
5. **`-n` + `input`/`inputs` for manual control** — Without `-n`, jq auto-feeds inputs; with `-n`, you pull explicitly

---

## The Identity Filter: `.`

The simplest jq program is `.` — it passes input through unchanged. Think of it as
Python's `lambda x: x`, or an Excel cell that simply references another cell (`=A1`).

```bash
echo '{"name": "Alice", "age": 30}' | jq '.'
# Python: json.dumps(d, indent=2)  — pretty-printed identity
# Excel:  =A1 (pass-through reference)
```

Output:

```json
{
  "name": "Alice",
  "age": 30
}
```

jq pretty-prints by default. Use `-c` for compact output:

```bash
echo '{"name":"Alice","age":30}' | jq -c '.'
# {"name":"Alice","age":30}
# Python: json.dumps(d, separators=(",",":"))  — compact/minified
# Excel:  no direct equivalent (Excel has no JSON formatting)
```

## Field Access: `.field`

Access object fields with dot notation, similar to Python's `d["key"]` or Excel's
`VLOOKUP` picking a column from a row:

```bash
echo '{"name": "Alice", "age": 30}' | jq '.name'
# "Alice"

echo '{"name": "Alice", "age": 30}' | jq '.age'
# 30
# Python: d["name"], d["age"]
# Excel:  VLOOKUP("name", table, 2, FALSE) or INDEX/MATCH
```

For keys with special characters or spaces, quote them:

```bash
echo '{"first-name": "Alice", "last name": "Smith"}' | jq '."first-name"'
# "Alice"

echo '{"first-name": "Alice", "last name": "Smith"}' | jq '."last name"'
# "Smith"
# Python: d["first-name"], d["last name"]  (bracket syntax handles any key)
# Excel:  INDIRECT with special characters in named ranges
```

### Chained Access

Chain fields to navigate nested structures:

```bash
echo '{"user": {"address": {"city": "Tokyo"}}}' | jq '.user.address.city'
# "Tokyo"
# Python: d["user"]["address"]["city"]
# Excel:  no direct equivalent (no native nested data traversal)
```

> **Familiar?** This is like `json["user"]["address"]["city"]` in Python, but with
> automatic null propagation — accessing a missing key returns `null` instead of
> throwing `KeyError`. In Excel, this is like chaining `INDEX/MATCH` lookups into
> nested tables.

### Null Propagation

Accessing a field on `null` returns `null`, not an error:

```bash
echo '{"a": 1}' | jq '.b'
# null

echo '{"a": 1}' | jq '.b.c.d'
# null
# Python: d.get("b")  → None (dict.get returns None for missing keys)
# Excel:  IFERROR(VLOOKUP(...), "") — returns blank instead of #REF!
```

This is like Python's `dict.get("key")` returning `None` instead of raising `KeyError`,
or Excel's `IFERROR` returning a blank instead of `#REF!`. Convenient for exploration,
but it can hide bugs — a typo in a field name silently returns `null`.

## Array Indexing: `.[n]`

Zero-based, like every language you know:

```bash
echo '["a", "b", "c", "d"]' | jq '.[0]'
# "a"

echo '["a", "b", "c", "d"]' | jq '.[2]'
# "c"
# Python: lst[0], lst[2]
# Excel:  INDEX(A1:A4, 1), INDEX(A1:A4, 3)  (1-based in Excel)
```

Negative indices count from the end (like Python, or Excel's `INDEX(A:A, ROWS(A:A))`):

```bash
echo '["a", "b", "c", "d"]' | jq '.[-1]'
# "d"

echo '["a", "b", "c", "d"]' | jq '.[-2]'
# "c"
# Python: lst[-1], lst[-2]
# Excel:  INDEX(A1:A4, ROWS(A1:A4)) — last element; no native negative indexing
```

## Array Slicing: `.[m:n]`

Slices work like Python's `list[m:n]` — inclusive start, exclusive end:

```bash
echo '["a", "b", "c", "d", "e"]' | jq '.[1:3]'
# ["b", "c"]

echo '["a", "b", "c", "d", "e"]' | jq '.[:2]'
# ["a", "b"]

echo '["a", "b", "c", "d", "e"]' | jq '.[3:]'
# ["d", "e"]

echo '["a", "b", "c", "d", "e"]' | jq '.[-2:]'
# ["d", "e"]
# Python: lst[1:3], lst[:2], lst[3:], lst[-2:]  (identical semantics)
# Excel:  OFFSET/INDEX to grab sub-ranges — no native slice syntax
```

String slicing works too:

```bash
echo '"hello world"' | jq '.[0:5]'
# "hello"
# Python: s[0:5]  (string slicing, same semantics)
# Excel:  LEFT("hello world", 5) or MID("hello world", 1, 5)
```

## Array/Object Iterator: `.[]`

`.[]` iterates over all values. This is the gateway to jq's generator model — it
produces **multiple outputs** from a single input.

```bash
echo '["a", "b", "c"]' | jq '.[]'
# "a"
# "b"
# "c"
# Python: iter(["a","b","c"])  — yields each element
# Excel:  A1:A3 treated as individual cells (each row separately)
```

For objects, it iterates over values (not keys):

```bash
echo '{"x": 1, "y": 2, "z": 3}' | jq '.[]'
# 1
# 2
# 3
# Python: d.values()  → dict_values([1, 2, 3])
# Excel:  no direct equivalent (no native key-value iteration)
```

> **Familiar?** `.[]` is like:
> - Python: the `for x in xs` part of a comprehension
> - Excel: applying a formula to every row in a column (dragging down)

## The Pipe: `|`

Pipes feed the output of one filter into the next, just like Unix pipes but operating
on structured JSON values instead of text:

```bash
echo '{"users": [{"name": "Alice"}, {"name": "Bob"}]}' | jq '.users | .[0] | .name'
# "Alice"
# Python: d["users"][0]["name"]
# Excel:  INDEX(users_col, 1) then lookup "name" field — multi-step
```

Equivalent shorthand (chaining field access):

```bash
echo '{"users": [{"name": "Alice"}, {"name": "Bob"}]}' | jq '.users[0].name'
# "Alice"
# Python: d["users"][0]["name"]  (same as above, just shorthand)
# Excel:  same multi-step lookup as above
```

When the left side produces multiple outputs, the right side runs **once per output**:

```bash
echo '{"users": [{"name": "Alice"}, {"name": "Bob"}]}' | jq '.users[] | .name'
# "Alice"
# "Bob"
# Python: [u["name"] for u in d["users"]]
# Excel:  dragging =INDEX(users,ROW(),"name") down each row
```

> **Familiar?** This is like a list comprehension in Python:
> ```python
> [u["name"] for u in users]
> ```
> Each output from `.users[]` becomes an independent input to `.name`.

## The Comma Operator: `,`

The comma produces multiple outputs from a single input:

```bash
echo '{"a": 1, "b": 2, "c": 3}' | jq '.a, .c'
# 1
# 3
# Python: (d["a"], d["c"])  — selecting multiple values
# Excel:  =A1, =C1 in separate cells (each is an independent formula)
```

This is a generator — it outputs `.a` then `.c` independently. You'll learn more about
this in Tutorial 05.

## Collecting into Arrays: `[...]`

Wrap any expression in `[...]` to collect all its outputs into a single array:

```bash
echo '{"a": 1, "b": 2, "c": 3}' | jq '[.a, .b, .c]'
# [1, 2, 3]

echo '[1, 2, 3, 4, 5]' | jq '[.[] | . * 10]'
# [10, 20, 30, 40, 50]
# Python: [d["a"], d["b"], d["c"]]  /  [x*10 for x in lst]
# Excel:  ={A1, B1, C1} (array literal)  /  =A1:A5*10 (spill formula)
```

> **Familiar?** `[expr]` is like wrapping a generator in `list()` in Python.
> - Excel: collecting computed values into a new column/range

## Parentheses for Grouping

Parentheses control evaluation order:

```bash
echo '5' | jq '. * (2 + 3)'
# 25

echo '5' | jq '(. * 2) + 3'
# 13
# Python: x * (2 + 3)  /  (x * 2) + 3
# Excel:  =A1*(2+3)  /  =(A1*2)+3
```

## Essential CLI Flags

| Flag | Long form | Purpose |
|------|-----------|---------|
| `-r` | `--raw-output` | Print strings without quotes |
| `-c` | `--compact-output` | Minify output (no pretty-print) |
| `-n` | `--null-input` | Don't read stdin; start with `null` |
| `-s` | `--slurp` | Read all inputs into one array |
| `-S` | `--sort-keys` | Sort object keys alphabetically |
| `-e` | `--exit-status` | Exit 1 if last output is false/null |
| | `--arg name val` | Bind a string variable |
| | `--argjson name val` | Bind a JSON variable |
| | `--rawfile name file` | Bind file contents as string |
| | `--jsonargs` | Remaining args are JSON values |
| | `--indent n` | Set indentation level (default 2) |

### `-r` — Raw Output

Without `-r`, strings include quotes:

```bash
echo '{"name": "Alice"}' | jq '.name'
# "Alice"

echo '{"name": "Alice"}' | jq -r '.name'
# Alice
# Python: print(d["name"])  — no quotes vs print(repr(d["name"])) — with quotes
# Excel:  no direct equivalent (Excel cells never show JSON quotes)
```

Essential when piping jq output to other commands.

### `-n` — Null Input

Generates output without reading stdin:

```bash
jq -n '1 + 2'
# 3

jq -n '{"greeting": "hello"}'
# {"greeting": "hello"}
# Python: 1 + 2  /  {"greeting": "hello"}  (no input needed, just evaluate)
# Excel:  =1+2  /  no direct equivalent (Excel doesn't construct JSON)
```

### `-s` — Slurp

Reads multiple JSON values into a single array:

```bash
echo -e '{"a":1}\n{"a":2}\n{"a":3}' | jq -s '.'
# [{"a": 1}, {"a": 2}, {"a": 3}]

echo -e '{"a":1}\n{"a":2}\n{"a":3}' | jq -s 'map(.a) | add'
# 6
# Python: items = [json.loads(l) for l in lines]  /  sum(x["a"] for x in items)
# Excel:  importing multiple rows into one table  /  =SUM(A:A)
```

### `--arg` and `--argjson` — Passing Variables

Pass external values into jq without string interpolation hazards:

```bash
jq -n --arg name "Alice" '{"greeting": "Hello, \($name)!"}'
# {"greeting": "Hello, Alice!"}

jq -n --argjson count 42 '{"count": $count, "doubled": ($count * 2)}'
# {"count": 42, "doubled": 84}
# Python: name="Alice"; f"Hello, {name}!"  /  count=42; {"count": count, "doubled": count*2}
# Excel:  ="Hello, "&A1&"!"  /  no direct equivalent for parameterized JSON
```

`--arg` always creates a string. Use `--argjson` for numbers, booleans, arrays, objects.

## Exercises

1. Extract the `city` from: `{"address": {"city": "Berlin", "country": "DE"}}`
2. Get the last element of: `[10, 20, 30, 40, 50]`
3. Slice elements 2 through 4 (indices 1-3) from: `["a","b","c","d","e"]`
4. Extract all names from: `[{"name":"Jo"},{"name":"Li"},{"name":"Mo"}]`
5. Use `--arg` to create `{"message": "Hello, <your-name>!"}` with your name

<details>
<summary>Solutions</summary>

```bash
# 1
echo '{"address":{"city":"Berlin","country":"DE"}}' | jq '.address.city'
# Python: d["address"]["city"]
# Excel:  no direct equivalent

# 2
echo '[10, 20, 30, 40, 50]' | jq '.[-1]'
# Python: lst[-1]
# Excel:  INDEX(A1:A5, ROWS(A1:A5))

# 3
echo '["a","b","c","d","e"]' | jq '.[1:4]'
# Python: lst[1:4]
# Excel:  OFFSET(A1,1,0,3,1) or INDEX(A1:A5,{2,3,4})

# 4
echo '[{"name":"Jo"},{"name":"Li"},{"name":"Mo"}]' | jq '[.[] | .name]'
# or: jq '[.[].name]'
# Python: [x["name"] for x in lst]
# Excel:  dragging =INDEX(table,ROW(),"name") down each row

# 5
jq -n --arg name "Alice" '{"message": "Hello, \($name)!"}'
# Python: name = "Alice"; {"message": f"Hello, {name}!"}
# Excel:  ="Hello, "&A1&"!"
```

</details>
