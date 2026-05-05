# Tutorial 03 — Array and Object Operations

## Array Operations

### Constructing Arrays

Wrap any expression in `[...]` to collect its outputs into an array:

```bash
jq -n '[1, 2, 3]'
# [1, 2, 3]

jq -n '[range(5)]'
# [0, 1, 2, 3, 4]

jq -n '[range(1; 10; 2)]'
# [1, 3, 5, 7, 9]

echo '[1, 2, 3, 4, 5]' | jq '[.[] | . * 10]'
# [10, 20, 30, 40, 50]
# Python: list(range(5)); list(range(1,10,2)); [x*10 for x in [1,2,3,4,5]]
# Excel:  =SEQUENCE(5,1,0,1) for ranges; drag formula =A1*10 down for transforms
```

### `map(f)` — Transform Every Element

`map(f)` is shorthand for `[.[] | f]`:

```bash
echo '[1, 2, 3, 4, 5]' | jq 'map(. * 2)'
# [2, 4, 6, 8, 10]

echo '["hello", "world"]' | jq 'map(ascii_upcase)'
# ["HELLO", "WORLD"]

echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq 'map(.name)'
# ["Alice", "Bob"]
# Python: [x*2 for x in xs]; [s.upper() for s in xs]; [d["name"] for d in xs]
# Excel:  =A1*2 dragged down; =UPPER(A1) dragged down; reference the Name column
```

> **Familiar?** Identical to Python's `[f(x) for x in xs]`. In Excel, this is like
> writing a formula in a new column and dragging it down all rows.

### `select(f)` — Filter Elements

`select(f)` keeps the value if `f` is truthy, discards it otherwise:

```bash
echo '[1, 2, 3, 4, 5, 6]' | jq '[.[] | select(. > 3)]'
# [4, 5, 6]

echo '[1, 2, 3, 4, 5, 6]' | jq 'map(select(. % 2 == 0))'
# [2, 4, 6]

echo '[{"name":"Alice","active":true},{"name":"Bob","active":false}]' | jq 'map(select(.active))'
# [{"name":"Alice","active":true}]
# Python: [x for x in xs if x > 3]; [x for x in xs if x % 2 == 0]
# Excel:  =FILTER(A1:A6, A1:A6>3); =FILTER(range, MOD(range,2)=0)
```

> **Familiar?** Like Python's `[x for x in xs if p(x)]`, or Excel's
> `FILTER(range, condition)`.

### Sorting

```bash
echo '[3, 1, 4, 1, 5, 9]' | jq 'sort'
# [1, 1, 3, 4, 5, 9]

echo '[3, 1, 4, 1, 5, 9]' | jq 'sort | reverse'
# [9, 5, 4, 3, 1, 1]

echo '[{"name":"Charlie","age":35},{"name":"Alice","age":30},{"name":"Bob","age":25}]' \
  | jq 'sort_by(.age)'
# [{"name":"Bob","age":25},{"name":"Alice","age":30},{"name":"Charlie","age":35}]

echo '[{"name":"Charlie","age":35},{"name":"Alice","age":30},{"name":"Bob","age":25}]' \
  | jq 'sort_by(.name)'
# sorted alphabetically by name
# Python: sorted(xs); sorted(xs, reverse=True); sorted(xs, key=lambda d: d["age"])
# Excel:  Data > Sort; =SORT(range, col, -1) for descending; =SORTBY(range, key_col)
```

### Grouping

```bash
echo '[{"dept":"eng","name":"Alice"},{"dept":"sales","name":"Bob"},{"dept":"eng","name":"Carol"}]' \
  | jq 'group_by(.dept)'
# [
#   [{"dept":"eng","name":"Alice"},{"dept":"eng","name":"Carol"}],
#   [{"dept":"sales","name":"Bob"}]
# ]
# Python: itertools.groupby(sorted(xs, key=lambda d: d["dept"]), key=lambda d: d["dept"])
# Excel:  pivot table grouped by the "dept" column
```

> **Familiar?** Like Python's `itertools.groupby(sorted(xs, key=f), key=f)`, or creating
> a pivot table in Excel grouped by a column. The result is always sorted by the grouping
> key and returns an array of arrays.

### Uniqueness

```bash
echo '[1, 2, 2, 3, 3, 3]' | jq 'unique'
# [1, 2, 3]

echo '[{"a":1,"b":2},{"a":1,"b":3},{"a":2,"b":4}]' | jq 'unique_by(.a)'
# [{"a":1,"b":2},{"a":2,"b":4}]  — keeps first occurrence
# Python: sorted(set(xs)); seen=set(); [d for d in xs if d["a"] not in seen and not seen.add(d["a"])]
# Excel:  =UNIQUE(range); Data > Remove Duplicates
```

