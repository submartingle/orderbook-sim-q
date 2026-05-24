# kdb+/q Coding Guide — Key Patterns and Traps

A distilled reference for writing idiomatic, correct q. Covers language behaviour,
performance, and ecosystem integration. 

---

## 1. Type System

### Type Code Quick Reference

| Type# | Name | Null | Infinity | Example |
|---|---|---|---|---|
| -1h | boolean | `0b` | — | `1b` |
| -6h | int | `0Ni` | `0Wi` | `42i` |
| -7h | long | `0N` | `0W` | `42` |
| -9h | float | `0n` | `0w` | `1.5` |
| -11h | symbol | `` ` `` | — | `` `sym `` |
| -12h | timestamp | `0Np` | `0Wp` | `2024.01.01D00:00:00` |
| -14h | date | `0Nd` | `0Wd` | `2024.01.01` |
| -16h | timespan | `0Nn` | `0Wn` | `0D00:01:00.000000000` |
| -17h | minute | `0Nu` | — | `00:01` |
| -19h | time | `0Nt` | — | `00:01:00.000` |
| 0h | mixed list | — | — | `(1;2.0;"a")` |
| 98h | table | — | — | `([]a:1 2 3)` |
| 99h | dictionary | — | — | `` `a`b!1 2 `` |

Negative type code = atom. Positive = vector. `type 42` → `-7h`. `type 42 43` → `7h`.

### Key Type Traps

**Null comparison — never use `=`:**
```q
0N = 0N    // 0b — null is never equal to anything, including itself
null 0N    // 1b — always use null[] to test for null
null each (0N; 1; 0n; 0Ni)  // 1b 0b 1b 1b
```

**Downcast overflow wraps to null silently:**
```q
`int$2147483648   // 0Ni (overflow — no error raised)
`short$40000      // 0Nh
```

**Mixed list promotion:**
```q
type 1 2 3     // 7h — long vector
type 1 2 3.0   // 9h — promoted to float because of 3.0
type (1;2.0)   // 0h — parens prevent promotion → mixed list
```

**Empty typed list:**
```q
type ()         // 0h — generic empty
type `long$()   // 7h — typed empty (has a type, count is 0)
```

**String is a char vector:**
```q
type "abc"           // 10h — char vector (string)
type ("a";"b";"c")  // 10h
```

**Symbol interning — symbols live forever:**
```q
// DANGEROUS: each unique string becomes a permanent symbol
`$string til 1000000

// SAFE for high-cardinality data: keep as strings or use enumerations
string til 1000000
```

**Symbols with hyphens can't use backtick syntax:**
```q
// WRONG — parse error
`GBP-USD

// CORRECT
`$"GBP-USD"
```

**Negating a variable — use `neg`, not unary `-`:**
```q
x: 5
-x      // 'type error — `-` expects a literal, not a variable name
neg x   // -5 — correct
```

### Casting

```q
`float$42          // 42f — upcast (safe)
`$"hello"          // `hello — string to symbol
9h$3               // 3f — cast by type code
-7h$3.7            // 3  — truncates (does not round)

// Dates are ints offset from 2000.01.01
`int$2000.01.01    // 0
`int$2000.01.02    // 1
2000.01.01+1       // 2000.01.02
```

---

## 2. Iterators

### Each (`'`)

```q
f each 1 2 3              // apply f to each element → list
{x+y}'[1 2 3; 10 20 30]  // binary each — both lists must match in length → 11 22 33

// Each-right: fix left arg, iterate right
"abc" ,/: ("x";"y")      // ("abcx";"abcy")

// Each-left: fix right arg, iterate left
("x";"y") ,\: "abc"      // ("xabc";"yabc")
```

`like` is already vectorized over a symbol list — `symlist like "pat*"` returns a boolean
vector. `like\:` with a single string pattern on the right is redundant.

### Over and Scan (`/` and `\`)

