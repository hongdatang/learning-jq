# Tutorial 12 -- Real-World Recipes

Practical patterns you'll use daily with APIs, config files, logs, and data processing.

## Recipe 1: Transform API Responses

### Reshape a GitHub-style API Response

```bash
echo '[
  {"name":"repo1","stargazers_count":100,"language":"Python","archived":false},
  {"name":"repo2","stargazers_count":50,"language":"Java","archived":true},
  {"name":"repo3","stargazers_count":200,"language":"Python","archived":false}
]' | jq '
  [.[] | select(.archived | not)] |
  sort_by(.stargazers_count) | reverse |
  map({name, stars: .stargazers_count, language})'
# [{"name":"repo3","stars":200,"language":"Python"},
#  {"name":"repo1","stars":100,"language":"Python"}]
# Python: sorted([r for r in repos if not r["archived"]], key=lambda r: r["stargazers_count"], reverse=True)
# Excel:  Filter archived=FALSE, then Sort by stars descending
```

### Paginated API: Merge Multiple Pages

```bash
# Simulating multiple page responses
echo -e '[{"id":1}]\n[{"id":2}]\n[{"id":3}]' | jq -s 'add'
# [{"id":1},{"id":2},{"id":3}]
# Python: list(itertools.chain.from_iterable(pages))  or sum(pages, [])
# Excel:  paste each page's rows below the previous
```

### Extract Nested Data from API

```bash
echo '{"data":{"users":{"edges":[{"node":{"name":"Alice","email":"a@x.com"}},{"node":{"name":"Bob","email":"b@x.com"}}]}}}' | jq '
  [.data.users.edges[].node | {name, email}]'
# [{"name":"Alice","email":"a@x.com"},{"name":"Bob","email":"b@x.com"}]
# Python: [{"name": e["node"]["name"], "email": e["node"]["email"]} for e in data["data"]["users"]["edges"]]
# Excel:  Power Query > navigate nested JSON > expand columns
```

## Recipe 2: JSON to CSV Conversion

### Simple Table

```bash
echo '[
  {"name":"Alice","age":30,"city":"Tokyo"},
  {"name":"Bob","age":25,"city":"Berlin"},
  {"name":"Carol","age":35,"city":"Paris"}
]' | jq -r '
  (.[0] | keys) as $cols |
  $cols, (.[] | [.[$cols[]]]) | @csv'
# Python: pd.DataFrame(data).to_csv(index=False)
# Excel:  native format — open the CSV file directly
```

Output:

```
"age","city","name"
30,"Tokyo","Alice"
25,"Berlin","Bob"
35,"Paris","Carol"
```

### TSV (Tab-Separated) — Often Cleaner

```bash
echo '[
  {"name":"Alice","age":30,"city":"Tokyo"},
  {"name":"Bob","age":25,"city":"Berlin"}
]' | jq -r '
  ["name","age","city"],
  (.[] | [.name, .age, .city]) | @tsv'
# Python: csv.writer(f, delimiter='\t').writerows(...)
# Excel:  native — paste TSV data or open .tsv file
```

Output:

```
name	age	city
Alice	30	Tokyo
Bob	25	Berlin
```

### Flatten Nested Objects for CSV

```bash
echo '[{"user":{"name":"Alice","age":30},"score":95}]' | jq -r '
  ["user_name","user_age","score"],
  (.[] | [.user.name, .user.age, .score]) | @csv'
# Python: pd.json_normalize(data).to_csv(index=False)
# Excel:  Power Query > expand nested record columns
```

## Recipe 3: CSV to JSON

```bash
echo 'name,age,city
Alice,30,Tokyo
Bob,25,Berlin' | jq -Rs '
  split("\n") | map(select(length > 0)) |
  .[0] as $header |
  .[1:] | map(
    split(",") | . as $row |
    reduce range($header | split(",") | length) as $i (
      {}; . + {(($header | split(","))[$i]): $row[$i]}
    )
  )'
# [{"name":"Alice","age":"30","city":"Tokyo"},{"name":"Bob","age":"25","city":"Berlin"}]
# Python: pd.read_csv(f).to_dict(orient="records") or csv.DictReader(f)
# Excel:  open the CSV — Excel parses it into rows/columns automatically
```

## Recipe 4: Configuration Merging

### Default + Override (Shallow)

```bash
echo '{"host":"localhost","port":3000,"debug":false}' | jq --argjson override '{"port":8080,"debug":true}' '
  . + $override'
# {"host":"localhost","port":8080,"debug":true}
# Python: {**defaults, **override} or defaults | override (Python 3.9+)
# Excel:  no direct equivalent (manually override cells)
```

### Deep Merge with `*`