### Min / Max

```bash
echo '[3, 1, 4, 1, 5]' | jq 'min'
# 1

echo '[3, 1, 4, 1, 5]' | jq 'max'
# 5

echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq 'min_by(.age)'
# {"name":"Bob","age":25}

echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq 'max_by(.age)'
# {"name":"Alice","age":30}
# Python: min(xs); max(xs); min(xs, key=lambda d: d["age"])
# Excel:  =MIN(range); =MAX(range); =MINIFS/MAXIFS for conditional
```

### Flattening

```bash
echo '[[1, 2], [3, [4, 5]]]' | jq 'flatten'
# [1, 2, 3, 4, 5]  — fully flattened

echo '[[1, 2], [3, [4, 5]]]' | jq 'flatten(1)'
# [1, 2, 3, [4, 5]]  — one level only
# Python: from itertools import chain; list(chain.from_iterable(xs)) for 1 level; recursive for full
# Excel:  no direct equivalent (flatten nested ranges manually or use Power Query)
```

### `add` — Reduce to Sum/Concatenation

`add` reduces an array using `+`. Works for numbers, strings, arrays, objects:

```bash
echo '[1, 2, 3, 4, 5]' | jq 'add'
# 15

echo '["hello", " ", "world"]' | jq 'add'
# "hello world"

echo '[[1, 2], [3, 4], [5]]' | jq 'add'
# [1, 2, 3, 4, 5]

echo '[{"a":1}, {"b":2}, {"c":3}]' | jq 'add'
# {"a":1,"b":2,"c":3}
# Python: sum(xs); "".join(xs); functools.reduce(operator.or_, dicts)  (Python 3.9+)
# Excel:  =SUM(range); =TEXTJOIN("",TRUE,range); no direct dict merge equivalent
```

New in jq 1.8 — `add(generator)` sums a generator directly without collecting into an
array first:

```bash
echo '10' | jq 'add(range(.))'
# 45  — sum of 0..9 without building an intermediate array
# Python: sum(range(10))
# Excel:  =SUM(SEQUENCE(10,1,0,1))
```

### `any` and `all`

```bash
echo '[1, 2, 3, 4, 5]' | jq 'any(. > 4)'
# true

echo '[1, 2, 3, 4, 5]' | jq 'all(. > 0)'
# true

echo '[1, 2, 3, 4, 5]' | jq 'all(. > 3)'
# false
# Python: any(x > 4 for x in xs); all(x > 0 for x in xs)
# Excel:  =OR(A1:A5>4) with Ctrl+Shift+Enter; =AND(A1:A5>0)
```

### `first`, `last`, `nth`, `limit`, `skip`

```bash
echo '[10, 20, 30, 40, 50]' | jq 'first'
# 10

echo '[10, 20, 30, 40, 50]' | jq 'last'
# 50

echo '[10, 20, 30, 40, 50]' | jq 'nth(2)'
# 30

jq -n '[limit(3; range(100))]'
# [0, 1, 2]  — takes only first 3, doesn't generate all 100

jq -n '[skip(3; range(6))]'
# [3, 4, 5]  — new in jq 1.8, counterpart to limit
# Python: xs[0]; xs[-1]; xs[2]; xs[:3]; xs[3:]
# Excel:  =INDEX(range,1); =INDEX(range,ROWS(range)); =INDEX(range,3)
```

> **Familiar?** `limit` and `skip` are like Python's `xs[:n]` and `xs[n:]`, or selecting
> the first/last N rows of a table in Excel.

### `range` — Generate Number Sequences

```bash
jq -n '[range(5)]'
# [0, 1, 2, 3, 4]

jq -n '[range(2; 7)]'
# [2, 3, 4, 5, 6]

jq -n '[range(0; 1; 0.25)]'
# [0, 0.25, 0.5, 0.75]

jq -n '[range(10; 0; -2)]'
# [10, 8, 6, 4, 2]
# Python: list(range(5)); list(range(2,7)); [x/4 for x in range(4)]; list(range(10,0,-2))
# Excel:  =SEQUENCE(5,1,0,1); =SEQUENCE(5,1,2,1); =SEQUENCE(4,1,0,0.25)
```

### `indices`, `index`, `rindex`

```bash
echo '"abcabc"' | jq 'indices("bc")'
# [1, 4]

echo '[1, 2, 3, 1, 2]' | jq 'index(2)'
# 1

echo '[1, 2, 3, 1, 2]' | jq 'rindex(2)'
# 4
# Python: [i for i,_ in enumerate(s) if s[i:].startswith("bc")]; xs.index(2); len(xs)-1-xs[::-1].index(2)
# Excel:  =FIND("bc",A1) for first occurrence; =MATCH(2,range,0) for index
```