```q
// Over — reduce to a single value
(+/) 1 2 3 4 5     // 15 (no seed: first element used as seed)
0 +/ 1 2 3 4 5     // 15 (explicit seed 0)
1 +/ 1 2 3         // 7  (seed=1: 1+1+2+3)

// Scan — all intermediate values
(+\) 1 2 3         // 1 3 6 (no seed — excludes it)
0 +\ 1 2 3         // 1 3 6 (explicit seed 0 — included in result)

// Convergence: apply until result stops changing
{x*x}/ [0.5]        // 0.0 (converges)

// N-times: apply exactly N times
3 {x*2}/ 1        // 8 (1→2→4→8)

// Until: apply while condition holds (condition is FALSE to continue)
{x<1000} {x*2}/ 1 // 1024
```

**Seeded scan includes the seed; seedless scan does not. This is the most common
off-by-one error with `\`.**

### Each-Prior (`':`)

```q
(-':) 1 3 6 10    // 1 2 3 4 — differences (implicit prior = 0)
1 -': 1 3 6 10   // 0 2 3 4 — explicit prior seed of 1
```

### Parallel Each (`peach`)

```q
// Requires slave threads: q myfile.q -s 4
{expensive_fn x} peach large_list
```

- Workers receive a copy of the process state at fork time — global modifications
  inside a `peach` worker are lost when results are merged back.
- Not worth it for fast, small operations — serialization overhead dominates.

---

## 3. Performance

**Attributes dramatically change query cost:**
```q
// Without attribute: O(n) linear scan
select from trade where sym=`AAPL

// `g# (grouped, hash): O(1) amortised — use for in-memory tables
update sym:`g#sym from `trade

// `p# (parted, sorted): O(log n) binary search — use for on-disk partitioned data
// applied automatically on `sym in a standard HDB layout
```

**Column access vs table query:**
```q
trade`sym          // direct column access — no copy, O(1)
exec sym from trade // full table scan — slower
```

**Check count before expensive operations:**
```q
if[count r:select from trade where ...;
   // expensive aggregation
  ]
```

**Build lists outside loops:**
```q
// Slow: extends global list on every iteration (reallocates each time)
r:(); do[1000; r,:enlist f[]];

// Fast: compute all at once
r:f[] each til 1000
```

