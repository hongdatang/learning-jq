# Lesson 13 -- Appendix: Extra jq Features (Optional Reference)

Your lemonade stand is closed for winter. The books are balanced, the
financial statements are filed, and there is nothing left to do but wait
for spring. While you wait, here is a catalog of jq features that did
not fit into the main story. Each section is standalone -- jump to
whatever interests you.

> **How to use this appendix.** Every feature shows a short description,
> an Excel analogy where one exists, and a runnable command. The sample
> data is at `accounting/src/data/13-appendix-samples.json`; a combined
> demo is at `accounting/src/programs/13-appendix-demos.jq`.

```bash
jq -f accounting/src/programs/13-appendix-demos.jq \
  accounting/src/data/13-appendix-samples.json
```

---

## 1. String / Encoding

### `explode` / `implode`

Convert a string to an array of Unicode codepoints, and back.
**Excel**: `CODE("A")` / `CHAR(65)`, but applied to every character.

```bash
jq -n '"Hello" | explode'           # => [72,101,108,108,111]
jq -n '[72,101,108,108,111] | implode'  # => "Hello"
```

### `tojson` / `fromjson`

Serialize a jq value into a JSON string, or parse one back. Useful when
JSON is embedded inside other JSON (log lines, double-encoded APIs).

```bash
jq -n '{name:"lemonade", price:1} | tojson'
# => "{\"name\":\"lemonade\",\"price\":1}"

jq -n '"{\"x\":42}" | fromjson | .x'   # => 42
```

### `@sh` / `@html`

Format strings for safe embedding. `@sh` adds shell quoting; `@html`
escapes `<`, `>`, `&`, and `'`. See also: [Lesson 11](11-financial-statements.md) (`@csv`).

```bash
jq -rn '"/usr/local/bin/jq" | @sh'   # => '/usr/local/bin/jq'
jq -r '.strings.html_unsafe | @html' \
  accounting/src/data/13-appendix-samples.json
# => &lt;script&gt;alert(&apos;xss&apos;)&lt;/script&gt;
```

### `splits(sep)`

Generator version of `split` -- yields pieces one at a time instead of
returning an array. See also: [Lesson 10](10-trial-balance.md) (regex).

```bash
jq -n '"Alice,30,Engineering" | [splits(",")]'
# => ["Alice","30","Engineering"]
```

### `utf8bytelength`

Byte length of a string in UTF-8. Differs from `length`, which counts
codepoints. **Excel**: `LENB()` vs `LEN()`.

```bash
jq -n '"Hello" | utf8bytelength'   # => 5
jq -n '"é" | utf8bytelength'       # => 2  (two bytes in UTF-8)
jq -n '"é" | length'               # => 1  (one codepoint)
```

---

## 2. Math

### Special Values

`nan` and `infinite` are constants. The `is*` family tests for them.
**Excel**: `ISNA()`, `ISNUMBER()`, `ISERR()`.

| Function | Purpose |
|----------|---------|
| `nan` | NaN constant |
| `infinite` | Infinity constant |
| `isnan` | true if NaN |
| `isinfinite` | true if +/- infinity |
| `isfinite` | true if not NaN or infinity |
| `isnormal` | true if normal (not zero, subnormal, inf, or NaN) |

```bash
jq -n 'nan | isnan'                    # => true
jq -n 'infinite | isinfinite'         # => true
jq -n '3.14 | [isfinite, isnormal]'   # => [true, true]
```

### Rounding and Absolute Value

**Excel**: `FLOOR()`, `CEILING()`, `ROUND()`, `ABS()`.

```bash
jq -n '3.14159 | [floor, ceil, round]'   # => [3, 4, 3]
jq -n '-42 | fabs'                        # => 42
```

### Powers, Roots, Logs

**Excel**: `SQRT()`, `POWER()`, `LN()`, `EXP()`.

```bash
jq -n '16 | sqrt'         # => 4
jq -n 'pow(2; 10)'        # => 1024
jq -n '27 | cbrt'         # => 3
jq -n '1 | exp | log'     # => 1  (round-trip)
```

