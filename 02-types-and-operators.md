# Tutorial 02 — Types and Operators

## jq's Type System

jq has exactly 6 JSON types plus a special `null`:

**jq → Python / Excel:**

| jq type | Python | Excel | Literal examples |
|---------|--------|-------|-----------------|
| `null` | `None` | empty cell | `null` |
| `boolean` | `bool` | `TRUE`/`FALSE` | `true`, `false` |
| `number` | `float`/`int` | number cell | `42`, `3.14`, `1e10` |
| `string` | `str` | text cell | `"hello"` |
| `array` | `list` | row/column range | `[1, "a", null]` |
| `object` | `dict` | named row | `{"k": "v"}` |

**Excel → jq:**

| Excel type | jq type | Notes |
|-----------|---------|-------|
| empty cell | `null` | |
| `TRUE`/`FALSE` | `boolean` | |
| number cell | `number` | |
| text cell | `string` | |
| date/time | `string` | ISO 8601: `"2026-05-04T12:00:00Z"`; use `now`/`strftime`/`strptime` |
| currency | `number` | No decimal type; beware float rounding on cents |
| error (`#N/A`, `#REF!`) | `null` or `string` | `null` to discard, `"#N/A"` to preserve |
| formula | — | Not a data type; jq filters serve this role |

### Type Inspection with `type`

```bash
jq -n '42 | type'
# "number"
# Python: type(42).__name__  → "int"
# Excel:  TYPE(42) → 1 (meaning number)

jq -n '"hello" | type'
# "string"
# Python: type("hello").__name__  → "str"
# Excel:  TYPE("hello") → 2 (meaning text)

jq -n 'null | type'
# "null"
# Python: type(None).__name__  → "NoneType"
# Excel:  TYPE(empty cell) → 1 (Excel has no null type — empty cells are 0 or "")

jq -n '[1,2] | type'
# "array"
# Python: type([1,2]).__name__  → "list"
# Excel:  no direct equivalent — Excel has no TYPE() result for arrays

jq -n '{"a":1} | type'
# "object"
# Python: type({"a":1}).__name__  → "dict"
# Excel:  no direct equivalent — Excel has no dict/object type

echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | type]'
# ["number","string","null","boolean","array","object"]
# Python: [type(x).__name__ for x in [1, "two", None, True, [3], {"a":4}]]
# Excel:  MAP(range, LAMBDA(x, TYPE(x))) — but TYPE() only covers number/text/logical/error
```

### Type-Selecting Builtins

These filters pass through values of a specific type and discard others:

```bash
echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | numbers]'
# [1]

echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | strings]'
# ["two"]

echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | booleans]'
# [true]

echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | nulls]'
# [null]

echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | arrays]'
# [[3]]

echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | objects]'
# [{"a":4}]

echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | scalars]'
# [1,"two",null,true]

echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | iterables]'
# [[3],{"a":4}]

echo '[1, "two", null, true, [3], {"a":4}]' | jq '[.[] | values]'
# [1,"two",true,[3],{"a":4}]

# Python: [x for x in lst if isinstance(x, int|float)]  — use isinstance() per type
# Excel:  no direct equivalent — would need FILTER() with TYPE() checks per row
```

> **Key detail**: `values` filters out `null`. `scalars` keeps everything except arrays
> and objects. `iterables` keeps only arrays and objects.

### Type Conversion

```bash
jq -n '"42" | tonumber'
# 42

jq -n '42 | tostring'
# "42"

jq -n '"true" | toboolean'
# true

jq -n '"false" | toboolean'
# false

# Python: int("42"), str(42), "true".lower() == "true"
# Excel:  VALUE("42"), TEXT(42,"0"), no direct string-to-boolean
```

`toboolean` is new in jq 1.8. It converts `"true"`/`"false"` strings to boolean values.

`tonumber` in jq 1.8 rejects strings with surrounding whitespace — use `trim | tonumber`
if your input might have spaces:

```bash
jq -n '"  42  " | trim | tonumber'
# 42
# Python: int("  42  ".strip())
# Excel:  VALUE(TRIM("  42  "))
```

## Numbers

jq numbers are IEEE 754 double-precision floats. No separate integer type exists.