Note: In jq 1.8, these use **codepoint indexing** for strings (not byte indexing).

### `transpose` — Zip Arrays

```bash
echo '[[1, 2, 3], ["a", "b", "c"]]' | jq 'transpose'
# [[1,"a"],[2,"b"],[3,"c"]]
# Python: list(zip(*lists))
# Excel:  select range, Copy, Paste Special > Transpose
```

> **Familiar?** Like Python's `zip(*lists)`, or placing two Excel columns side by side.

### `combinations`

```bash
jq -n '[[1,2], ["a","b"]] | combinations'
# [1,"a"]
# [1,"b"]
# [2,"a"]
# [2,"b"]

jq -n '[combinations(2)]'
# generates nothing from null input — typically used as:
jq -n '[[0,1],[0,1]] | [combinations]'
# [[0,0],[0,1],[1,0],[1,1]]
# Python: list(itertools.product([1,2], ["a","b"]))
# Excel:  no direct equivalent (build manually with helper columns)
```

### `bsearch` — Binary Search

Works on sorted arrays. Returns index if found, or `(-insertionPoint - 1)` if not:

```bash
echo '[1, 2, 3, 4, 5]' | jq 'bsearch(3)'
# 2

echo '[1, 2, 3, 4, 5]' | jq 'bsearch(3.5)'
# -4  — would be inserted at index 3
# Python: import bisect; bisect.bisect_left(xs, 3)
# Excel:  =MATCH(3, range, 1) for approximate match in sorted data
```

## Object Operations

### Constructing Objects

```bash
jq -n '{"name": "Alice", "age": 30}'
# {"name":"Alice","age":30}
# Python: {"name": "Alice", "age": 30}
# Excel:  a row in a table with columns "name" and "age"
```

**Computed keys** — wrap in parentheses:

```bash
jq -n --arg k "name" '{($k): "Alice"}'
# {"name":"Alice"}
# Python: {k: "Alice"} where k is a variable
# Excel:  no direct equivalent (column headers are static)
```

**Variable binding shorthand** (new in jq 1.8) — `{$var}` creates `{"var": value}`:

```bash
echo '{"x": 1, "y": 2}' | jq '.x as $x | .y as $y | {$x, $y}'
# {"x": 1, "y": 2}
# Python: x = d["x"]; y = d["y"]; {"x": x, "y": y}
# Excel:  no direct equivalent
```

**Field shorthand** — `{foo}` is shorthand for `{foo: .foo}`:

```bash
echo '{"name":"Alice","age":30,"city":"Tokyo"}' | jq '{name, city}'
# {"name":"Alice","city":"Tokyo"}
# Python: {k: d[k] for k in ["name", "city"]}
# Excel:  select only the "name" and "city" columns from a table
```

### `keys` and `values`

```bash
echo '{"b": 2, "a": 1, "c": 3}' | jq 'keys'
# ["a", "b", "c"]  — sorted!

echo '{"b": 2, "a": 1, "c": 3}' | jq 'keys_unsorted'
# ["b", "a", "c"]  — insertion order

echo '{"b": 2, "a": 1, "c": 3}' | jq '[values]'
# [2, 1, 3]
# Python: sorted(d.keys()); list(d.keys()); list(d.values())
# Excel:  column headers (sorted A-Z); column headers as-is; the data column
```

### `has` and `in`

```bash
echo '{"name": "Alice"}' | jq 'has("name")'
# true

echo '{"name": "Alice"}' | jq 'has("age")'
# false

echo '["a", "b", "c"]' | jq 'has(1)'
# true (index 1 exists)

echo '"name"' | jq 'in({"name": "Alice", "age": 30})'
# true
# Python: "name" in d; "age" in d; 1 < len(xs)
# Excel:  =NOT(ISNA(MATCH("name", header_row, 0)))
```

### `to_entries`, `from_entries`, `with_entries`

Convert between objects and key-value pair arrays:

```bash
echo '{"a": 1, "b": 2}' | jq 'to_entries'
# [{"key":"a","value":1},{"key":"b","value":2}]

echo '[{"key":"a","value":1},{"key":"b","value":2}]' | jq 'from_entries'
# {"a":1,"b":2}

echo '[{"name":"x","value":1},{"name":"y","value":2}]' | jq 'from_entries'
# {"x":1,"y":2}  — also works with "name"/"value" keys
# Python: [{"key":k,"value":v} for k,v in d.items()]; dict((e["key"],e["value"]) for e in xs)
# Excel:  unpivot a row into key/value pairs (Power Query > Unpivot); reverse with pivot
```

