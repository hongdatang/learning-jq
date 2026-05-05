# Tutorial 07 — Defining Functions

## Basic Function Definition

```
def NAME: BODY;
def NAME(ARGS): BODY;
```

Functions are filters — they receive input via `.` and produce output:

```bash
echo '5' | jq 'def double: . * 2; double'
# 10

echo '[1, 2, 3]' | jq 'def double: . * 2; map(double)'
# [2, 4, 6]
# Python: double = lambda x: x * 2; list(map(double, [1,2,3]))
# Excel:  =A1*2 (drag down)
```

### Functions with Arguments

Arguments are separated by **semicolons**, not commas:

```bash
echo '5' | jq 'def add_mul(x; y): (. + x) * y; add_mul(3; 2)'
# 16  — (5 + 3) * 2

echo '10' | jq 'def clamp(lo; hi): if . < lo then lo elif . > hi then hi else . end; clamp(0; 5)'
# 5
# Python: clamp = lambda val, lo, hi: max(lo, min(hi, val)); clamp(10, 0, 5)
# Excel:  =MIN(5, MAX(0, A1))
```

> **Semicolons, not commas!** This is the #1 syntax gotcha. jq uses commas for
> generators (multiple outputs), so function arguments use semicolons instead.

### Chaining Function Definitions

Multiple `def` statements can be chained. Later definitions can use earlier ones:

```bash
echo '4' | jq '
  def square: . * .;
  def cube: . * . * .;
  def sum_of_powers: square + cube;
  sum_of_powers'
# 80  — 16 + 64
# Python: square = lambda x: x**2; cube = lambda x: x**3; square(4) + cube(4)
# Excel:  =A1^2 + A1^3
```

## Arguments Are Filters (Not Values)

This is jq's most surprising feature for programmers from other languages.

When you write `def f(x): ...`, `x` is **not** a value — it's an unevaluated expression
(a closure/thunk). Each time you reference `x` in the body, it re-evaluates against the
current input.

```bash
echo '5' | jq '
  def apply_twice(f): f | f;
  apply_twice(. + 1)'
# 7  — (5 + 1) = 6, then (6 + 1) = 7
# Python: apply_twice = lambda f, x: f(f(x)); apply_twice(lambda x: x+1, 5)
# Excel:  no direct equivalent (nest formulas manually: =A1+1+1)
```

`f` here is the expression `. + 1`. When called:
1. First `f`: input is `5`, `. + 1` = `6`
2. Second `f`: input is `6`, `. + 1` = `7`

> **Familiar?** This is like passing a function in Python:
> ```python
> def apply_twice(f, x): return f(f(x))
> ```
> In Excel, it's like `LAMBDA()` (Excel 365) — you pass a formula as an argument,
> and it re-evaluates against each cell.

### Higher-Order Functions

Because arguments are filters, every function is naturally higher-order:

```bash
echo '[1, 2, 3, 4, 5]' | jq '
  def my_map(f): [.[] | f];
  my_map(. * 10)'
# [10, 20, 30, 40, 50]

echo '[1, 2, 3, 4, 5, 6]' | jq '
  def my_filter(pred): [.[] | select(pred)];
  my_filter(. > 3)'
# [4, 5, 6]

echo '[3, 1, 4, 1, 5]' | jq '
  def my_count(pred): map(select(pred)) | length;
  my_count(. > 2)'
# 3
# Python: list(map(lambda x: x*10, data)); list(filter(lambda x: x>3, data)); sum(1 for x in data if x>2)
# Excel:  =A1*10 (map); =FILTER(A1:A6, A1:A6>3); =COUNTIF(A1:A5, ">2")
```

### Value Arguments (When You Want Evaluated Values)

If you need the argument evaluated once and stored, bind it with `as`:

```bash
echo '5' | jq '
  def add_to(x): x as $v | . + $v;
  add_to(. * 2)'
# 15  — x is evaluated to (5 * 2) = 10, then . + 10 = 15
# Python: add_to = lambda val, x: val + x; add_to(5, 5*2)
# Excel:  =A1 + A1*2
```

Or use `$`-prefixed parameter names — they bind the value:

```bash
echo '5' | jq '
  def add_to($v): . + $v;
  add_to(. * 2)'
# 15  — $v is bound to the evaluated value of (. * 2) = 10
# Python: add_to = lambda val, v: val + v; add_to(5, 5*2)
# Excel:  =A1 + A1*2
```

`def f($x): body;` is syntactic sugar for `def f(x): x as $x | body;`.

## Recursion

jq supports recursive functions. Tail-recursive calls are optimized.

### Factorial

```bash
echo '10' | jq '
  def factorial:
    if . <= 1 then 1
    else . as $n | (. - 1) | factorial | . * $n
    end;
  factorial'
# 3628800
# Python: import math; math.factorial(10)
# Excel:  =FACT(10)
```

### Fibonacci (Efficient, with Reduce)

```bash
echo '10' | jq '
  def fib:
    . as $n |
    reduce range($n) as $_ ([0, 1]; [.[1], .[0] + .[1]])
    | .[0];
  fib'
# 55
# Python: functools.reduce(lambda a, _: (a[1], a[0]+a[1]), range(10), (0,1))[0]
# Excel:  no direct equivalent (use helper column: B1=0, B2=1, B3=B1+B2, drag)
```

### Tree Traversal

```bash
echo '{"val":1,"children":[{"val":2,"children":[]},{"val":3,"children":[{"val":4,"children":[]}]}]}' \
  | jq '
  def flatten_tree: .val, (.children[] | flatten_tree);
  [flatten_tree]'
# [1, 2, 3, 4]
# Python: def flatten(t): return [t["val"]] + [v for c in t["children"] for v in flatten(c)]
# Excel:  no direct equivalent
```

### Custom `recurse`

The builtin `recurse(f; cond)` is generally preferred for recursive patterns because
it's implemented iteratively (no stack overflow risk):

```bash
jq -n '
  def powers_of_2: [1 | recurse(. * 2; . < 1000)];
  powers_of_2'
# [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]
# Python: list(itertools.takewhile(lambda x: x < 1000, (2**i for i in range(20))))
# Excel:  =POWER(2, ROW()-1) drag down, stop at 512
```

## `walk(f)` — Transform Every Value in a Tree

`walk(f)` applies `f` bottom-up to every value in a JSON structure:

```bash
echo '{"a": "hello", "b": [1, "world", {"c": "foo"}]}' | jq '
  walk(if type == "string" then ascii_upcase else . end)'
# {"a":"HELLO","b":[1,"WORLD",{"c":"FOO"}]}

echo '{"a": 1, "b": null, "c": {"d": null, "e": 2}}' | jq '
  walk(if type == "object" then with_entries(select(.value != null)) else . end)'
# {"a":1,"c":{"e":2}}
# Python: def walk(obj, f): ... (recursive function applying f to all nested values)
# Excel:  no direct equivalent
```

## Scoping Rules

Functions see:
1. All `def`s defined before them in the same scope
2. All `$variables` bound in enclosing scopes (lexical/closure scoping)
3. Shadowing is allowed — inner definitions shadow outer ones

```bash
jq -n '
  def f: "outer";
  def g:
    def f: "inner";
    f;
  f, g'
# "outer"
# "inner"
# Python: same as nested def — inner def shadows outer def within its scope
# Excel:  no direct equivalent (NAME scoping is global)
```

Variables captured as closures:

```bash
echo '{"x": 10}' | jq '
  .x as $x |
  def add_x: . + $x;
  [1, 2, 3] | map(add_x)'
# [11, 12, 13]
# Python: x = 10; add_x = lambda v: v + x; list(map(add_x, [1,2,3]))  (closure over x)
# Excel:  =A1+$B$1 (absolute reference acts like a closed-over variable)
```

## Practical Function Patterns

### Null-Safe Field Access

```bash
echo '{"user":{"address":{"city":"Tokyo"}}}' | jq '
  def get(path): path // null;
  get(.user.address.city), get(.user.phone.number)'
# "Tokyo"
# null
# Python: data.get("user", {}).get("address", {}).get("city")  (or glom/pydash deep_get)
# Excel:  =IFERROR(INDIRECT("..."), "")
```

### Validation