```bash
echo '{
  "database": {"host":"localhost","port":5432,"pool":{"min":2,"max":10}},
  "logging": {"level":"info","file":"/var/log/app.log"}
}' | jq --argjson prod '{
  "database": {"host":"db.prod.internal","pool":{"max":50}},
  "logging": {"level":"warn"}
}' '
  . * $prod'
# {
#   "database":{"host":"db.prod.internal","port":5432,"pool":{"min":2,"max":50}},
#   "logging":{"level":"warn","file":"/var/log/app.log"}
# }
# Python: deep_merge(base, prod) — e.g. using deepmerge library or recursive dict update
# Excel:  no direct equivalent
```

### Merge Multiple Config Files

```bash
# jq -s 'reduce .[] as $c ({}; . * $c)' defaults.json env.json local.json
# Last file wins on conflicts (left-to-right priority)
# Python: functools.reduce(deep_merge, [defaults, env_cfg, local_cfg])
# Excel:  no direct equivalent
```

## Recipe 5: Log Analysis

### Parse Structured Logs (JSON Lines)

```bash
echo '{"ts":"2024-01-15T10:00:00","level":"INFO","msg":"started"}
{"ts":"2024-01-15T10:00:01","level":"ERROR","msg":"disk full"}
{"ts":"2024-01-15T10:00:02","level":"INFO","msg":"request handled"}
{"ts":"2024-01-15T10:00:03","level":"ERROR","msg":"timeout"}' | jq -s '
  group_by(.level) | map({
    level: .[0].level,
    count: length,
    messages: map(.msg)
  })'
# Python: pd.DataFrame(logs).groupby("level").agg(count=("msg","count"), messages=("msg",list))
# Excel:  Pivot Table grouping by level with COUNT and message list
```

### Count Errors by Type

```bash
echo '{"ts":"10:00","level":"ERROR","code":"DISK_FULL"}
{"ts":"10:01","level":"ERROR","code":"TIMEOUT"}
{"ts":"10:02","level":"ERROR","code":"DISK_FULL"}
{"ts":"10:03","level":"INFO","code":"OK"}
{"ts":"10:04","level":"ERROR","code":"TIMEOUT"}
{"ts":"10:05","level":"ERROR","code":"TIMEOUT"}' | jq -s '
  map(select(.level == "ERROR")) |
  group_by(.code) | map({code: .[0].code, count: length}) |
  sort_by(.count) | reverse'
# [{"code":"TIMEOUT","count":3},{"code":"DISK_FULL","count":2}]
# Python: df[df.level=="ERROR"].groupby("code").size().sort_values(ascending=False)
# Excel:  COUNTIFS(level,"ERROR",code,"TIMEOUT") or Pivot Table
```

## Recipe 6: Kubernetes / Docker Output Processing

### Extract Pod Info

```bash
echo '{
  "items": [
    {"metadata":{"name":"web-abc","namespace":"prod"},"status":{"phase":"Running"}},
    {"metadata":{"name":"api-def","namespace":"prod"},"status":{"phase":"Pending"}},
    {"metadata":{"name":"db-ghi","namespace":"staging"},"status":{"phase":"Running"}}
  ]
}' | jq -r '
  .items[] |
  [.metadata.namespace, .metadata.name, .status.phase] | @tsv'
# Python: [[i["metadata"]["namespace"], i["metadata"]["name"], i["status"]["phase"]] for i in data["items"]]
# Excel:  Power Query to flatten nested JSON; then display as table
```

Output:

```
prod	web-abc	Running
prod	api-def	Pending
staging	db-ghi	Running
```

### Filter by Condition

```bash
# Same input as above
echo '...' | jq '
  [.items[] | select(.status.phase != "Running") |
   {name: .metadata.name, status: .status.phase}]'
# Python: [{"name": i["metadata"]["name"], "status": i["status"]["phase"]} for i in items if i["status"]["phase"] != "Running"]
# Excel:  =FILTER(table, status_col<>"Running")
```

## Recipe 7: Data Aggregation Pipeline

### Sales Report

```bash
echo '[
  {"date":"2024-01","region":"US","product":"A","revenue":1000},
  {"date":"2024-01","region":"EU","product":"A","revenue":800},
  {"date":"2024-01","region":"US","product":"B","revenue":1200},
  {"date":"2024-02","region":"US","product":"A","revenue":1100},
  {"date":"2024-02","region":"EU","product":"B","revenue":900}
]' | jq '
  group_by(.date) | map({
    month: .[0].date,
    total_revenue: (map(.revenue) | add),
    by_region: (group_by(.region) | map({
      region: .[0].region,
      revenue: (map(.revenue) | add)
    }))
  })'
# Python: df.groupby(["date","region"])["revenue"].sum().reset_index()
# Excel:  Pivot Table with date as rows, region as columns, SUM of revenue
```

