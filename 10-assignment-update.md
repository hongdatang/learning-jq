# Tutorial 10 — Assignment and Update Operators

jq values are immutable — all "assignments" produce a new copy with the change applied.
But the syntax makes it feel like mutation.

## Plain Assignment: `=`

Sets a value at a path:

```bash
echo '{"a": 1, "b": 2}' | jq '.c = 3'
# {"a":1,"b":2,"c":3}

echo '{"a": 1, "b": 2}' | jq '.a = 99'
# {"a":99,"b":2}

echo '{"user": {"name": "Alice"}}' | jq '.user.age = 30'
# {"user":{"name":"Alice","age":30}}
# Python: d["c"] = 3; d["a"] = 99; d["user"]["age"] = 30
# Excel:  type a value into a cell (direct assignment)
```

### `=` Evaluates the Right Side Once

The right-hand side of `=` is evaluated against the **original input**, not the
value at the path:

```bash
echo '{"a": 1, "b": 2}' | jq '.a = .b'
# {"a":2,"b":2}  — .b is evaluated against the root object

echo '{"a": [1,2,3]}' | jq '.a = (.a | length)'
# {"a":3}
# Python: d["a"] = d["b"]; d["a"] = len(d["a"])
# Excel:  =B1 (reference another cell's value)
```

## Update Operator: `|=`

`|=` applies a filter to the current value at the path. The `.` inside the filter
refers to the **value at the path**, not the root:

```bash
echo '{"a": 5}' | jq '.a |= . * 2'
# {"a":10}  — . inside |= is 5 (the value of .a)

echo '{"items": [1, 2, 3]}' | jq '.items |= map(. * 10)'
# {"items":[10,20,30]}

echo '{"name": "alice"}' | jq '.name |= ascii_upcase'
# {"name":"ALICE"}
# Python: d["a"] *= 2; d["items"] = [x*10 for x in d["items"]]; d["name"] = d["name"].upper()
# Excel:  =A1*2 (formula referencing the current value)
```

### The Difference Between `=` and `|=`

```bash
echo '{"a": 5, "b": 10}' | jq '.a = . + 1'
# error — . is the whole object {"a":5,"b":10}, can't add 1 to it

echo '{"a": 5, "b": 10}' | jq '.a |= . + 1'
# {"a":6,"b":10}  — . is 5 (value at .a), so 5 + 1 = 6
# Python: d["a"] += 1 (Python's += transforms in place like |=)
# Excel:  =A1+1 (formula references the value at that cell)
```

Rule of thumb:
- Use `=` when the new value is independent of the old value
- Use `|=` when you're transforming the existing value

## Arithmetic Update Operators

Shorthand for common `|=` patterns:

```bash
echo '{"count": 5}' | jq '.count += 10'
# {"count":15}  — equivalent to .count |= . + 10

echo '{"count": 5}' | jq '.count -= 2'
# {"count":3}

echo '{"count": 5}' | jq '.count *= 3'
# {"count":15}

echo '{"count": 10}' | jq '.count /= 2'
# {"count":5}

echo '{"count": 10}' | jq '.count %= 3'
# {"count":1}
# Python: d["count"] += 10; d["count"] -= 2; d["count"] *= 3; etc.
# Excel:  no augmented assignment; use =A1+10 in another cell or VBA
```

## Alternative Assignment: `//=`

Sets the value only if it's currently `null` or `false`:

```bash
echo '{"a": 1}' | jq '.b //= 42'
# {"a":1,"b":42}  — .b was null

echo '{"a": 1, "b": 10}' | jq '.b //= 42'
# {"a":1,"b":10}  — .b already had a value, unchanged
# Python: d["b"] = d.get("b") if d.get("b") not in (None, False) else 42  (//= triggers on null and false only)
# Excel:  =IF(ISBLANK(B1), 42, B1)
```

Useful for setting defaults:

```bash
echo '{"host": "example.com"}' | jq '.port //= 8080 | .protocol //= "https"'
# {"host":"example.com","port":8080,"protocol":"https"}
# Python: defaults = {"port": 8080, "protocol": "https"}; d = {**defaults, **d}
# Excel:  =IF(ISBLANK(A1), default, A1) per field
```

## Updating Array Elements

### Update a Specific Index

