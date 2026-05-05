# Tutorial 11 — Advanced Patterns

## Format Strings

Format strings encode values into specific text formats:

### `@base64` / `@base64d`

```bash
echo '"Hello, World!"' | jq '@base64'
# "SGVsbG8sIFdvcmxkIQ=="

echo '"SGVsbG8sIFdvcmxkIQ=="' | jq '@base64d'
# "Hello, World!"
# Python: import base64; base64.b64encode(s.encode()).decode(); base64.b64decode(s).decode()
# Excel:  no direct equivalent (VBA or Power Query required)
```

### `@uri` / `@urid`

```bash
echo '"hello world&foo=bar"' | jq '@uri'
# "hello%20world%26foo%3Dbar"

echo '"hello%20world"' | jq '@urid'
# "hello world"
# Python: urllib.parse.quote(s); urllib.parse.unquote(s)
# Excel:  =ENCODEURL(A1) (encode only; no built-in decode)
```

`@urid` is new in jq 1.8 — reverse of `@uri`.

### `@html`

```bash
echo '"<script>alert(1)</script>"' | jq '@html'
# "&lt;script&gt;alert(1)&lt;/script&gt;"
# Python: import html; html.escape(s)
# Excel:  no direct equivalent
```

### `@csv` / `@tsv`

```bash
echo '["Alice", 30, "Tokyo"]' | jq '@csv'
# "\"Alice\",30,\"Tokyo\""

echo '["Alice", 30, "Tokyo"]' | jq '@tsv'
# "Alice\t30\tTokyo"
# Python: import csv; writer.writerow(["Alice", 30, "Tokyo"])
# Excel:  native format — just paste or "Save As CSV"
```

### `@json`

```bash
echo '{"a": 1}' | jq '@json'
# "{\"a\":1}"  — serializes to a JSON string
# Python: import json; json.dumps({"a": 1})
# Excel:  no direct equivalent
```

### `@sh` — Shell Escaping

```bash
echo '"hello world; rm -rf /"' | jq '@sh'
# "'hello world; rm -rf /'"
# Python: shlex.quote("hello world; rm -rf /")
# Excel:  no direct equivalent
```

### Format Strings with Interpolation

When used with interpolation, only the interpolated parts get formatted:

```bash
echo '{"q": "hello world", "page": 2}' | jq '@uri "https://api.example.com/search?q=\(.q)&page=\(.page)"'
# "https://api.example.com/search?q=hello%20world&page=2"

echo '{"name": "<b>Alice</b>"}' | jq '@html "<p>Hello, \(.name)</p>"'
# "<p>Hello, &lt;b&gt;Alice&lt;/b&gt;</p>"
# Python: f"https://...?q={urllib.parse.quote(q)}&page={page}"
# Excel:  ="https://...?q=" & ENCODEURL(A1) & "&page=" & B1
```

## SQL-Style Operators

### `INDEX(stream; expr)` — Build a Lookup Map

Creates an object keyed by the result of `expr` for each element:

```bash
echo '[{"id": "a", "val": 1}, {"id": "b", "val": 2}, {"id": "c", "val": 3}]' | jq '
  INDEX(.[]; .id)'
# {"a":{"id":"a","val":1},"b":{"id":"b","val":2},"c":{"id":"c","val":3}}
# Python: {x["id"]: x for x in lst}
# Excel:  XLOOKUP or VLOOKUP table (build a lookup range keyed by one column)
```

> **Familiar?** Like Python's `{x["id"]: x for x in xs}`, or Excel's `XLOOKUP()`
> / `VLOOKUP()` table — you build a lookup keyed by one column.

### `IN(stream)` — Membership Test

```bash
echo '["apple", "banana", "cherry"]' | jq '[.[] | select(IN("apple", "cherry"))]'
# ["apple","cherry"]

echo '"banana"' | jq 'IN("apple", "banana", "cherry")'
# true
# Python: [x for x in lst if x in {"apple", "cherry"}]; "banana" in s
# Excel:  =ISNUMBER(MATCH(A1, allowed_list, 0)) or FILTER with MATCH
```

### Joins with `INDEX`

Simulate SQL JOINs by building an index then looking up:

```bash
echo '{
  "users": [{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}],
  "orders": [{"user_id":1,"product":"Widget"},{"user_id":2,"product":"Gadget"},{"user_id":1,"product":"Doohickey"}]
}' | jq '
  INDEX(.users[]; .id) as $users |
  [.orders[] | . + {user_name: $users[(.user_id | tostring)].name}]'
# [{"user_id":1,"product":"Widget","user_name":"Alice"},
#  {"user_id":2,"product":"Gadget","user_name":"Bob"},
#  {"user_id":1,"product":"Doohickey","user_name":"Alice"}]
# Python: lookup = {u["id"]: u for u in users}; [{**o, "user_name": lookup[o["user_id"]]["name"]} for o in orders]
# Excel:  =VLOOKUP(user_id, users_table, 2, FALSE) or XLOOKUP
```

## Streaming

Streaming processes JSON as a sequence of `[path, value]` events, enabling processing
of data larger than available memory.