### Top-N per Group

```bash
echo '[
  {"category":"fruit","name":"apple","sales":100},
  {"category":"fruit","name":"banana","sales":80},
  {"category":"fruit","name":"cherry","sales":120},
  {"category":"veggie","name":"carrot","sales":90},
  {"category":"veggie","name":"broccoli","sales":110},
  {"category":"veggie","name":"spinach","sales":70}
]' | jq '
  group_by(.category) | map({
    category: .[0].category,
    top2: (sort_by(.sales) | reverse | .[:2] | map({name, sales}))
  })'
# Python: df.groupby("category").apply(lambda g: g.nlargest(2, "sales"))
# Excel:  SORT + FILTER per category, or LARGE() to get top-N values
```

## Recipe 8: JSON Diff

### Compare Two Objects

```bash
jq -n --argjson a '{"x":1,"y":2,"z":3}' --argjson b '{"x":1,"y":99,"w":4}' '
  {
    added: ($b | keys - ($a | keys)),
    removed: ($a | keys - ($b | keys)),
    changed: [($a | keys[]) | select(. as $k | ($b | has($k)) and $a[$k] != $b[$k])],
    unchanged: [($a | keys[]) | select(. as $k | ($b | has($k)) and $a[$k] == $b[$k])]
  }'
# {"added":["w"],"removed":["z"],"changed":["y"],"unchanged":["x"]}
# Python: added = b.keys() - a.keys(); removed = a.keys() - b.keys(); changed = {k for k in a.keys() & b.keys() if a[k] != b[k]}
# Excel:  conditional formatting to highlight differences; no structural diff
```

## Recipe 9: Denormalize / Flatten Nested Data

### Parent-Child to Flat Rows

```bash
echo '{
  "company": "Acme",
  "departments": [
    {"name": "Eng", "employees": ["Alice", "Bob"]},
    {"name": "Sales", "employees": ["Carol"]}
  ]
}' | jq '[
  .company as $co |
  .departments[] | .name as $dept |
  .employees[] |
  {company: $co, department: $dept, employee: .}
]'
# [{"company":"Acme","department":"Eng","employee":"Alice"},
#  {"company":"Acme","department":"Eng","employee":"Bob"},
#  {"company":"Acme","department":"Sales","employee":"Carol"}]
# Python: [{"company": d["company"], "dept": dept["name"], "employee": e} for d in data for dept in d["departments"] for e in dept["employees"]]
# Excel:  Power Query > expand nested lists to flat rows
```

## Recipe 10: Build Shell Commands

### Generate Environment Variables

```bash
echo '{"DB_HOST":"localhost","DB_PORT":"5432","DB_NAME":"mydb"}' | jq -r '
  to_entries | map("export \(.key)=\(.value | @sh)") | .[]'
# export DB_HOST='localhost'
# export DB_PORT='5432'
# export DB_NAME='mydb'
# Python: "\n".join(f"export {k}={shlex.quote(v)}" for k, v in d.items())
# Excel:  ="export "&A1&"='"&B1&"'" concatenation formula
```

### Generate SQL Inserts

```bash
echo '[{"name":"Alice","age":30},{"name":"Bob","age":25}]' | jq -r '
  .[] | "INSERT INTO users (name, age) VALUES (\(.name | @json), \(.age));"'
# INSERT INTO users (name, age) VALUES ("Alice", 30);
# INSERT INTO users (name, age) VALUES ("Bob", 25);
# Python: f"INSERT INTO users (name, age) VALUES ({json.dumps(r['name'])}, {r['age']});"
# Excel:  ="INSERT INTO users (name, age) VALUES ('"&A2&"', "&B2&");"
```

## Recipe 11: Working with Dates

```bash
# Current time (Unix timestamp)
jq -n 'now'
# 1705312800.123

# Format dates
jq -n 'now | strftime("%Y-%m-%d %H:%M:%S")'
# "2024-01-15 10:00:00"

# Parse ISO date
echo '"2024-01-15T10:30:00Z"' | jq 'fromdateiso8601'
# 1705314600

# Convert timestamp to readable
echo '1705314600' | jq 'todate'
# "2024-01-15T10:30:00Z"

# Date arithmetic (add 7 days = 604800 seconds)
echo '"2024-01-15T00:00:00Z"' | jq 'fromdateiso8601 + 604800 | todate'
# "2024-01-22T00:00:00Z"
# Python: datetime.now().timestamp(); datetime.strptime(...); dt + timedelta(days=7)
# Excel:  =NOW(), =TEXT(A1,"YYYY-MM-DD"), =A1+7 (dates are numbers in Excel)
```