```bash
echo '[10, 20, 30]' | jq '.[1] = 99'
# [10, 99, 30]

echo '[10, 20, 30]' | jq '.[1] |= . * 100'
# [10, 2000, 30]
# Python: lst[1] = 99; lst[1] *= 100
# Excel:  directly edit cell B1 (second element in a row)
```

### Update All Elements with `.[]`

```bash
echo '[1, 2, 3]' | jq '.[] |= . * 10'
# [10, 20, 30]

echo '[{"active": true}, {"active": false}]' | jq '.[].active = true'
# [{"active":true},{"active":true}]
# Python: lst = [x * 10 for x in lst]; for item in lst: item["active"] = True
# Excel:  fill-down formula =A1*10; or paste TRUE into a column
```

### Update Matching Elements

```bash
echo '[1, 2, 3, 4, 5]' | jq 'map(if . > 3 then . * 10 else . end)'
# [1, 2, 3, 40, 50]

echo '[{"name":"Alice","score":80},{"name":"Bob","score":95}]' | jq '
  map(if .score >= 90 then .grade = "A" else .grade = "B" end)'
# [{"name":"Alice","score":80,"grade":"B"},{"name":"Bob","score":95,"grade":"A"}]
# Python: [x*10 if x > 3 else x for x in lst]; conditional dict update in list comp
# Excel:  =IF(A1>3, A1*10, A1) dragged down a column
```

### Add Elements

```bash
echo '[1, 2, 3]' | jq '. += [4, 5]'
# [1, 2, 3, 4, 5]

echo '[1, 2, 3]' | jq '. + [0] | sort'
# [0, 1, 2, 3]
# Python: lst.extend([4, 5]) or lst + [4, 5]; sorted(lst + [0])
# Excel:  paste new values below existing data; sort column
```

## Updating Nested Structures

### Chain Path Expressions

```bash
echo '{"user": {"address": {"city": "Tokyo"}}}' | jq '.user.address.city = "Berlin"'
# {"user":{"address":{"city":"Berlin"}}}

echo '{"user": {"address": {"city": "Tokyo"}}}' | jq '.user.address.city |= ascii_upcase'
# {"user":{"address":{"city":"TOKYO"}}}
# Python: d["user"]["address"]["city"] = "Berlin"; or .upper() for transform
# Excel:  directly edit the cell; =UPPER(C2) for transform
```

### Multiple Updates

Pipe multiple assignments:

```bash
echo '{"name": "alice", "age": 25}' | jq '
  .name |= ascii_upcase |
  .age += 1 |
  .status = "active"'
# {"name":"ALICE","age":26,"status":"active"}
# Python: d["name"] = d["name"].upper(); d["age"] += 1; d["status"] = "active"
# Excel:  multiple cell edits / formulas applied to different columns
```

### Conditional Update

```bash
echo '[
  {"name": "Alice", "score": 85},
  {"name": "Bob", "score": 92},
  {"name": "Carol", "score": 78}
]' | jq 'map(
  if .score >= 90 then .grade = "A"
  elif .score >= 80 then .grade = "B"
  else .grade = "C" end)'
# Python: for r in rows: r["grade"] = "A" if r["score"]>=90 else "B" if r["score"]>=80 else "C"
# Excel:  =IFS(B2>=90,"A", B2>=80,"B", TRUE,"C")
```

## `del` — Delete Fields or Elements

```bash
echo '{"a": 1, "b": 2, "c": 3}' | jq 'del(.b)'
# {"a":1,"c":3}

echo '{"a": 1, "b": 2, "c": 3}' | jq 'del(.a, .c)'
# {"b":2}

echo '[1, 2, 3, 4, 5]' | jq 'del(.[2])'
# [1, 2, 4, 5]

# Delete elements matching a condition
echo '[1, 2, 3, 4, 5]' | jq 'del(.[] | select(. % 2 == 0))'
# [1, 3, 5]
# Python: del d["b"]; del lst[2]; [x for x in lst if x % 2 != 0]
# Excel:  delete row/column; or FILTER() to exclude values
```

## `+= [{...}]` Pattern for Appending to Arrays

```bash
echo '{"items": [{"id": 1}]}' | jq '.items += [{"id": 2}, {"id": 3}]'
# {"items":[{"id":1},{"id":2},{"id":3}]}
# Python: d["items"].extend([{"id": 2}, {"id": 3}])
# Excel:  append rows below existing table
```

## How `|=` Works Internally

Under the hood, `.path |= f` is roughly:

```
.path as $old | setpath(path(.path); $old | f)
```

This means `|=` works with any valid path expression:

```bash
# Update values at dynamic paths
echo '{"a": 1, "b": 2, "c": 3}' | jq '.["a","c"] |= . * 10'
# {"a":10,"b":2,"c":30}

# Update all array elements > 3
echo '[1, 2, 3, 4, 5]' | jq '(.[] | select(. > 3)) |= . * 100'
# [1, 2, 3, 400, 500]
# Python: for k in ["a","c"]: d[k] *= 10; lst = [x*100 if x>3 else x for x in lst]
# Excel:  =IF(A1>3, A1*100, A1) dragged down
```

## Practical Patterns

### Batch Update From a Map

```bash
echo '{"a": 1, "b": 2, "c": 3}' | jq --argjson updates '{"a": 10, "c": 30}' '
  . + $updates'
# {"a":10,"b":2,"c":30}
# Python: d.update({"a": 10, "c": 30}) or {**d, **updates}
# Excel:  no direct equivalent (paste special -> values over existing cells)
```

### Toggle a Boolean

```bash
echo '{"enabled": true}' | jq '.enabled |= not'
# {"enabled":false}
# Python: d["enabled"] = not d["enabled"]
# Excel:  =NOT(A1)
```

### Increment All Values in a Nested Counter

```bash
echo '{"counters": {"errors": 5, "warnings": 10}}' | jq '.counters |= map_values(. + 1)'
# {"counters":{"errors":6,"warnings":11}}
# Python: d["counters"] = {k: v+1 for k, v in d["counters"].items()}
# Excel:  =B1+1 formula applied across a row of counters
```

### Add a Timestamp to Every Object in an Array

```bash
echo '[{"id":1},{"id":2}]' | jq --arg ts "2024-01-15" '
  map(. + {created_at: $ts})'
# [{"id":1,"created_at":"2024-01-15"},{"id":2,"created_at":"2024-01-15"}]
# Python: for item in lst: item["created_at"] = "2024-01-15"
# Excel:  fill a "created_at" column with the same date value
```

## Exercises

1. Given `{"x":1,"y":2,"z":3}`, double only `x` and `z` using `|=`.
2. Given `[{"name":"a","done":false},{"name":"b","done":false}]`, set `done` to
   `true` for the item named `"b"`.
3. Given `{"config":{"debug":false,"port":3000}}`, set `debug` to `true` and
   add `host: "0.0.0.0"`.
4. Given `[1,2,3,4,5,6]`, replace all even numbers with `0` using `|=` and `select`.
5. Given `{"a":1,"b":null,"c":3}`, use `//=` to set `b` to a default of `99` without
   changing `a` or `c`.

<details>
<summary>Solutions</summary>

```bash
# 1
echo '{"x":1,"y":2,"z":3}' | jq '.x |= . * 2 | .z |= . * 2'
# {"x":2,"y":2,"z":6}
# or: .["x","z"] |= . * 2
# Python: for k in ["x","z"]: d[k] *= 2
# Excel:  =A1*2 applied to specific cells

# 2
echo '[{"name":"a","done":false},{"name":"b","done":false}]' | jq '
  map(if .name == "b" then .done = true else . end)'
# [{"name":"a","done":false},{"name":"b","done":true}]
# Python: next(r for r in lst if r["name"]=="b")["done"] = True
# Excel:  =IF(A2="b", TRUE, B2) in a helper column

# 3
echo '{"config":{"debug":false,"port":3000}}' | jq '
  .config.debug = true | .config.host = "0.0.0.0"'
# {"config":{"debug":true,"port":3000,"host":"0.0.0.0"}}
# Python: d["config"]["debug"] = True; d["config"]["host"] = "0.0.0.0"
# Excel:  edit cells directly

# 4
echo '[1,2,3,4,5,6]' | jq '(.[] | select(. % 2 == 0)) |= 0'
# [1,0,3,0,5,0]
# Python: [0 if x % 2 == 0 else x for x in lst]
# Excel:  =IF(MOD(A1,2)=0, 0, A1)

# 5
echo '{"a":1,"b":null,"c":3}' | jq '.a //= 99 | .b //= 99 | .c //= 99'
# {"a":1,"b":99,"c":3}
# Python: for k in d: d[k] = d[k] if d[k] is not None else 99
# Excel:  =IF(ISBLANK(A1), 99, A1)
```

</details>
