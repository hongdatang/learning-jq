# Tutorial 08 — Regular Expressions

jq has first-class regex support via the Oniguruma library (same engine as Ruby).

## Regex Flags

| Flag | Meaning |
|------|---------|
| `"x"` | Extended — ignore whitespace and `#` comments in pattern |
| `"i"` | Case-insensitive |
| `"m"` | Multiline — `^` and `$` match line boundaries |
| `"s"` | Single-line — `.` matches `\n` |
| `"g"` | Global — all matches (used by `scan`, `gsub`, etc.) |

Flags are passed as a string: `"ix"` means case-insensitive + extended.

## `test` — Boolean Match

Returns `true` if the input matches the regex:

```bash
echo '"foobar"' | jq 'test("foo")'
# true

echo '"foobar"' | jq 'test("^bar")'
# false

echo '"Hello World"' | jq 'test("hello")'
# false

echo '"Hello World"' | jq 'test("hello"; "i")'
# true  — case-insensitive
# Python: bool(re.search("foo", "foobar")); bool(re.search("hello", s, re.IGNORECASE))
# Excel:  =ISNUMBER(SEARCH("foo", A1)) — SEARCH is case-insensitive; FIND is case-sensitive
```

Commonly used with `select`:

```bash
echo '["apple", "banana", "avocado", "cherry"]' | jq '[.[] | select(test("^a"))]'
# ["apple", "avocado"]
# Python: [s for s in data if re.match("^a", s)]
# Excel:  =FILTER(A1:A4, LEFT(A1:A4,1)="a")
```

## `match` — Detailed Match Object

Returns a match object with offset, length, string, and captures:

```bash
echo '"foo bar 123"' | jq 'match("[0-9]+")'
# {"offset":8,"length":3,"string":"123","captures":[]}

echo '"2024-01-15"' | jq 'match("([0-9]{4})-([0-9]{2})-([0-9]{2})")'
# {
#   "offset": 0,
#   "length": 10,
#   "string": "2024-01-15",
#   "captures": [
#     {"offset":0,"length":4,"string":"2024","name":null},
#     {"offset":5,"length":2,"string":"01","name":null},
#     {"offset":8,"length":2,"string":"15","name":null}
#   ]
# }
# Python: m = re.search(r"(\d{4})-(\d{2})-(\d{2})", s); m.group(), m.groups()
# Excel:  no direct equivalent (use MID + FIND for positional extraction)
```

### Named Captures

Use `(?<name>...)` for named groups:

```bash
echo '"2024-01-15"' | jq 'match("(?<year>[0-9]{4})-(?<month>[0-9]{2})-(?<day>[0-9]{2})")'
# {
#   ...
#   "captures": [
#     {"offset":0,"length":4,"string":"2024","name":"year"},
#     {"offset":5,"length":2,"string":"01","name":"month"},
#     {"offset":8,"length":2,"string":"15","name":"day"}
#   ]
# }
# Python: re.search(r"(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})", s).groupdict()
# Excel:  =YEAR(A1), =MONTH(A1), =DAY(A1)  (if recognized as date)
```

### Global Match

With the `"g"` flag, `match` becomes a generator producing multiple matches:

```bash
echo '"foo123bar456"' | jq '[match("[0-9]+"; "g")]'
# [
#   {"offset":3,"length":3,"string":"123","captures":[]},
#   {"offset":9,"length":3,"string":"456","captures":[]}
# ]
# Python: [m for m in re.finditer(r"[0-9]+", s)]  (each m has .start(), .group())
# Excel:  no direct equivalent
```

## `capture` — Named Captures as Object

Returns only the named captures as a simple key-value object:

```bash
echo '"John Smith, age 30"' | jq 'capture("(?<name>[A-Za-z ]+), age (?<age>[0-9]+)")'
# {"name":"John Smith","age":"30"}

echo '"2024-01-15"' | jq 'capture("(?<y>[0-9]{4})-(?<m>[0-9]{2})-(?<d>[0-9]{2})")'
# {"y":"2024","m":"01","d":"15"}
# Python: re.match(r"(?P<y>\d{4})-(?P<m>\d{2})-(?P<d>\d{2})", s).groupdict()
# Excel:  =LEFT(A1,4) for year, =MID(A1,6,2) for month, =RIGHT(A1,2) for day
```

> **Familiar?** `capture` is like Python's `re.match(...).groupdict()`, or using
> Excel's `TEXTBEFORE()`/`TEXTAFTER()`/`MID()` to extract parts of a string into
> separate columns.

## `scan` — Find All Matches

`scan` returns all matching substrings. Without groups, it returns strings. With groups,
it returns arrays of captured groups:

```bash
echo '"foo123bar456baz789"' | jq '[scan("[0-9]+")]'
# ["123","456","789"]

echo '"hello world hello jq"' | jq '[scan("hello")]'
# ["hello","hello"]

echo '"Jan 15, Feb 20, Mar 5"' | jq '[scan("([A-Za-z]+) ([0-9]+)")]'
# [["Jan","15"],["Feb","20"],["Mar","5"]]
# Python: re.findall(r"[0-9]+", s); re.findall(r"([A-Za-z]+) ([0-9]+)", s)
# Excel:  no direct equivalent (TEXTSPLIT + FILTER for simple cases)
```