```bash
jq -n '1 + 0.5'
# 1.5

jq -n '10 / 3'
# 3.3333333333333335

jq -n '2 | pow(.; 53)'
# 9007199254740992

jq -n '(2 | pow(.; 53)) + 1 == (2 | pow(.; 53))'
# true — precision lost beyond 2^53

# Python: Python ints have arbitrary precision (no loss); only floats: float(2**53+1) == float(2**53) → True
# Excel:  same — Excel uses doubles; 2^53+1 loses precision identically
```

### Math Functions

```bash
jq -n '-5 | abs'        # 5      — absolute value
jq -n '3.7 | floor'     # 3      — round down
jq -n '3.2 | ceil'      # 4      — round up
jq -n '3.5 | round'     # 4      — round to nearest
jq -n '16 | sqrt'       # 4      — square root
jq -n '2 | log'         # 0.6931 — natural log
jq -n '1 | exp'         # 2.7183 — e^x
jq -n '2 | pow(.; 10)'  # 1024   — power
jq -n '10 | fabs'       # 10     — float absolute value

jq -n 'infinite'         # 1.7976931348623157e+308 (true infinity; JSON has no infinity literal so displayed as DBL_MAX)
jq -n 'nan'              # null (in output)
jq -n 'infinite | isinfinite'  # true
jq -n 'nan | isnan'            # true
jq -n '42 | isnormal'         # true
jq -n '0 | isnormal'          # false

# Python: abs(), math.floor(), math.ceil(), round(), math.sqrt(), math.log(), math.exp(), pow()
# Excel:  ABS(), FLOOR.MATH(), CEILING.MATH(), ROUND(), SQRT(), LN(), EXP(), POWER()
```

## Arithmetic Operators

```bash
jq -n '10 + 3'    # 13
jq -n '10 - 3'    # 7
jq -n '10 * 3'    # 30
jq -n '10 / 3'    # 3.3333333333333335
jq -n '10 % 3'    # 1  (modulo)
# Python: +, -, *, /, % — identical operators
# Excel:  +, -, *, /, MOD() — same except modulo uses a function
```

### Operator Overloading

`+` and other operators behave differently based on types:

**String concatenation:**

```bash
jq -n '"hello" + " " + "world"'
# "hello world"
# Python: "hello" + " " + "world"
# Excel:  CONCAT("hello"," ","world") or "hello" & " " & "world"
```

**Array concatenation:**

```bash
jq -n '[1, 2] + [3, 4]'
# [1, 2, 3, 4]
# Python: [1, 2] + [3, 4]
# Excel:  no direct equivalent — would need HSTACK() or VSTACK()
```

**Object merging** (`+` is shallow, `*` is deep/recursive):

```bash
jq -n '{"a": 1, "b": 2} + {"b": 3, "c": 4}'
# {"a": 1, "b": 3, "c": 4}  — right side wins on conflicts

jq -n '{"a": {"x": 1, "y": 2}} * {"a": {"y": 3, "z": 4}}'
# {"a": {"x": 1, "y": 3, "z": 4}}  — deep/recursive merge

# Python: {**d1, **d2} (shallow); deep merge needs a library or recursion
# Excel:  no direct equivalent
```

> **Familiar?** `*` on objects works like a deep merge utility — Python's
> `{**d1, **d2}` only does shallow merge, so jq's `*` is more powerful. In Excel,
> think of merging two sheets where the second sheet's values overwrite the first's.

**Subtraction on arrays** (set difference):

```bash
jq -n '[1, 2, 3, 4, 5] - [2, 4]'
# [1, 3, 5]
# Python: [x for x in lst if x not in {2, 4}]
# Excel:  FILTER(range, NOT(ISNUMBER(MATCH(range, {2,4}, 0))))
```

**String repetition:**

```bash
jq -n '"ha" * 3'
# "hahaha"
# Python: "ha" * 3
# Excel:  REPT("ha", 3)
```

**String splitting:**

```bash
jq -n '"a,b,c" / ","'
# ["a", "b", "c"]
# Python: "a,b,c".split(",")
# Excel:  TEXTSPLIT("a,b,c", ",")
```

**Null arithmetic** — `null` acts as identity element:

```bash
jq -n 'null + 1'      # 1
jq -n 'null + "hi"'   # "hi"
jq -n 'null + [1,2]'  # [1,2]
# Python: no equivalent — None + 1 raises TypeError
# Excel:  partial — empty cell + 1 = 1, but empty cell & "hi" = "hi"
```

