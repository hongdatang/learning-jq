# Tutorial 04 — Control Flow

## Conditionals: `if-then-elif-else-end`

```bash
echo '3' | jq 'if . > 0 then "positive" elif . == 0 then "zero" else "negative" end'
# "positive"
# Python: "positive" if 3 > 0 else ("zero" if 3 == 0 else "negative")
# Excel:  =IF(A1>0, "positive", IF(A1=0, "zero", "negative"))
```

### `if` Without `else` (New in jq 1.8)

When you omit `else`, it defaults to `.` (identity — pass through unchanged):

```bash
echo '5' | jq 'if . > 10 then "big" end'
# 5  — condition was false, so input passes through unchanged

echo '15' | jq 'if . > 10 then "big" end'
# "big"
# Python: "big" if x > 10 else x
# Excel:  =IF(A1>10, "big", A1)
```

This also works with `elif`:

```bash
echo '{"status": "active", "name": "Alice"}' | jq '
  if .status == "deleted" then empty
  elif .status == "suspended" then .name = .name + " [suspended]"
  end'
# {"status":"active","name":"Alice"}  — no else needed
# Python: if status == "deleted": continue; elif status == "suspended": name += " [suspended]"
# Excel:  =IFS(A1="deleted", "", A1="suspended", B1&" [suspended]", TRUE, B1)
```

### Conditionals Are Expressions

Unlike Python where `if` is a statement, jq's `if` is an expression that produces
a value — like Python's ternary (`x if cond else y`), or Excel's `IF()` function:

```bash
echo '5' | jq '(if . > 3 then "high" else "low" end) + "!"'
# "high!"
# Python: ("high" if 5 > 3 else "low") + "!"
# Excel:  =IF(A1>3, "high", "low") & "!"
```

### Type Dispatch Pattern

```bash
echo '[1, "hello", null, true, [2], {"a":3}]' | jq '.[] |
  if type == "number" then "NUM: \(.)"
  elif type == "string" then "STR: \(.)"
  elif type == "null" then "NULL"
  elif type == "boolean" then "BOOL: \(.)"
  elif type == "array" then "ARR[\(length)]"
  elif type == "object" then "OBJ{\(keys | join(","))}"
  else "UNKNOWN"
  end'
# Python: match type(x): case int|float: ... case str: ... (Python 3.10+ structural match)
# Excel:  =IFS(ISNUMBER(A1),"NUM",ISTEXT(A1),"STR",ISBLANK(A1),"NULL",...)
```

> **Familiar?** This is jq's version of `elif` chains in Python. In Excel, think of
> nested `IF()` calls or `IFS()` checking multiple conditions.

## The Alternative Operator: `//`

`//` returns the left side if it's neither `false` nor `null`; otherwise the right side:

```bash
echo '{"name": "Alice"}' | jq '.age // 0'
# 0  — .age is null

echo '{"name": "Alice", "age": 30}' | jq '.age // 0'
# 30

echo '{}' | jq '.a // .b // .c // "none"'
# "none"  — chained alternatives, like SQL's COALESCE
# Python: d.get("age", 0)  or  next((v for v in [a, b, c] if v is not None), "none")
# Excel:  =IFNA(VLOOKUP(...), 0)  or  =COALESCE (not native, use nested IFs)
```

> **Watch out**: `//` triggers on both `null` AND `false`:
> ```bash
> echo '{"enabled": false}' | jq '.enabled // true'
> # true — not what you'd want! It treats false as "missing"
> ```
> If you need to distinguish `null` from `false`, use an explicit `if`:
> ```bash
> echo '{"enabled": false}' | jq 'if .enabled == null then true else .enabled end'
> # false — correct
> ```

### `//=` — Assign Default

```bash
echo '{"a": 1}' | jq '.b //= 42'
# {"a":1,"b":42}  — .b was null, so it gets the default

echo '{"a": 1, "b": 10}' | jq '.b //= 42'
# {"a":1,"b":10}  — .b already had a value, no change
# Python: d.setdefault("b", 42)
# Excel:  =IF(ISBLANK(B1), 42, B1)
```

## Error Handling: `try-catch`

```bash
echo '"not a number"' | jq 'try tonumber catch "conversion failed"'
# "conversion failed"

echo '42' | jq 'try tonumber catch "conversion failed"'
# 42
# Python: try: int(x) except ValueError: "conversion failed"
# Excel:  =IFERROR(VALUE(A1), "conversion failed")
```

The catch handler receives the error message as its input (`.`):