### Extracting Patterns

```bash
# Extract all email-like patterns
echo '"Contact alice@example.com or bob@test.org"' | jq '[scan("[\\w.]+@[\\w.]+")] '
# ["alice@example.com","bob@test.org"]

# Extract all numbers
echo '"There are 3 cats and 12 dogs"' | jq '[scan("[0-9]+") | tonumber]'
# [3, 12]
# Python: re.findall(r"[\w.]+@[\w.]+", s); [int(x) for x in re.findall(r"[0-9]+", s)]
# Excel:  no direct equivalent (would require VBA or complex formulas)
```

## `split` — Split with Regex

Two forms: string split and regex split:

```bash
# String split (no regex)
echo '"a,b,,c"' | jq 'split(",")'
# ["a","b","","c"]

# Regex split
echo '"one  two   three"' | jq 'split("\\s+"; "")'
# ["one","two","three"]

echo '"camelCaseWords"' | jq 'split("(?=[A-Z])"; "")'
# ["camel","Case","Words"]  — split before uppercase letters
# Python: "a,b,,c".split(","); re.split(r"\s+", s); re.split(r"(?=[A-Z])", s)
# Excel:  =TEXTSPLIT(A1, ",") for simple splits; no regex split
```

`splits` (with trailing `s`) is a generator version — it produces individual parts:

```bash
echo '"a,b,c"' | jq '[splits(",")]'
# ["a","b","c"]
# Python: "a,b,c".split(",")
# Excel:  =TEXTSPLIT("a,b,c", ",")
```

## `sub` — Replace First Match

```bash
echo '"hello world"' | jq 'sub("world"; "jq")'
# "hello jq"

echo '"foo123bar"' | jq 'sub("[0-9]+"; "NUM")'
# "fooNUMbar"
# Python: re.sub(r"[0-9]+", "NUM", s, count=1)
# Excel:  =SUBSTITUTE(A1, "world", "jq") — string only, no regex support
```

### Backreferences in Replacement

Use named captures in the replacement string:

```bash
echo '"John Smith"' | jq 'sub("(?<first>\\w+) (?<last>\\w+)"; "\(.last), \(.first)")'
# "Smith, John"
# Python: re.sub(r"(?P<first>\w+) (?P<last>\w+)", r"\g<last>, \g<first>", s)
# Excel:  =TEXTAFTER(A1," ") & ", " & TEXTBEFORE(A1," ")
```

## `gsub` — Replace All Matches

```bash
echo '"foo 123 bar 456"' | jq 'gsub("[0-9]+"; "NUM")'
# "foo NUM bar NUM"

echo '"hello   world   jq"' | jq 'gsub("\\s+"; " ")'
# "hello world jq"

# Remove non-alphanumeric characters
echo '"Hello, World! 123"' | jq 'gsub("[^a-zA-Z0-9 ]"; "")'
# "Hello World 123"
# Python: re.sub(r"[0-9]+", "NUM", s); re.sub(r"\s+", " ", s); re.sub(r"[^a-zA-Z0-9 ]", "", s)
# Excel:  no direct equivalent (SUBSTITUTE only handles literal strings, not patterns)
```

### Dynamic Replacement

The replacement is a filter expression, so you can compute it:

```bash
echo '"price: $100, tax: $15"' | jq 'gsub("\\$(?<n>[0-9]+)"; "€\(.n | tonumber * 0.85 | round)")'
# "price: €85, tax: €13"
# Python: re.sub(r"\$(\d+)", lambda m: f"€{round(int(m.group(1))*0.85)}", s)
# Excel:  no direct equivalent (would need VBA for regex + computed replacement)
```

## Practical Patterns

### Validate Input Format

```bash
echo '"2024-01-15"' | jq '
  if test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") then "valid date format"
  else error("invalid date format")
  end'
# "valid date format"
# Python: if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", s): raise ValueError(...)
# Excel:  =IF(AND(LEN(A1)=10, ISNUMBER(DATEVALUE(A1))), "valid", "invalid")
```

### Parse Structured Strings

```bash
echo '"GET /api/users?page=2 HTTP/1.1"' | jq '
  capture("(?<method>\\w+) (?<path>[^ ]+) (?<protocol>.*)")'
# {"method":"GET","path":"/api/users?page=2","protocol":"HTTP/1.1"}
# Python: re.match(r"(?P<method>\w+) (?P<path>\S+) (?P<protocol>.*)", s).groupdict()
# Excel:  =TEXTBEFORE(A1," ") for method, nested TEXTBEFORE/TEXTAFTER for the rest
```

### Extract and Transform Log Lines