**Functional select is faster than string parse in hot paths:**
```q
// Slow: re-parses the string every call
value "select from trade where date=2024.01.01"

// Fast: pre-parsed functional form
?[`trade; enlist(=;`date;2024.01.01); 0b; ()]
```

**Symbol operations over string operations:**
```q
// Slow: convert to string to match
select from t where string[sym] like "AAPL*"

// Fast: symbol membership
select from t where sym in `AAPL`AAPLV
```

---

## 4. Error Handling

```q
// Unary trap: @[function; arg; error_handler]
result:@[{1+`a}; ::; {0N}]       // returns 0N on error
@[f; arg; {.lg.e[`label;x]}]     // log error and continue

// Binary trap: .[function; arg_list; error_handler]
.[f; (x;y;z); {'"rethrow: ",x}]  // re-signal with context

// Signal an error
'`myerror           // signal a symbol error
'"message string"   // signal a string error

// Re-raise after catching
@[dangerousfn; arg; {'x}]
```

**Scoping — error handler fires in its own scope:**
```q
a:1;
@[{a::2; error}; ::; {a::3}];
a  // 3 — handler ran and set a to 3
```

**Nested traps — only the innermost fires:**
```q
f:{@[{1+`a};::;{"inner: ",x}]}
@[f;::;{"outer: ",x}]   // "inner: type" — outer trap never fires
```

---

## 5. Date and Time

**Time type arithmetic rules:**
```q
2024.01.02 - 2024.01.01        // 1 — date minus date is an INT, not a date
2024.01.01 + 1                 // 2024.01.02 — adding int to date gives date
2024.01.01 + 1.0               // type error — float + date is not allowed

12:00:00.000 + 00:01:00.000000000  // 12:01:00.000 — time + timespan = time
12:00:00.000 + 00:01           // 12:01:00.000 — time + minute = time
```

**Timestamp vs datetime — prefer timestamp:**
```q
.z.p   // current UTC timestamp (nanosecond precision) — use this
.z.P   // current local timestamp
.z.z   // UTC datetime (float, millisecond) — deprecated
```

**Extracting parts:**
```q
`date$.z.p    // date part of a timestamp
`time$.z.p    // time part (as time type)
`second$.z.p  // seconds since midnight
```

**Null timestamp trap:**
```q
0Np = 0Np    // 0b — null != null (use null[] instead)
null 0Np     // 1b
```

---

## 6. IPC

```q
h:hopen `:host:5000        // open sync handle (blocks forever by default)
hopen (`:host:5000; 2000)  // with 2000ms timeout — always use in production
hclose h

h "q expression"           // sync call — blocks caller until result returned
neg[h] "q expression"      // async call — fire and forget, no result
neg[h] (::)                // flush async queue
h (::)                     // sync barrier — ensures prior async messages processed
```

**Deferred sync pattern (async send, then block for reply):**
```q
neg[h] (`.remote.fn; arg)
result:h[]   // block until remote sends back a result
```

**Message ordering:**
- All messages on a single handle are strictly sequential.
- A sync call on handle `h` guarantees all prior async messages on `h` were sent first.

**IPC and enumerations:**
- Enumerated columns are automatically de-enumerated to raw symbols before transmission.
  Never assume enum metadata survives an IPC round-trip.

**Compression:**
- Automatically applied for messages >2000 bytes when not on localhost.

**After SIGINT on a blocking sync call:**
- The handle is poisoned. Always `hclose` and reopen — subsequent calls on the same
  handle give "Bad file descriptor".

**Serialisation:**
```q
-8! x   // q value → bytes
-9! x   // bytes → q value
```

---

## 7. Namespaces and Scope

```q
\d .myns       // switch to namespace — all definitions below are .myns.*
myfunc:{x+1}  // becomes .myns.myfunc

\d .            // return to root

// \d persists for the rest of the file — always close with \d .
```

**Local variables shadow globals:**
```q
a:10
f:{a:20; a}   // local a=20, root a unchanged → returns 20
a              // still 10

g:{a::20}      // :: assigns to global
g[]; a         // 20
```

**Max 8 parameters per function:**
```q
{[a;b;c;d;e;f;g;h] ...}   // OK
{[a;b;c;d;e;f;g;h;i] ...} // 'params error
// Workaround: pass a dictionary as single arg
{[cfg] cfg[`a]+cfg[`b]} [`a`b!1 2]
```

**`value` with default (safe variable lookup):**
```q
result:@[value;`myvar;defaultval]   // returns myvar if defined, else defaultval
```

---

## 8. Common Idioms

```q
// Null-fill
42^0N                         // 42 (fill null with 42)
0^0N                          // 0

// Symbol list ensure (never assume atom vs list)
x:x,()                        // guarantees x is a list even if it was an atom

// Inline assignment (useful to avoid repeating an expression)
(c:cols t) where c like "*price*"

// In-place table update
update col:value from `mytable where condition

// Functional select
?[t; where_clauses; by_clause; col_dict]
// where_clauses: list of (op; col; val) triples, e.g. enlist(=;`sym;`AAPL)
// by_clause: 0b for no grouping, dict for grouping
// col_dict: ()!() for all columns, or dict of name→expression

// Functional update
![t; where_clauses; 0b; col_update_dict]

// Direct column access (no copy)
t`col1                         // returns column as vector

// exec to extract a scalar or vector from a table
exec max price from trade
exec avg size by sym from trade  // returns a dict

// Safe dict merge (right wins on conflict)
d1,d2

// Generate sequential symbol labels
`$"prefix_",/:string 1+til 5   // `prefix_1`prefix_2`prefix_3`prefix_4`prefix_5

// String formatting
"value: ",(string 42)
.Q.s1 value                   // format any value as string without printing
```

---

## 9. Ecosystem Integration

### PyKX (Python ↔ kdb+)

```python
import pykx as kx

# IPC client
with kx.SyncQConnection(host='localhost', port=5000,
                        username='u', password='p',
                        timeout=30) as q:
    df = q('select from trade where date=.z.d').pd()

# Embedded q (run q inside Python process)
result = kx.q('{x+y}', 1, 2)
kx.q.system.load('/path/to/myfile.q')
```

**Key limitations:**
- Attributes (`g#`, `p#`) are lost through Python round-trips.
- Enumerations are de-enumerated on transmission.
- Connections are not thread-safe — one connection per thread.
- High-cardinality string lists → use `CharVector`, not `SymbolVector` (symbols intern permanently).
- Always set `timeout=` — the default has no timeout.

### JSON

```q
.j.j x    // q value → JSON string
.j.k x    // JSON string → q dict/table

// Pitfalls:
// .j.k round-trip loses types: symbols become strings
.j.k .j.j `a`b`c    // ("a";"b";"c") — strings, not symbols

// Nulls lose type information
.j.j (0N;0n;0Nd)    // "null","null","null"

// JS loses precision on longs > 2^53 — string-encode large IDs

// Timestamps become ISO strings
.j.j 2024.01.01D00:00:00  // "2024-01-01T00:00:00.000000000"
```

### HTTP / REST

```q
// Outbound GET / POST
.Q.hg `$":http://api.example.com/data"
.Q.hp[`$":http://api.example.com/data"; "application/json"; .j.j mydata]

// Inbound — override .z.ph (GET) and .z.pp (POST)
.z.ph:{
  url:first "?" vs x;
  result:.j.j select from trade where date=.z.d;
  .h.hn["200 OK"; "application/json"; result]}

// WARNING: default .z.ph evaluates arbitrary q — always override in production
```

### WebSockets

```q
// Server-side handler
.z.ws:{[msg]
  data:$[-8h=type msg; -9! msg; .j.k msg];  // handles binary or JSON text
  // process and reply
  neg[.z.w] .j.j response}

// Open/close callbacks
.z.wo:{[h] / WebSocket opened — register h}
.z.wc:{[h] / WebSocket closed — clean up h}

// Broadcast to all subscribers
{neg[x] -8! msg} each handles
```

**WebSocket message format:**
- Byte vector (`-8h`): serialised kdb+ — deserialise with `-9!`.
- Char vector (`10h`): text/JSON — parse with `.j.k`.

---

## 10. Error Reference

| Error | Likely Cause |
|---|---|
| `'type` | Wrong type passed; often numeric literal needed instead of variable — use `neg x` not `-x` |
| `'length` | Conformability mismatch in vector operation |
| `'domain` | `til -1`, enum lookup failure, out-of-range cast |
| `'value` | Undefined variable or function; check namespace with `\d` |
| `'wsfull` | Out of memory; call `.Q.gc[]`, check `.Q.w[]` |
| `'conn` | Too many connections (pre-4.1t limit: 1022) |
| `'stack` | Recursion too deep; replace with iterators |
| `'params` | More than 8 named parameters in a function |
| `'assign` | Attempt to modify a read-only/constant table |

---

## 11. Quick Diagnostic Commands

```q
type x                   // type code of x
meta t                   // column types and attributes of table t
cols t                   // column names
tables`.                 // tables in root namespace
.Q.w[]                   // memory: used/heap/peak/limit
.Q.gc[]                  // force garbage collection
\v                       // all variables in current namespace
\f                       // all functions in current namespace
\t expr                  // time expression in milliseconds
\ts expr                 // time and space (ms + bytes allocated)
-8! x                    // serialised byte count (size of x over IPC)
```
