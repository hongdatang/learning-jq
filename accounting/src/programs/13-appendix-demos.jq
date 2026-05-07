# Lesson 13 -- Appendix Demos
# Tutorial: accounting/13-appendix-extra-features.md
# Data:     accounting/src/data/13-appendix-samples.json
# Run:      jq -f accounting/src/programs/13-appendix-demos.jq accounting/src/data/13-appendix-samples.json

# ── String / Encoding ──────────────────────────────────

"=== String / Encoding ===",
"",

# explode / implode: string <-> codepoint array
"explode \"Hello\":",
("Hello" | explode),
"implode back:",
([72, 101, 108, 108, 111] | implode),
"",

# tojson / fromjson: JSON within JSON
"tojson: embed an object as a string:",
({name: "lemonade", price: 1.00} | tojson),
"fromjson: parse it back:",
("{\"name\":\"lemonade\",\"price\":1}" | fromjson | .name),
"",

# @html: entity escaping
"@html escaping:",
(.strings.html_unsafe | @html),
"",

# @sh: shell-safe quoting
"@sh quoting:",
(.strings.path | @sh),
"",

# splits: generator version of split
"splits(\",\") on csv_line:",
[.strings.csv_line | splits(",")],
"",

# utf8bytelength
"utf8bytelength of \"Hello\":",
("Hello" | utf8bytelength),
"utf8bytelength of a Unicode char:",
("é" | utf8bytelength),
"",

# ── Math ───────────────────────────────────────────────

"=== Math ===",
"",

"floor, ceil, round of pi:",
{ floor: (.numbers.pi | floor),
  ceil:  (.numbers.pi | ceil),
  round: (.numbers.pi | round) },

"fabs of -42:",
(.numbers.negative | fabs),

"sqrt(16):",
(16 | sqrt),

"pow(2; 10):",
(pow(2; 10)),

"log and exp round-trip:",
(1 | exp | log),

"sin(0), cos(0):",
{ sin_0: (0 | sin), cos_0: (0 | cos) },

"isnan and isinfinite:",
{ nan_check: (nan | isnan), inf_check: (infinite | isinfinite) },
"",

# ── Array / Object Niche ──────────────────────────────

"=== Array / Object Niche ===",
"",

# combinations: cartesian product
"combinations of colors x sizes:",
([.arrays.colors, .arrays.sizes] | [combinations] | map(join("-"))),
"",

# bsearch: binary search on sorted array
"bsearch for 7 in sorted array:",
(.arrays.sorted | bsearch(7)),
"bsearch for 6 (not found, gives insertion point):",
(.arrays.sorted | bsearch(6)),
"",

# nth: get nth generator output
"nth(2; range(10)) -- third value from 0..9:",
(nth(2; range(10))),
"",

# isempty
"isempty(empty):",
isempty(empty),
"isempty(1, 2, 3):",
isempty(1, 2, 3),
"",

# builtins: count available functions
"Number of built-in functions:",
(builtins | length),
"",

# ── Advanced Control Flow ─────────────────────────────

"=== Advanced Control Flow ===",
"",

# label-break: early exit
"label-break -- first value > 10 in sorted array:",
(label $out | .arrays.sorted[] | if . > 10 then ., break $out else . end),
"(printed 1, 3, 5, 7, 9, 11 then broke out)",
"",

# repeat: infinite generator, bounded with limit
"repeat -- 5 copies of 'lemonade':",
([limit(5; "lemonade" | repeat(.))]),
"",

# $__loc__
"$__loc__ (source location):",
$__loc__,
"",

# ── I/O and Multi-File ────────────────────────────────

"=== I/O Notes ===",
"",
"--jsonargs: pass JSON values on the command line.",
"  Example: jq -n --jsonargs '$ARGS.positional' -- '1' '[\"a\"]'",
"input_line_number: available when reading line-delimited input.",
"modulemeta: inspect metadata of imported modules.",
"",
"=== End of Appendix Demos ==="