`with_entries(f)` is a shortcut for `to_entries | map(f) | from_entries`:

```bash
# Filter by value
echo '{"a":1,"b":null,"c":3,"d":null}' | jq 'with_entries(select(.value != null))'
# {"a":1,"c":3}

# Transform keys
echo '{"old_name":"Alice","old_age":30}' | jq 'with_entries(.key |= ltrimstr("old_"))'
# {"name":"Alice","age":30}

# Transform values
echo '{"a":"hello","b":"world"}' | jq 'with_entries(.value |= ascii_upcase)'
# {"a":"HELLO","b":"WORLD"}

# Add prefix to keys
echo '{"host":"localhost","port":5432}' | jq 'with_entries(.key = "db_" + .key)'
# {"db_host":"localhost","db_port":5432}
# Python: {k:v for k,v in d.items() if v is not None}; {k.removeprefix("old_"):v for k,v in d.items()}
# Excel:  filter rows where value != blank; Find & Replace on column headers
```

> **Familiar?** Like Python's `{f(k): g(v) for k, v in d.items()}`, or
> renaming/transforming column headers and values in an Excel table.

### `del` — Remove Fields or Elements

```bash
echo '{"a":1,"b":2,"c":3}' | jq 'del(.b)'
# {"a":1,"c":3}

echo '{"a":1,"b":2,"c":3}' | jq 'del(.a, .c)'
# {"b":2}

echo '[1, 2, 3, 4, 5]' | jq 'del(.[2])'
# [1, 2, 4, 5]
# Python: {k:v for k,v in d.items() if k != "b"}; xs[:2] + xs[3:]
# Excel:  delete a column; delete a row from the table
```

### `map_values(f)` — Transform Object Values

Like `map` but for objects — applies `f` to each value, keeping keys:

```bash
echo '{"a": 1, "b": 2, "c": 3}' | jq 'map_values(. * 10)'
# {"a":10,"b":20,"c":30}
# Python: {k: v*10 for k, v in d.items()}
# Excel:  apply a formula to every cell in a data row/column
```

### `pick` — Select Specific Paths

```bash
echo '{"name":"Alice","age":30,"address":{"city":"Tokyo","zip":"100"}}' \
  | jq 'pick(.name, .address.city)'
# {"name":"Alice","address":{"city":"Tokyo"}}
# Python: {"name": d["name"], "address": {"city": d["address"]["city"]}}
# Excel:  no direct equivalent (select specific columns, but nested structure not supported)
```

## Exercises

1. Given `[5,3,8,1,9,2]`, sort descending and take the top 3.
2. Given `[{"name":"A","score":80},{"name":"B","score":95},{"name":"C","score":80}]`,
   group by score and format as `{score: [names]}`.
3. Given `{"x":1,"y":null,"z":3,"w":null}`, remove all null values.
4. Given `[1,2,3,4,5,6,7,8,9,10]`, get only even numbers greater than 4.
5. Construct `[["a",1],["b",2],["c",3]]` from `{"a":1,"b":2,"c":3}`.

<details>
<summary>Solutions</summary>

```bash
# 1
echo '[5,3,8,1,9,2]' | jq 'sort | reverse | .[:3]'
# [9,8,5]
# Python: sorted(xs, reverse=True)[:3]
# Excel:  =LARGE(range, {1,2,3}) or =SORT(range,,-1) then take top 3

# 2
echo '[{"name":"A","score":80},{"name":"B","score":95},{"name":"C","score":80}]' \
  | jq 'group_by(.score) | map({(.[0].score | tostring): map(.name)}) | add'
# {"80":["A","C"],"95":["B"]}
# Python: {k: [d["name"] for d in g] for k, g in itertools.groupby(sorted(xs, key=lambda d: d["score"]), key=lambda d: d["score"])}
# Excel:  pivot table with score as row, names concatenated per group

# 3
echo '{"x":1,"y":null,"z":3,"w":null}' | jq 'with_entries(select(.value != null))'
# {"x":1,"z":3}
# Python: {k: v for k, v in d.items() if v is not None}
# Excel:  filter out blank cells in a column

# 4
echo '[1,2,3,4,5,6,7,8,9,10]' | jq 'map(select(. > 4 and . % 2 == 0))'
# [6,8,10]
# Python: [x for x in xs if x > 4 and x % 2 == 0]
# Excel:  =FILTER(range, (range>4) * (MOD(range,2)=0))

# 5
echo '{"a":1,"b":2,"c":3}' | jq 'to_entries | map([.key, .value])'
# [["a",1],["b",2],["c",3]]
# Python: list(d.items())  # returns list of tuples
# Excel:  a two-column table with headers and values side by side
```

</details>