```bash
echo '"bad"' | jq 'try tonumber catch "Error: \(.)"'
# "Error: Invalid numeric literal at EOF at line 1, column 3 (while parsing 'bad')"
# Python: try: int(x) except ValueError as e: f"Error: {e}"
# Excel:  no direct equivalent (IFERROR cannot access the error message)
```

### `try` Without `catch`

`try` alone silently discards errors (produces `empty`):

```bash
echo '[1, "two", 3, "four", 5]' | jq '[.[] | try tonumber]'
# [1, 3, 5]  — strings that fail tonumber are silently dropped
# Python: [x for x in lst if isinstance(x, (int, float))]  (or wrap int() in try/except)
# Excel:  =IFERROR(VALUE(A1), "")  — blanks out errors
```

> **Familiar?** This is like a `try/except` that silently skips failures in Python.
> In Excel, similar to `IFERROR(expr, "")` which silently blanks out errors.

### The `?` Operator — Shorthand for `try`

```bash
echo '"not_an_object"' | jq '.foo?'
# (no output, no error)  — ? suppresses the "null has no field" error

echo '"not_an_object"' | jq '.foo'
# error: null (null) has no fields

echo '"not_an_array"' | jq '.[]?'
# (no output, no error)

echo '"not_an_array"' | jq '[.[]?]'
# []
# Python: try: d["foo"] except (KeyError, TypeError): None
# Excel:  no direct equivalent (would need nested IFERROR)
```

`.foo?` and `.[]?` are equivalent to `try .foo` and `try .[]`. Use `?` when the
input might not be the expected type (e.g., a string where you expect an object).

### `error` — Raise Custom Errors

```bash
echo '-5' | jq 'if . < 0 then error("input must be non-negative: \(.)") else . end'
# error: input must be non-negative: -5

echo '-5' | jq 'try (if . < 0 then error("negative") else . end) catch .'
# "negative"
# Python: raise ValueError(f"input must be non-negative: {x}")
# Excel:  no direct equivalent (no user-defined exceptions)
```

### `try-catch` as Alternative (Error Fallback)

Different from `//`: `try-catch` catches **errors**, not just null/false:

```bash
echo '"bad"' | jq 'try tonumber catch "fallback"'
# "fallback"  — tonumber raised an error, caught by try-catch

echo '"bad"' | jq 'tonumber // "fallback"'
# error!  — plain // does NOT catch errors, only null/false
# Python: try: int(x) except: "fallback"  (vs.  int(x) if int(x) else "fallback")
# Excel:  =IFERROR(VALUE(A1), "fallback")
```

> **Note**: jq 1.7 had a `?//` operator for this, but it was removed in jq 1.8.
> Use `try expr catch fallback` instead.

Use `try-catch` when the left side might error. Use `//` when it might be null/false.

## Looping Constructs

jq doesn't have `for` or `while` loops in the imperative sense. Instead, it uses
generators and recursion. But it does provide some loop-like builtins.

### `while(cond; update)` — Loop While True

```bash
jq -n '1 | [while(. < 100; . * 2)]'
# [1,2,4,8,16,32,64]

jq -n '1 | [., while(. < 100; . * 2)]'
# [1,1,2,4,8,16,32,64]  — prepending `. ,` duplicates the initial value
# Python: x=1; result=[]; (while x<100: result.append(x); x*=2)  using itertools.takewhile
# Excel:  no direct equivalent (would need VBA or LAMBDA recursion)
```

> **Note**: `while` includes the initial value in its output (the first line
> `[1,2,4,8,16,32,64]` starts with 1). Prepending `. ,` would duplicate it.

### `until(cond; update)` — Loop Until True

`until` keeps updating until the condition becomes true, then outputs the final value:

```bash
jq -n '1 | until(. >= 100; . * 2)'
# 128  — single output: the first value where condition is met

jq -n '0 | until(. >= 10; . + 1)'
# 10
# Python: x=1; while x < 100: x*=2; return x  (or next(x for x in ... if x>=100))
# Excel:  no direct equivalent (would need iteration via VBA or LAMBDA)
```

> **Familiar?** `until` is like a `do-while` that returns the final state. Unlike
> `while` which outputs intermediate values, `until` only outputs the end result.

### `repeat(f)` — Infinite Loop (Until Error)

`repeat(f)` applies `f` repeatedly forever, producing outputs at each step. It stops
only when `f` raises an error. In practice, use `recurse` instead for most cases, as
`repeat` with `limit` has known issues in jq 1.8:

```bash
jq -n '1 | [limit(10; recurse(. * 2))]'
# [1,2,4,8,16,32,64,128,256,512]

jq -n '1 | first(recurse(. * 2) | select(. > 1000))'
# 1024
# Python: list(itertools.islice(iter_doublings(), 10))  or  next(x for x in iter if x>1000)
# Excel:  no direct equivalent (no infinite generators)
```