## Recipe 12: Process JSONL (JSON Lines)

JSON Lines is one JSON value per line — the most common format for streaming data:

```bash
# Count lines
# jq -s 'length' data.jsonl

# Filter and count
# jq -c 'select(.status == "error")' data.jsonl | wc -l

# Top 10 by field
# jq -s 'sort_by(.duration) | reverse | .[:10]' requests.jsonl

# Sample: take every 100th line
# jq -n --slurpfile data <(cat data.jsonl) '$data | to_entries | map(select(.key % 100 == 0) | .value)'
# Python: len(lines); sum(1 for l in lines if json.loads(l)["status"]=="error"); sorted(data, key=...)[:10]
# Excel:  =COUNTA(column); COUNTIF; SORT + TOP-N via LARGE or FILTER
```

Efficient JSONL processing — jq processes line by line without `-s`:

```bash
echo '{"user":"alice","action":"login"}
{"user":"bob","action":"purchase"}
{"user":"alice","action":"logout"}' | jq -c 'select(.user == "alice")'
# {"user":"alice","action":"login"}
# {"user":"alice","action":"logout"}
# Python: [row for row in data if row["user"] == "alice"]
# Excel:  =FILTER(table, user_col="alice")
```

## Recipe 13: Validate JSON Structure

```bash
echo '{"name":"Alice","age":30,"email":"alice@example.com"}' | jq '
  def require(key; type_name):
    if has(key) and (.[key] | type) == type_name then .
    else error("\(key) must be a \(type_name)")
    end;
  require("name"; "string") |
  require("age"; "number") |
  require("email"; "string") |
  if (.age < 0 or .age > 150) then error("age out of range") else . end |
  if (.email | test("@") | not) then error("invalid email") else . end |
  "valid"'
# "valid"
# Python: pydantic model or jsonschema.validate(data, schema)
# Excel:  Data Validation rules (dropdown, range, custom formula)
```

## Recipe 14: Pipe with Other Tools

```bash
# curl + jq: fetch and transform API data
# curl -s https://api.github.com/users/octocat/repos | jq '.[].name'

# kubectl + jq: Kubernetes resources
# kubectl get pods -o json | jq '.items[] | {name: .metadata.name, status: .status.phase}'

# aws + jq: AWS CLI output
# aws ec2 describe-instances | jq '.Reservations[].Instances[] | {id: .InstanceId, state: .State.Name}'

# docker + jq: container info
# docker inspect $(docker ps -q) | jq '.[] | {name: .Name, image: .Config.Image}'

# gh + jq: GitHub CLI
# gh pr list --json title,author,createdAt | jq '.[] | "\(.author.login): \(.title)"'
# Python: requests.get(url).json(); subprocess + json.loads(); boto3 SDK calls
# Excel:  Power Query > From Web/API; or paste JSON into cells
```

## Recipe 15: Mermaid Diagram from JSON

```bash
echo '{"nodes":[{"id":"A","label":"Start"},{"id":"B","label":"Process"},{"id":"C","label":"End"}],"edges":[{"from":"A","to":"B"},{"from":"B","to":"C"}]}' | jq -r '
  "graph LR",
  (.nodes[] | "    \(.id)[\(.label)]"),
  (.edges[] | "    \(.from) --> \(.to)")'
# Python: "\n".join(["graph LR"] + [f"    {n['id']}[{n['label']}]" for n in nodes] + [f"    {e['from']} --> {e['to']}" for e in edges])
# Excel:  no direct equivalent (string concatenation formulas possible but awkward)
```

Output:

```
graph LR
    A[Start]
    B[Process]
    C[End]
    A --> B
    B --> C
```

## Performance Tips

1. **Avoid `-s` for huge files** — process line by line when possible
2. **Use `--stream` for multi-GB files** — doesn't load entire file
3. **`INDEX(.[]; .key)` for lookups** — O(n) build, O(1) per query
4. **`limit(n; expr)` is lazy** — stops after n results
5. **`first(expr | select(cond))`** — stops at first match
6. **Prefer builtins** (`add`, `sort_by`, `group_by`) over manual `reduce`
7. **`[generator]` over `reduce ... ([] ; . + [item])`** — `[...]` is O(n), repeated append is O(n²)
8. **`-c` (compact output)** — faster for pipelines (no pretty-print overhead)
9. **`inputs` over `-s`** — reads values incrementally
10. **Know when to switch** — if the jq filter exceeds ~20-30 lines, consider Python for maintainability, or Excel/Google Sheets if the audience needs a visual, interactive view of the data