```bash
echo '{"name": "", "age": -5}' | jq '
  def validate_name: if (.name | length) > 0 then . else error("name is required") end;
  def validate_age: if .age >= 0 then . else error("age must be non-negative") end;
  def validate: validate_name | validate_age;
  try validate catch "Validation failed: \(.)"'
# "Validation failed: name is required"
# Python: assert len(data["name"]) > 0, "name is required"; assert data["age"] >= 0
# Excel:  =IF(LEN(A1)>0, IF(B1>=0, "valid", "age err"), "name err")
```

### Pipeline Helpers

```bash
echo '[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]' | jq '
  def take(n): .[:n];
  def drop(n): .[n:];
  def where(f): map(select(f));
  def sum: add;

  where(. > 3) | take(4) | sum'
# 22  — [4,5,6,7] | sum
# Python: sum([x for x in data if x > 3][:4])
# Excel:  =SUM(TAKE(FILTER(A1:A10, A1:A10>3), 4))
```

### Memoization Pattern

jq doesn't have built-in memoization, but you can pass a cache through state:

```bash
echo '10' | jq '
  def fib_memo:
    . as $n |
    reduce range(2; $n + 1) as $i (
      {cache: {("0"): 0, ("1"): 1}};
      .cache as $c |
      .cache[($i | tostring)] = ($c[(($i-1) | tostring)] + $c[(($i-2) | tostring)])
    )
    | .cache[($n | tostring)];
  fib_memo'
# 55
# Python: @functools.lru_cache; def fib(n): return fib(n-1)+fib(n-2) if n>1 else n
# Excel:  no direct equivalent (use helper column for iterative fib)
```

## Multi-Arity and Default Arguments

jq doesn't support optional arguments directly. Instead, define multiple functions:

```bash
echo '"hello world"' | jq '
  def pad(n): pad(n; " ");
  def pad(n; char): . + (char * (n - length));
  pad(20; ".")'
# "hello world........."
# Python: "hello world".ljust(20, ".")
# Excel:  =A1 & REPT(".", 20-LEN(A1))
```

## Exercises

1. Write a function `def factorial:` that computes factorial recursively.
   Test with `5`, `0`, `1`.
2. Write `def my_reverse:` that reverses an array using `reduce`.
3. Write `def pluck(key):` that extracts a field from each object in an array.
   Test: `[{"a":1},{"a":2}] | pluck("a")` → `[1,2]`.
4. Write `def compose(f; g):` that applies `f` then `g`. Test:
   `5 | compose(. + 1; . * 2)` → `12`.
5. Write `def deep_keys:` that finds all keys at all depths of an object using `..`.

<details>
<summary>Solutions</summary>

```bash
# 1
echo '5' | jq '
  def factorial: if . <= 1 then 1 else . as $n | (. - 1) | factorial | . * $n end;
  factorial'
# 120
# Python: math.factorial(5)
# Excel:  =FACT(5)

# 2
echo '[1,2,3,4,5]' | jq '
  def my_reverse: reduce .[] as $x ([]; [$x] + .);
  my_reverse'
# [5,4,3,2,1]
# Python: [1,2,3,4,5][::-1]
# Excel:  =SORTBY(A1:A5, SEQUENCE(5,1,5,-1))  (reverses order; SORT descending only works on pre-sorted data)

# 3
echo '[{"a":1,"b":10},{"a":2,"b":20}]' | jq '
  def pluck(key): map(.[key]);
  pluck("a")'
# [1,2]
# Python: [item["a"] for item in data]
# Excel:  just reference the "a" column directly

# 4
echo '5' | jq '
  def compose(f; g): f | g;
  compose(. + 1; . * 2)'
# 12
# Python: compose = lambda f, g: lambda x: g(f(x)); compose(lambda x: x+1, lambda x: x*2)(5)
# Excel:  =(A1+1)*2 (nest formulas)

# 5
echo '{"a":{"b":1,"c":{"d":2}}}' | jq '
  def deep_keys: [.. | objects | keys[]] | unique;
  deep_keys'
# ["a","b","c","d"]
# Python: def deep_keys(d): return sorted({k for v in [d] for k in _recurse_keys(v)})
# Excel:  no direct equivalent
```

</details>