```bash
echo '["2024-01-15 ERROR: disk full","2024-01-15 INFO: started","2024-01-16 ERROR: timeout"]' | jq '
  [.[] | select(test("ERROR"))
       | capture("(?<date>[^ ]+) ERROR: (?<msg>.*)")
       | {date, error: .msg}]'
# [{"date":"2024-01-15","error":"disk full"},{"date":"2024-01-16","error":"timeout"}]
# Python: [re.match(r"(\S+) ERROR: (.*)", l).groups() for l in lines if "ERROR" in l]
# Excel:  =FILTER(A:A, ISNUMBER(SEARCH("ERROR",A:A))) then parse with TEXTBEFORE/TEXTAFTER
```

### Clean and Normalize Data

```bash
echo '["  Alice  ", "BOB", " carol "]' | jq '
  map(gsub("^\\s+|\\s+$"; "") | ascii_downcase | sub("^(?<c>.)"; .c | ascii_upcase))'
# ["Alice","Bob","Carol"]
# Python: [s.strip().capitalize() for s in data]
# Excel:  =PROPER(TRIM(A1))
```

Or using jq 1.8's `trim`:

```bash
echo '["  Alice  ", "BOB", " carol "]' | jq '
  map(trim | ascii_downcase | sub("^(?<c>.)"; .c | ascii_upcase))'
# ["Alice","Bob","Carol"]
# Python: [s.strip().capitalize() for s in data]
# Excel:  =PROPER(TRIM(A1))
```

### Split CSV-like Lines

```bash
echo '"name,age,city\nAlice,30,Tokyo\nBob,25,Berlin"' | jq '
  split("\n") |
  .[0] as $headers |
  .[1:] | map(
    split(",") | . as $vals |
    reduce range($headers | split(",") | length) as $i (
      {}; . + {(($headers | split(","))[$i]): $vals[$i]}
    )
  )'
# [{"name":"Alice","age":"30","city":"Tokyo"},{"name":"Bob","age":"25","city":"Berlin"}]
# Python: import csv; list(csv.DictReader(data.splitlines()))
# Excel:  Data > From Text/CSV (import wizard handles this natively)
```

## Regex vs String Functions

Use string functions when possible — they're simpler and faster:

| Task | Regex | String function |
|------|-------|-----------------|
| Contains substring | `test("foo")` | `contains("foo")` |
| Starts with | `test("^foo")` | `startswith("foo")` |
| Ends with | `test("foo$")` | `endswith("foo")` |
| Simple split | `split(","; "")` | `split(",")` |
| Trim whitespace | `gsub("^\\s+\|\\s+$"; "")` | `trim` (jq 1.8) |

Use regex when you need patterns, captures, or complex matching.

## Exercises

1. From `["abc123", "def", "456ghi", "jkl"]`, select only strings containing digits.
2. Extract year, month, day from `"2024-03-15T10:30:00Z"` as an object.
3. Replace all runs of whitespace in `"hello   world  jq"` with a single space.
4. From `"key1=val1&key2=val2&key3=val3"`, parse into `{"key1":"val1",...}`.
5. Given log entries like `"[ERROR] 2024-01-15 Something went wrong"`, extract
   the level, date, and message into an object.

<details>
<summary>Solutions</summary>

```bash
# 1
echo '["abc123","def","456ghi","jkl"]' | jq '[.[] | select(test("[0-9]"))]'
# ["abc123","456ghi"]
# Python: [s for s in data if re.search(r"[0-9]", s)]
# Excel:  =FILTER(A1:A4, ISNUMBER(SUMPRODUCT(SEARCH({0,1,2,3,4,5,6,7,8,9}, A1:A4))))

# 2
echo '"2024-03-15T10:30:00Z"' | jq 'capture("(?<year>\\d{4})-(?<month>\\d{2})-(?<day>\\d{2})")'
# {"year":"2024","month":"03","day":"15"}
# Python: re.match(r"(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})", s).groupdict()
# Excel:  =LEFT(A1,4), =MID(A1,6,2), =MID(A1,9,2)

# 3
echo '"hello   world  jq"' | jq 'gsub("\\s+"; " ")'
# "hello world jq"
# Python: re.sub(r"\s+", " ", s)
# Excel:  =TRIM(A1) — collapses multiple spaces to single

# 4
echo '"key1=val1&key2=val2&key3=val3"' | jq '
  split("&") | map(split("=") | {(.[0]): .[1]}) | add'
# {"key1":"val1","key2":"val2","key3":"val3"}
# Python: dict(pair.split("=") for pair in s.split("&"))  (or urllib.parse.parse_qs)
# Excel:  =TEXTSPLIT then split each part by "=" — no single-formula equivalent

# 5
echo '"[ERROR] 2024-01-15 Something went wrong"' | jq '
  capture("\\[(?<level>\\w+)\\] (?<date>\\S+) (?<message>.*)")'
# {"level":"ERROR","date":"2024-01-15","message":"Something went wrong"}
# Python: re.match(r"\[(?P<level>\w+)\] (?P<date>\S+) (?P<message>.*)", s).groupdict()
# Excel:  =MID(A1,2,FIND("]",A1)-2) for level, TEXTBEFORE/TEXTAFTER for the rest
```

</details>