### Trigonometry

All in radians. **Excel**: `SIN()`, `COS()`, `TAN()` (also radians).

Available: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`.

```bash
jq -n '0 | [sin, cos, tan]'   # => [0, 1, 0]
jq -n '1 | asin'              # => 1.5707963267948966  (pi/2)
```

### Float Decomposition

`significand`, `exponent`, and `logb` decompose IEEE 754 floats.

```bash
jq -n '8.0 | [significand, exponent, logb]'
# => [1, 3, 3]   (because 8.0 = 1.0 * 2^3)
```

### `remainder` and `fma`

IEEE remainder and fused multiply-add.

```bash
jq -n 'remainder(10; 3)'   # => 1
jq -n 'fma(2; 3; 4)'       # => 10  (2*3 + 4)
```

See also: [Lesson 02](02-buying-supplies.md) (basic arithmetic).

---

## 3. Array / Object Niche

### `combinations`

Cartesian product. **Excel**: a two-variable data table listing every
pairing.

```bash
jq '[.arrays.colors, .arrays.sizes] | [combinations] | map(join("-"))' \
  accounting/src/data/13-appendix-samples.json
# => ["red-S","red-M","red-L","green-S","green-M","green-L","blue-S",...]
```

See also: [Lesson 05](05-the-balance-sheet.md) (generators).

### `bsearch(val)`

Binary search on a **sorted** array. Returns the index if found, or
`(-1 - insertion_point)` if not. **Excel**: `MATCH(val, range, 1)`.

```bash
jq '.arrays.sorted | bsearch(7)' \
  accounting/src/data/13-appendix-samples.json   # => 3  (found)

jq '.arrays.sorted | bsearch(6)' \
  accounting/src/data/13-appendix-samples.json   # => -4  (not found)
```

### `nth(n; expr)` / `isempty(expr)`

`nth` returns the nth output (0-indexed) of a generator. `isempty`
tests whether a generator produces any output.
**Excel**: `INDEX(array, n)`, but the array is generated on the fly.

```bash
jq -n 'nth(2; range(10))'                              # => 2
jq -n 'nth(4; range(100) | select(. % 2 == 0))'        # => 8
jq -n 'isempty(empty)'                                 # => true
jq -n '[1,2,3] | isempty(.[] | select(. > 5))'         # => true
```

See also: [Lesson 03](03-first-sales.md) (`first`, `last`, `limit`).

### `finites` / `normals`

Type selectors that filter out `nan`, `infinite`, and subnormals.

```bash
jq -n '[1, nan, 2, infinite, 3] | [.[] | finites]'   # => [1, 2, 3]
```

See also: [Lesson 03](03-first-sales.md) (type selectors).

### `builtins`

Lists all built-in function names with arity suffixes.

```bash
jq -n 'builtins | length'   # => ~170+ (varies by jq version)
jq -n '[builtins[] | select(startswith("to"))]'
# => ["todateiso8601/0","todate/0","tojson/0","tonumber/0","tostring/0",...]
```

---

## 4. Advanced Control Flow

### `label-break`

Early exit from a generator. Define a label with `label $name`, then
`break $name` to jump out -- jq's equivalent of `break` in a loop.

```bash
jq -n 'label $out | range(20) | if . > 4 then break $out else . end'
# => 0 1 2 3 4
```

See also: [Lesson 05](05-the-balance-sheet.md) (`limit`),
[Lesson 09](09-cash-flow-statement.md) (`until`).

### `repeat(f)`

Applies `f` to its input forever. Always pair with `limit` or
`label-break` to stop.

```bash
jq -n '[limit(5; 1 | repeat(. * 2))]'    # => [2, 4, 8, 16, 32]
jq -n '[limit(8; 0 | repeat(. + 1))]'    # => [1, 2, 3, 4, 5, 6, 7, 8]
```

See also: [Lesson 09](09-cash-flow-statement.md) (`while`, `until`,
`recurse`).

### `$__loc__`

Returns the source filename and line number. Useful for debugging.

```bash
jq -n '$__loc__'   # => {"file":"<stdin>","line":1}
```

In a `.jq` file it reports the actual filename and line -- helpful when
debugging large programs.

### `halt` / `halt_error`

Terminate jq immediately. `halt` exits with code 0; `halt_error` exits
with a custom code and prints to stderr.

```bash
jq -n '"done" | halt'                              # (exits 0, no output)
jq -n '"something went wrong\n" | halt_error(1)'   # (exits 1, prints to stderr)
```

See also: [Lesson 06](06-the-income-statement.md) (`try-catch`,
`error`).

---

## 5. I/O and Multi-File

### `--jsonargs`

Pass JSON values as positional arguments. They appear in
`$ARGS.positional`. **Excel**: named cells referenced by formulas, but
passed from outside the workbook.

```bash
jq -n --jsonargs '$ARGS.positional' -- '42' '["a","b"]' '"hello"'
# => [42, ["a","b"], "hello"]

