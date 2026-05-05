# Tutorial 09 — Path Operations

Path operations let you treat JSON paths as data — you can inspect, manipulate, and
reconstruct paths programmatically. This is jq's reflection/metaprogramming system.

## What Is a Path?

A path is an array of strings (object keys) and integers (array indices) that locates
a value within a JSON structure:

```
{"a": {"b": [10, 20, 30]}}

Path to 20: ["a", "b", 1]
```

## `path(expr)` — Get the Path to a Value

```bash
echo '{"a": {"b": {"c": 42}}}' | jq 'path(.a.b.c)'
# ["a","b","c"]

echo '{"users": [{"name": "Alice"}]}' | jq 'path(.users[0].name)'
# ["users",0,"name"]
# Python: no built-in; manually construct ["a","b","c"] or use jsonpath_ng
# Excel:  no direct equivalent
```

## `paths` — All Paths in a Document

`paths` generates all paths (to both intermediate and leaf nodes):

```bash
echo '{"a": 1, "b": {"c": 2}}' | jq '[paths]'
# [["a"],["b"],["b","c"]]
# Python: recursive function collecting keys, e.g. list all keys via DFS traversal
# Excel:  no direct equivalent
```

### `paths(filter)` — Paths Where Filter Is True

```bash
# Paths to all numbers
echo '{"a": 1, "b": "hi", "c": {"d": 2}}' | jq '[paths(type == "number")]'
# [["a"],["c","d"]]

# Paths to all strings
echo '{"a": "x", "b": [1, "y"]}' | jq '[paths(type == "string")]'
# [["a"],["b",1]]

# Paths to values matching a condition
echo '{"a": 1, "b": 50, "c": {"d": 100}}' | jq '[paths(numbers > 10)]'
# [["b"],["c","d"]]
# Python: recursive walk collecting paths where isinstance(v, int/float) or v > 10
# Excel:  no direct equivalent
```

### `paths(scalars)` — Paths to Leaf Values Only

Excludes intermediate arrays and objects:

```bash
echo '{"a": 1, "b": {"c": 2, "d": [3, 4]}}' | jq '[paths(scalars)]'
# [["a"],["b","c"],["b","d",0],["b","d",1]]
# Python: recursive walk yielding path only when value is not dict/list
# Excel:  no direct equivalent
```

## `getpath(path)` — Retrieve Value at a Path

```bash
echo '{"a": {"b": {"c": 42}}}' | jq 'getpath(["a", "b", "c"])'
# 42

echo '{"users": [{"name": "Alice"}, {"name": "Bob"}]}' | jq 'getpath(["users", 1, "name"])'
# "Bob"

echo '{"a": 1}' | jq 'getpath(["x", "y"])'
# null  — path doesn't exist
# Python: functools.reduce(lambda d,k: d[k], ["a","b","c"], data)
# Excel:  =INDEX(table, row, col) or nested INDIRECT references
```

## `setpath(path; value)` — Set Value at a Path