This is useful with `reduce` — you can start with `null` and `+` will work for any type.

## Comparison Operators

Standard comparisons — works across all types:

```bash
jq -n '1 == 1'     # true
jq -n '1 != 2'     # true
jq -n '1 < 2'      # true
jq -n '2 > 1'      # true
jq -n '1 <= 1'     # true
jq -n '2 >= 3'     # false
# Python: ==, !=, <, >, <=, >= — identical operators
# Excel:  =, <>, <, >, <=, >= — note: Excel uses <> for not-equal
```

**Deep equality** — compares structures recursively:

```bash
jq -n '{"a":1,"b":2} == {"b":2,"a":1}'
# true — key order doesn't matter

jq -n '[1,[2,3]] == [1,[2,3]]'
# true — deep structural equality

# Python: == does deep equality on dicts and lists natively
# Excel:  no direct equivalent — EXACT() only works on strings
```

**Cross-type ordering**: `null < false < true < numbers < strings < arrays < objects`

```bash
jq -n 'null < false'       # true
jq -n 'false < true'       # true
jq -n 'true < 0'           # true
jq -n '99 < "a"'           # true
jq -n '"zzz" < []'         # true
jq -n '[] < {}'             # true
# Python: cross-type comparison raises TypeError (Python 3)
# Excel:  no direct equivalent — comparing text to number gives inconsistent results
```

## Logical Operators

```bash
jq -n 'true and false'    # false
jq -n 'true or false'     # true
jq -n 'true | not'        # false
jq -n 'null | not'        # true
# Python: and, or, not — same keywords (but different truthiness rules!)
# Excel:  AND(), OR(), NOT() — same logic as functions
```

**Truthiness**: Only `false` and `null` are falsy. Everything else is truthy —
including `0`, `""`, `[]`, `{}`.

```bash
jq -n '0 | if . then "truthy" else "falsy" end'
# "truthy" — unlike Python/Excel where 0 is falsy!

jq -n '"" | if . then "truthy" else "falsy" end'
# "truthy" — unlike Python/Excel where "" is falsy!

jq -n '[] | if . then "truthy" else "falsy" end'
# "truthy"

# Python: bool(0)→False, bool("")→False, bool([])→False — all falsy in Python!
# Excel:  IF(0,...)→falsy, IF("",...)→falsy — same as Python, opposite of jq
```

> **Watch out**: This is one of the biggest gotchas for Python/Excel developers.
> In jq, only `null` and `false` are falsy. `0`, `""`, and `[]` are all truthy.
> In Excel, `0` and `""` are both falsy in `IF()` — jq treats them as truthy.

## String Operations

### String Interpolation

```bash
echo '{"name": "Alice", "age": 30}' | jq '"Hello, \(.name)! Age: \(.age)"'
# "Hello, Alice! Age: 30"
# Python: f"Hello, {d['name']}! Age: {d['age']}"
# Excel:  "Hello, " & A1 & "! Age: " & B1
```

You can nest arbitrary jq expressions inside `\(...)`:

```bash
echo '[1, 2, 3]' | jq '"Sum: \(add), Count: \(length)"'
# "Sum: 6, Count: 3"
# Python: f"Sum: {sum(lst)}, Count: {len(lst)}"
# Excel:  "Sum: " & SUM(A1:A3) & ", Count: " & COUNT(A1:A3)
```

### Case Conversion

```bash
jq -n '"Hello World" | ascii_downcase'
# "hello world"

jq -n '"Hello World" | ascii_upcase'
# "HELLO WORLD"

# Python: "Hello World".lower(), "Hello World".upper()
# Excel:  LOWER("Hello World"), UPPER("Hello World")
```

### Trimming

New in jq 1.8 — `trim`, `ltrim`, `rtrim` handle Unicode whitespace:

```bash
jq -n '"  hello  " | trim'
# "hello"

jq -n '"  hello  " | ltrim'
# "hello  "

jq -n '"  hello  " | rtrim'
# "  hello"

# Python: "  hello  ".strip(), .lstrip(), .rstrip()
# Excel:  TRIM() — trims leading/trailing AND collapses internal spaces (unlike jq/Python which only trim ends); no left/right-only variant
```

Trim specific prefixes/suffixes:

```bash
jq -n '"hello world" | ltrimstr("hello ")'
# "world"

jq -n '"hello world" | rtrimstr(" world")'
# "hello"

jq -n '"***hello***" | trimstr("***")'
# "hello"

# Python: "hello world".removeprefix("hello "), .removesuffix(" world")
# Excel:  no direct equivalent — would need MID()/LEFT()/RIGHT() with LEN()
```

`trimstr` is new in jq 1.8 — removes the string from both ends.

### Testing and Searching

```bash
jq -n '"foobar" | startswith("foo")'
# true

jq -n '"foobar" | endswith("bar")'
# true

jq -n '"foobar" | contains("oba")'
# true

jq -n '"oba" | inside("foobar")'
# true

# Python: "foobar".startswith("foo"), .endswith("bar"), "oba" in "foobar"
# Excel:  LEFT("foobar",3)="foo", RIGHT("foobar",3)="bar", ISNUMBER(SEARCH("oba","foobar"))
```

### Splitting and Joining

```bash
jq -n '"a,b,c" | split(",")'
# ["a", "b", "c"]

jq -n '["a", "b", "c"] | join("-")'
# "a-b-c"

# Python: "a,b,c".split(","), "-".join(["a","b","c"])
# Excel:  TEXTSPLIT("a,b,c", ","), TEXTJOIN("-", TRUE, A1:C1)
```

### String to/from Codepoints

```bash
jq -n '"ABC" | explode'
# [65, 66, 67]

jq -n '[72, 101, 108, 108, 111] | implode'
# "Hello"

# Python: [ord(c) for c in "ABC"], "".join(chr(c) for c in [72,101,108,108,111])
# Excel:  CODE("A")→65 (one char at a time), CHAR(72)→"H" (one codepoint at a time)
```

### `length` on Strings

Returns the number of Unicode codepoints (not bytes):

```bash
jq -n '"hello" | length'
# 5

jq -n '"café" | length'
# 4

jq -n '"café" | utf8bytelength'
# 5  — the 'é' is 2 bytes in UTF-8

# Python: len("hello")→5, len("café")→4, len("café".encode("utf-8"))→5
# Excel:  LEN("hello")→5, LEN("café")→4; no byte-length function
```

## The `length` Function (Polymorphic)

`length` works on every type:

```bash
jq -n 'null | length'       # 0
jq -n '42 | length'         # 42 (for numbers, length = absolute value)
jq -n '-5 | length'         # 5
jq -n '"hello" | length'    # 5 (codepoints)
jq -n '[1,2,3] | length'    # 3 (elements)
jq -n '{"a":1,"b":2} | length'  # 2 (keys)
# Python: len() works on str/list/dict; raises TypeError on None/bool/int
# Excel:  LEN() for strings, COUNTA() for ranges, ROWS()/COLUMNS() for arrays
```

## Exercises

1. What is the type of each element in `[42, "hello", null, true, [1], {"a":2}]`?
   Use `map(type)`.
2. What is `"ha" * 5`?
3. What does `[1,2,3,4,5] - [2,4]` produce?
4. Deep merge `{"db":{"host":"localhost","port":5432}}` with
   `{"db":{"port":3306,"name":"mydb"}}` using `*`.
5. Build the string `"3 items totaling 60"` from the input `[10, 20, 30]` using
   string interpolation.

<details>
<summary>Solutions</summary>

```bash
# 1
echo '[42,"hello",null,true,[1],{"a":2}]' | jq 'map(type)'
# ["number","string","null","boolean","array","object"]
# Python: [type(x).__name__ for x in [42,"hello",None,True,[1],{"a":2}]]

# 2
jq -n '"ha" * 5'
# "hahahahaha"
# Python: "ha" * 5
# Excel:  REPT("ha", 5)

# 3
jq -n '[1,2,3,4,5] - [2,4]'
# [1,3,5]
# Python: [x for x in [1,2,3,4,5] if x not in {2,4}]

# 4
jq -n '{"db":{"host":"localhost","port":5432}} * {"db":{"port":3306,"name":"mydb"}}'
# {"db":{"host":"localhost","port":3306,"name":"mydb"}}
# Python: needs a recursive merge function — no built-in deep merge

# 5
echo '[10,20,30]' | jq '"\(length) items totaling \(add)"'
# "3 items totaling 60"
# Python: f"{len(lst)} items totaling {sum(lst)}"
# Excel:  COUNT(A1:A3) & " items totaling " & SUM(A1:A3)
```

</details>