jq -n --jsonargs '$ARGS.positional[0] + $ARGS.positional[1]' -- '10' '20'
# => 30
```

Compare with `--arg` ([Lesson 01](01-opening-day.md)) which passes
strings, and `--argjson` which passes a single named JSON value.

### `input_line_number` / `input_filename`

Return the current line number or filename when reading input. Useful
for debugging multi-file or line-delimited pipelines. See also:
[Lesson 12](12-year-in-review.md) (`-s`, `--stream`).

```bash
echo -e '{"a":1}\n{"b":2}' | jq -c '{line: input_line_number, data: .}'
# => {"line":2,"data":{"a":1}}
# => {"line":3,"data":{"b":2}}
```

### `modulemeta`

Inspect metadata of an imported jq module (the `module { ... }` block).
Mainly useful for library authors. See also:
[Lesson 11](11-financial-statements.md) (modules).

---

## Quick-Reference Table

| Feature | Category | Related Lesson |
|---------|----------|----------------|
| `explode`/`implode` | String | -- |
| `tojson`/`fromjson` | String | -- |
| `@sh`, `@html` | String | [11](11-financial-statements.md) (`@csv`) |
| `splits` | String | [10](10-trial-balance.md) (regex) |
| `utf8bytelength` | String | -- |
| `floor`/`ceil`/`round`/`fabs` | Math | [02](02-buying-supplies.md) |
| `sqrt`/`pow`/`log`/`exp`/`cbrt` | Math | -- |
| trig, float decomposition | Math | -- |
| `combinations` | Array | [05](05-the-balance-sheet.md) |
| `bsearch` | Array | [03](03-first-sales.md) |
| `nth`, `isempty` | Array | [05](05-the-balance-sheet.md) |
| `finites`/`normals` | Array | [03](03-first-sales.md) |
| `builtins` | Array | -- |
| `label-break` | Control | [05](05-the-balance-sheet.md) |
| `repeat` | Control | [09](09-cash-flow-statement.md) |
| `$__loc__` | Control | -- |
| `halt`/`halt_error` | Control | [06](06-the-income-statement.md) |
| `--jsonargs` | I/O | [01](01-opening-day.md) |
| `input_line_number` | I/O | [12](12-year-in-review.md) |
| `modulemeta` | I/O | [11](11-financial-statements.md) |

---

## Further Reading

- **jq Manual**: <https://jqlang.github.io/jq/manual/>
- **Developer tutorials** (programmer-focused, with Python analogies):
  - [05-generators-and-backtracking.md](../05-generators-and-backtracking.md) -- generators, `label-break`, `repeat`
  - [02-types-and-operators.md](../02-types-and-operators.md) -- type system, special values, format strings
  - [11-advanced-patterns.md](../11-advanced-patterns.md) -- modules, `$__loc__`, `halt_error`
- **jq Cookbook**: <https://github.com/stedolan/jq/wiki/Cookbook>