Returns a new structure with the value set (doesn't mutate):

```bash
echo '{"a": {"b": 1}}' | jq 'setpath(["a", "c"]; 99)'
# {"a":{"b":1,"c":99}}

echo '{"a": {"b": 1}}' | jq 'setpath(["a", "b"]; "replaced")'
# {"a":{"b":"replaced"}}

# Creates intermediate structure if needed
echo '{}' | jq 'setpath(["a", "b", "c"]; 42)'
# {"a":{"b":{"c":42}}}
# Python: d["a"]["c"] = 99 (mutation); for immutable, use copy.deepcopy + assignment
# Excel:  no direct equivalent (cells are mutable by default)
```

## `delpaths(paths)` — Delete Multiple Paths

Takes an array of paths and removes them all:

```bash
echo '{"a": 1, "b": 2, "c": 3}' | jq 'delpaths([["a"], ["c"]])'
# {"b":2}

echo '{"x": [1, 2, 3, 4]}' | jq 'delpaths([["x", 1], ["x", 3]])'
# {"x":[1,3]}  — removes values at original indices 1 and 3 (delpaths handles ordering internally)
# Python: for k in ["a","c"]: del d[k]  (or dict comprehension to keep immutable)
# Excel:  no direct equivalent
```

## Combining Paths with `getpath`/`setpath`

### Flatten Nested JSON to Dot-Notation

```bash
echo '{"a": {"b": 1}, "c": [2, 3]}' | jq '
  [paths(scalars) as $p | {key: ($p | map(tostring) | join(".")), value: getpath($p)}]'
# [{"key":"a.b","value":1},{"key":"c.0","value":2},{"key":"c.1","value":3}]
# Python: pd.json_normalize(d, sep=".") or recursive flatten function
# Excel:  no direct equivalent (Power Query can flatten nested JSON)
```

### Copy a Value from One Path to Another

```bash
echo '{"source": {"data": 42}, "target": {}}' | jq '
  getpath(["source", "data"]) as $val |
  setpath(["target", "result"]; $val)'
# {"source":{"data":42},"target":{"result":42}}
# Python: d["target"]["result"] = d["source"]["data"]
# Excel:  =A2 (copy cell reference from source to target)
```

### Find and Replace at Arbitrary Depth

```bash
echo '{"a": {"x": "old"}, "b": [{"x": "old"}, {"x": "keep"}]}' | jq '
  reduce (paths(. == "old")) as $p (.; setpath($p; "new"))'
# {"a":{"x":"new"},"b":[{"x":"new"},{"x":"keep"}]}
# Python: recursive walk replacing all occurrences of "old" with "new"
# Excel:  Ctrl+H (Find & Replace) across a sheet
```

## Recursive Descent: `..`

`..` is defined as `recurse(.[]?)` — it produces the value itself plus every nested
value at all depths:

```bash
echo '{"a": [1, {"b": 2}], "c": 3}' | jq '[.. | numbers]'
# [1, 2, 3]

echo '{"a": {"b": "hello"}, "c": ["world"]}' | jq '[.. | strings]'
# ["hello", "world"]
# Python: [v for v in recursive_values(d) if isinstance(v, (int, float))]
# Excel:  no direct equivalent
```

### Search for a Key Anywhere

```bash
echo '{"level1": {"level2": {"target": "found it!"}}}' | jq '.. | .target? // empty'
# "found it!"

echo '{"a": {"id": 1}, "b": {"c": {"id": 2}}}' | jq '[.. | objects | select(has("id")) | .id]'
# [1, 2]
# Python: [v["id"] for v in recursive_objects(d) if "id" in v]
# Excel:  no direct equivalent
```

### Find All Keys in a Nested Structure

```bash
echo '{"a": {"b": 1, "c": {"d": 2}}}' | jq '[.. | objects | keys[]] | unique'
# ["a","b","c","d"]
# Python: set of all keys gathered via recursive walk over dicts
# Excel:  no direct equivalent
```

## `walk(f)` — Bottom-Up Transformation

`walk(f)` applies `f` to every value, starting from the deepest leaves and working up:

```bash
# Add a field to every object at any depth
echo '{"a": {"x": 1}, "b": [{"y": 2}]}' | jq '
  walk(if type == "object" then . + {"_touched": true} else . end)'
# {"a":{"x":1,"_touched":true},"b":[{"y":2,"_touched":true}],"_touched":true}

# Round all numbers
echo '{"price": 19.99, "items": [{"cost": 3.14159}]}' | jq '
  walk(if type == "number" then (. * 100 | round) / 100 else . end)'
# {"price":19.99,"items":[{"cost":3.14}]}

# Sort all object keys recursively
echo '{"b":1,"a":{"d":2,"c":3}}' | jq 'walk(if type == "object" then to_entries | sort_by(.key) | from_entries else . end)'
# {"a":{"c":3,"d":2},"b":1}
# Python: recursive function applying transform bottom-up; e.g. round() for numbers
# Excel:  no direct equivalent (=ROUND(A1,2) for individual cells)
```

## `env` and `$ENV` — Environment Variables

```bash
jq -n 'env.HOME'
# "/Users/yourusername"

jq -n '$ENV.PATH | split(":") | length'
# number of PATH entries

jq -n '$ENV | keys[:5]'
# first 5 environment variable names
# Python: os.environ["HOME"], os.environ["PATH"].split(":")
# Excel:  =INFO("directory") for limited system info; no general env access
```

## Practical Patterns

### Deep Diff — Find Differences Between Two Objects

```bash
jq -n --argjson a '{"x":1,"y":{"z":2},"w":3}' --argjson b '{"x":1,"y":{"z":99},"w":3}' '
  [$a | paths(scalars)] as $paths |
  [$paths[] | select($a | getpath(.) as $av | $b | getpath(.) as $bv | $av != $bv) |
    {path: (map(tostring) | join(".")), old: ($a | getpath(.) ), new: ($b | getpath(.))}
  ]'
# [{"path":"y.z","old":2,"new":99}]
# Python: deepdiff.DeepDiff(a, b) from the deepdiff library
# Excel:  no direct equivalent (manual cell-by-cell comparison or conditional formatting)
```

### Rename Keys at Any Depth

```bash
echo '{"old_name": "Alice", "data": {"old_name": "Bob"}}' | jq '
  walk(if type == "object" and has("old_name") then
    .name = .old_name | del(.old_name)
  else . end)'
# {"name":"Alice","data":{"name":"Bob"}}
# Python: recursive walk: d["name"] = d.pop("old_name") for each dict with "old_name"
# Excel:  rename column header manually; no recursive rename
```

### Extract Schema (Types at Each Path)

```bash
echo '{"name":"Alice","age":30,"tags":["a","b"],"address":{"city":"NYC"}}' | jq '
  [paths(scalars) as $p | {path: ($p | join(".")), type: (getpath($p) | type)}]'
# [{"path":"name","type":"string"},{"path":"age","type":"number"},
#  {"path":"tags.0","type":"string"},{"path":"tags.1","type":"string"},
#  {"path":"address.city","type":"string"}]
# Python: recursive walk building {".".join(path): type(value).__name__}
# Excel:  no direct equivalent
```

### Selectively Update Deep Values

```bash
echo '{"config":{"db":{"host":"old","port":5432},"cache":{"host":"old","ttl":300}}}' | jq '
  reduce (paths(. == "old")) as $p (.; setpath($p; "new-host.example.com"))'
# all "old" values replaced at any depth
# Python: recursive walk replacing v == "old" with "new-host.example.com"
# Excel:  Ctrl+H (Find & Replace) for "old" -> "new-host.example.com"
```

## Exercises

1. Given `{"a":{"b":1},"c":{"d":{"e":2}}}`, list all leaf paths as dot-notation strings.
2. Given a nested object, find all paths where the value is `null` and remove them.
3. Use `walk` to convert all string values to uppercase throughout a nested structure.
4. Given `{"x": {"target": 42}, "y": [{"target": 99}]}`, find all values of "target"
   keys at any depth.
5. Implement "unflatten": convert `{"a.b": 1, "a.c": 2, "d": 3}` back to
   `{"a": {"b": 1, "c": 2}, "d": 3}` using `setpath`.

<details>
<summary>Solutions</summary>

```bash
# 1
echo '{"a":{"b":1},"c":{"d":{"e":2}}}' | jq '[paths(scalars) | map(tostring) | join(".")]'
# ["a.b","c.d.e"]
# Python: [".".join(str(k) for k in path) for path in leaf_paths(d)]
# Excel:  no direct equivalent

# 2
echo '{"a":1,"b":null,"c":{"d":null,"e":2}}' | jq '
  delpaths([paths(. == null)])'
# {"a":1,"c":{"e":2}}
# Python: recursive dict comprehension filtering out None values
# Excel:  no direct equivalent

# 3
echo '{"a":"hello","b":[1,"world",{"c":"foo"}]}' | jq '
  walk(if type == "string" then ascii_upcase else . end)'
# {"a":"HELLO","b":[1,"WORLD",{"c":"FOO"}]}
# Python: recursive walk applying str.upper() to all string values
# Excel:  =UPPER(A1) per cell

# 4
echo '{"x":{"target":42},"y":[{"target":99}]}' | jq '[.. | objects | .target? // empty]'
# [42,99]
# Python: [obj["target"] for obj in recursive_objects(d) if "target" in obj]
# Excel:  no direct equivalent

# 5
echo '{"a.b":1,"a.c":2,"d":3}' | jq '
  to_entries | reduce .[] as $e ({};
    setpath($e.key | split("."); $e.value))'
# {"a":{"b":1,"c":2},"d":3}
# Python: functools.reduce over split keys, building nested dicts
# Excel:  no direct equivalent
```

</details>