### `tostream` — Convert to Stream

```bash
echo '{"a": 1, "b": [2, 3]}' | jq '[tostream]'
# [
#   [["a"],1],
#   [["b",0],2],
#   [["b",1],3],
#   [["b",1]],    ← truncated path = end marker for array .b
#   [["b"]]       ← end marker
# ]
# Python: no built-in; similar to ijson library's prefix/value event pairs
# Excel:  no direct equivalent
```

Stream events come in two forms:
- `[path, value]` — a leaf value at the given path
- `[path]` — end of a container at the given path (a "truncated" event)

### `fromstream(stream_expr)` — Reconstruct from Stream

```bash
echo '{"a": 1, "b": [2, 3]}' | jq 'fromstream(tostream)'
# {"a":1,"b":[2,3]}  — round-trips perfectly
# Python: reconstruct dict from (path, value) pairs using setpath logic
# Excel:  no direct equivalent
```

### `truncate_stream(stream_expr)` — Remove Leading Path Elements

```bash
echo '{"a": {"x": 1, "y": 2}}' | jq 'fromstream(1 | truncate_stream(tostream))'
# {"x":1,"y":2}  — stripped the leading "a" from all paths
# Python: d["a"] (just access the nested value directly)
# Excel:  no direct equivalent
```

### Command-Line Streaming: `--stream`

For large files, use `--stream` flag to process without loading into memory:

```bash
# Process a huge JSON file with an array of millions of objects:
# jq --stream 'select(.[0][0] == "items" and length == 2) | .[1]' huge.json
# This extracts each element of .items without loading the whole array

# Filter stream events
echo '{"users": [{"name": "Alice"}, {"name": "Bob"}]}' | jq --stream '
  select(.[0][:1] == ["users"] and .[0][-1] == "name" and length == 2) | .[1]'
# "Alice"
# "Bob"
# Python: ijson.items(file, "items.item") for streaming large JSON
# Excel:  no direct equivalent (Power Query can handle large files incrementally)
```

## Multi-Input Processing

### `input` and `inputs`

Read additional JSON values from stdin:

```bash
echo -e '{"a":1}\n{"b":2}\n{"c":3}' | jq -n '[inputs]'
# [{"a":1},{"b":2},{"c":3}]

# Sum values from multiple JSON objects
echo -e '{"val":10}\n{"val":20}\n{"val":30}' | jq -n '[inputs.val] | add'
# 60
# Python: [json.loads(line) for line in f]; sum(obj["val"] for obj in objs)
# Excel:  import data line by line; =SUM(column)
```

### `input_line_number`

```bash
echo -e '{"a":1}\n{"b":2}' | jq '{line: input_line_number, data: .}'
# {"line":1,"data":{"a":1}}
# {"line":2,"data":{"b":2}}
# Python: for i, line in enumerate(f, 1): {"line": i, "data": json.loads(line)}
# Excel:  =ROW() gives the row number alongside data
```

## Debugging

### `debug`

Prints to stderr without changing the pipeline:

```bash
echo '5' | jq '. | debug | . * 2'
# stderr: ["DEBUG:",5]
# stdout: 10
# Python: print(x, file=sys.stderr); result = x * 2
# Excel:  no direct equivalent (use Watch Window or Evaluate Formula)
```

### `debug(msg)`

Custom debug message:

```bash
echo '[1, 2, 3]' | jq 'map(debug("before") | . * 2 | debug("after"))'
# stderr shows values at each step
# stdout: [2, 4, 6]
# Python: logging.debug(f"before: {x}"); result = x*2; logging.debug(f"after: {result}")
# Excel:  no direct equivalent
```

### `stderr`

Outputs the current value to stderr and passes it through:

```bash
echo '{"step": "processing", "val": 42}' | jq '.val | . * 2 | stderr | . + 1'
# stderr: 84
# stdout: 85
# Python: x = val*2; print(x, file=sys.stderr); result = x + 1
# Excel:  no direct equivalent
```

## Module System

### File Structure

jq modules are `.jq` files containing function definitions:

```
# mylib.jq
def double: . * 2;
def triple: . * 3;
def clamp($lo; $hi): if . < $lo then $lo elif . > $hi then $hi else . end;
```

### `include` — Import All Definitions

```bash
# jq -L ./lib 'include "mylib"; map(double)' input.json
# Python: from mylib import double; [double(x) for x in lst]
# Excel:  no direct equivalent (VBA modules or LAMBDA named functions)
```

`include "name"` imports all `def`s from `name.jq` into the current scope.

### `import` — Namespaced Import

```bash
# jq -L ./lib 'import "mylib" as m; map(m::double)' input.json
# Python: import mylib as m; [m.double(x) for x in lst]
# Excel:  no direct equivalent
```

### Module Metadata

```
# mylib.jq
module { "name": "mylib", "version": "1.0.0" };

def double: . * 2;
```

### Search Path

jq looks for modules in:
1. Directories specified with `-L`
2. `~/.jq` (legacy single-file library)

Typical project layout:

```
project/
  lib/
    utils.jq
    transforms.jq
  main.jq         # include "utils"; include "transforms"; ...
```