### `recurse(f)` and `recurse(f; cond)`

`recurse` applies `f` repeatedly, outputting each intermediate value:

```bash
jq -n '1 | [recurse(. * 2; . < 100)]'
# [1,2,4,8,16,32,64]

jq -n '2 | [recurse(. + 1; . <= 5)]'
# [2,3,4,5]
# Python: list(itertools.takewhile(lambda x: x<100, (2**n for n in range(20))))
# Excel:  =SEQUENCE(7,1,1,1) with manual doubling — no clean recursive equivalent
```

### `..` — Recursive Descent

`..` is defined as `recurse(.[]?)` — it descends into every nested value:

```bash
echo '{"a": {"b": [1, {"c": 2}]}}' | jq '[.. | numbers]'
# [1, 2]

echo '{"a": {"b": [1, {"c": 2}]}}' | jq '[.. | strings]'
# []  — no strings in this structure

echo '{"a": {"b": [1, {"c": 2}]}}' | jq '[.. | objects | keys[]]' | jq 'unique'
# ["a","b","c"]
# Python: [v for v in flatten_recursive(d) if isinstance(v, (int, float))]
# Excel:  no direct equivalent (no recursive tree traversal)
```

> **Familiar?** `..` is like an XPath `//` — it searches the entire tree at all depths.

## Label-Break for Early Exit

For advanced control flow, `label-break` lets you exit a generator early:

```bash
echo '[1, 2, 3, 4, 5]' | jq 'label $out | foreach .[] as $x (0; . + $x;
  if . > 6 then ., break $out else . end)'
# 1
# 3
# 6
# 10
# Python: result=[]; s=0; for x in lst: s+=x; result.append(s); if s>6: break
# Excel:  no direct equivalent (no early-exit in formulas)
```

`break $label` is like a "long-range `empty`" — it unwinds back to the `label` and
produces `empty` there. This is how `limit` is implemented internally.

In practice, you'll rarely write `label-break` directly. Use `first`, `limit`, or
`until` instead — they cover most use cases.

## Exercises

1. Given a number, output "fizz" if divisible by 3, "buzz" if by 5,
   "fizzbuzz" if by both, or the number itself. Test with `15`, `9`, `10`, `7`.
2. Given `[1, "two", 3, null, [5]]`, extract only the numbers using `try`.
3. Use `until` to find the smallest power of 3 that exceeds 1000.
4. Given `{"a":1,"b":null,"c":false,"d":"","e":0}`, keep only entries where the
   value is neither `null` nor `false` (use `//`).
5. Use `..` to find all numbers in: `{"x":[1,{"y":2}],"z":{"w":[3,4]}}`

<details>
<summary>Solutions</summary>

```bash
# 1
echo '15' | jq 'if . % 15 == 0 then "fizzbuzz"
  elif . % 3 == 0 then "fizz"
  elif . % 5 == 0 then "buzz"
  else .
  end'
# "fizzbuzz"
# Python: "fizzbuzz" if n%15==0 else "fizz" if n%3==0 else "buzz" if n%5==0 else n
# Excel:  =IF(MOD(A1,15)=0,"fizzbuzz",IF(MOD(A1,3)=0,"fizz",IF(MOD(A1,5)=0,"buzz",A1)))

# 2
echo '[1,"two",3,null,[5]]' | jq '[.[] | try (select(type == "number"))]'
# [1,3]
# or simpler: [.[] | numbers]
# Python: [x for x in lst if isinstance(x, (int, float))]
# Excel:  no direct equivalent (FILTER can't filter by type)

# 3
jq -n '1 | until(. > 1000; . * 3)'
# 2187
# Python: x=1; while x<=1000: x*=3  → x is 2187
# Excel:  =3^ROUNDUP(LOG(1000,3),0)  (mathematical shortcut: =3^7)

# 4
echo '{"a":1,"b":null,"c":false,"d":"","e":0}' \
  | jq 'with_entries(select(.value | . != null and . != false))'
# {"a":1,"d":"","e":0}
# Python: {k: v for k, v in d.items() if v is not None and v is not False}
# Excel:  no direct equivalent (no dict filtering in formulas)

# 5
echo '{"x":[1,{"y":2}],"z":{"w":[3,4]}}' | jq '[.. | numbers]'
# [1,2,3,4]
# Python: [v for v in flatten_recursive(d) if isinstance(v, (int, float))]
# Excel:  no direct equivalent (no recursive traversal)
```

</details>