## `$__loc__` — Source Location

Returns the current file and line number (useful for debugging):

```bash
jq -n '$__loc__'
# {"file":"<top-level>","line":1}
# Python: f"{__file__}:{inspect.currentframe().f_lineno}"
# Excel:  =CELL("filename") for the current file
```

## Advanced: `try-catch` with Generators

`try` catches errors from the expression, including generator exhaustion:

```bash
echo '[1, 2, "three", 4]' | jq '[.[] | try (. + 1)]'
# [2, 3, 5]  — "three" + 1 errors silently

echo '["1", "bad", "3"]' | jq '[.[] | try tonumber catch "NaN"]'
# [1, "NaN", 3]
# Python: [x+1 for x in lst if isinstance(x, (int,float))]; or try/except per item
# Excel:  =IFERROR(A1+1, "") to suppress errors
```

## Advanced: Recursion with `def` for Generators

Recursive generators are powerful for tree traversal:

```bash
echo '{"a":{"b":{"c":1}},"d":2}' | jq '
  def all_leaves:
    if type == "object" then .[] | all_leaves
    elif type == "array" then .[] | all_leaves
    else .
    end;
  [all_leaves]'
# [1, 2]
# Python: def all_leaves(d): yield from (all_leaves(v) if isinstance(v,(dict,list)) else [v] ...)
# Excel:  no direct equivalent
```

## `builtins` — List All Available Functions

```bash
jq -n 'builtins | length'
# shows how many builtins exist

jq -n '[builtins | .[] | select(startswith("to"))]'
# all builtins starting with "to"
# Python: dir(module) or inspect.getmembers(module)
# Excel:  no direct equivalent (browse function list in Insert Function dialog)
```

## Exercises

1. Build a URL from `{"base":"https://api.example.com","path":"/search","params":{"q":"hello world","page":"2"}}` with proper URL encoding.
2. Convert `[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]` to CSV output with headers.
3. Use `INDEX` to join `{"students":[{"id":1,"name":"A"},{"id":2,"name":"B"}],"grades":[{"student_id":1,"grade":"A"},{"student_id":2,"grade":"B+"}]}`.
4. Use `debug` to trace the transformation of `[1,2,3]` through `map(. * 2 | . + 1)`.
5. Given two JSON objects on separate lines, compute which keys are in both:
   `echo -e '{"a":1,"b":2,"c":3}\n{"b":4,"c":5,"d":6}'`

<details>
<summary>Solutions</summary>

```bash
# 1
echo '{"base":"https://api.example.com","path":"/search","params":{"q":"hello world","page":"2"}}' | jq -r '
  .base + .path + "?" + (
    .params | to_entries | map("\(.key)=\(.value | @uri)") | join("&")
  )'
# https://api.example.com/search?q=hello%20world&page=2
# Python: urllib.parse.urlencode(params); f"{base}{path}?{encoded}"
# Excel:  string concatenation with ENCODEURL(): =A1&B1&"?"&ENCODEURL(C1)

# 2
echo '[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]' | jq -r '
  (.[0] | keys_unsorted) as $cols |
  ($cols | @csv), (.[] | [.[$cols[]]] | @csv)'
# "id","name"
# 1,"Alice"
# 2,"Bob"
# Python: pd.DataFrame(data).to_csv(index=False) or csv.DictWriter
# Excel:  native — this IS what Excel does (tabular data with headers)

# 3
echo '{"students":[{"id":1,"name":"A"},{"id":2,"name":"B"}],"grades":[{"student_id":1,"grade":"A"},{"student_id":2,"grade":"B+"}]}' | jq '
  INDEX(.students[]; .id) as $stu |
  [.grades[] | . + {name: $stu[(.student_id | tostring)].name}]'
# [{"student_id":1,"grade":"A","name":"A"},{"student_id":2,"grade":"B+","name":"B"}]
# Python: pd.merge(grades_df, students_df, left_on="student_id", right_on="id")
# Excel:  =VLOOKUP(student_id, students_table, 2, FALSE)

# 4
echo '[1,2,3]' | jq 'map(debug("input") | . * 2 | debug("doubled") | . + 1 | debug("final"))'
# stderr shows each step; stdout: [3,5,7]
# Python: use logging.debug() at each transformation step
# Excel:  Evaluate Formula step-by-step (Formulas > Evaluate Formula)

# 5
echo -e '{"a":1,"b":2,"c":3}\n{"b":4,"c":5,"d":6}' | jq -n '
  [inputs | keys[]] | group_by(.) | map(select(length > 1) | .[0])'
# ["b","c"]
# or:
echo -e '{"a":1,"b":2,"c":3}\n{"b":4,"c":5,"d":6}' | jq -s '
  (.[0] | keys) as $k1 | (.[1] | keys) as $k2 |
  [$k1[] | select(IN($k2[]))]'
# ["b","c"]
# Python: set(d1.keys()) & set(d2.keys())
# Excel:  =FILTER(keys1, COUNTIF(keys2, keys1)>0) or MATCH-based formula
```

</details>
