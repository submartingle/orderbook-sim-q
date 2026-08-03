# kdb+/q Coding Guide — Style, Architecture and Language Traps

Working notes on kdb+/q: how I structure projects, the conventions I apply, and the language
traps worth knowing before they cost a debugging session. My own material, built on top of
Data Intellect's q language reference.

---

## 1. Project Code Organisation

Break code into three layers. This is the target structure for any new or refactored project:

### Libraries (`*.q` files in a `lib/` or named directory)
Discrete, reusable code living in a dedicated namespace. Each file owns one namespace.
```
latency.q     → .latency.* functions  (e.g. .latency.upd, .latency.calc)
logging.q     → .log.*    functions   (core infrastructure)
vwap.q        → .vwap.*   functions   (analytics / business logic)
```
Libraries must be self-contained: no dependency on process-level globals, no side effects on load beyond defining their namespace.

### Schemas (`schema/*.q` or a single `schema.q` per application domain)
One file per group of related tables. Think of it as "the market data application has tables A, B, C".
- Define table schemas with correct types and attributes here (see Section 3).
- Never scatter table definitions across process files.

### Processes (`proc/*.q` or top-level `tp.q`, `rdb.q`, etc.)
Load the relevant libraries and schemas. Process files are thin orchestration:
```q
system "l lib/logging.q"
system "l lib/latency.q"
system "l schema/mktdata.q"
// process-specific handlers and startup only below here
```

---

## 2. Naming Conventions

Pick **one** style and apply it consistently across the entire project. Do not mix.

**Preferred style: dot-separated lowercase for namespaced names, camelCase for local variables.**
All-caps reserved for constants only. No snake_case mixed into a camelCase file.

**Terse q names are fine for loop variables and short-lived locals; use descriptive names for anything that persists or is exported.**

**Never use a bare common English word as a variable name** (`ok`, `apply`, `has`, `cur`, `root`, `ser`, …) — even where q permits it. Many collide with q reserved words/keywords, and all of them read as prose rather than as an identifier. Instead:
- **Local, used once or twice:** one or two letters (`c`, `hR`).
- **Anything else:** a compound name that carries the meaning — turn the plain word into a phrase (`has` → `inSeries`, `root` → `symroot`, `apply` → `doPush`, `ok` → `isApproved`/`clrd`). Slightly longer and unmistakably an identifier beats short and ambiguous.

---

## 3. Schemas and Attributes

### Attribute Selection — Critical for Performance

Apply the correct attribute at schema definition time; retrofitting is expensive.

| Context | Column | Attribute | Reason |
|---|---|---|---|
| In-memory RDB / tickerplant | `sym` | `` `g# `` | Hash lookup O(1); maintained automatically on append |
| On-disk HDB partitioned table | `sym` | `` `p# `` | Binary search O(log n); q applies this automatically on standard HDB layout |
| Any sorted column (time, seq) | `time` / `seq` | `` `s# `` | Binary search on sorted data |
| Low-cardinality enum-like col | any | `` `u# `` | Unique — enables fast equality checks |

```q
// Re-apply g# after bulk backfill — appends drop the attribute
update `g#sym from `trade
```

**Never apply `p#` to a live in-memory table that receives streaming updates** — `p#` is not maintained on unsorted appends and will be silently dropped. Do NOT manually apply `p#` to an in-memory table that will be saved via `.Q.dpft` (q applies it).

### Instrument Key: `sym` vs `instrument.exchange`

Single-venue data: plain `sym` column. Multi-venue: compound key `sym` + `exch`, **or** encode as
`` `$instrument,".",exchange `` if a single symbol column is required. Choose one approach per
project and document it in the schema file. Mixed approaches within the same codebase are forbidden.

---

## 4. Namespacing

**Preferred style: use dotted namespace references inline (`.myns.fn`), not `\d` switches.**

`\d` causes problems with VS Code and other dev tools (function lookup, go-to-definition break). It also makes it harder to grep for where a function is defined when the namespace switch is in a different file section.

```q
// CORRECT — define with full dotted path
.latency.upd:{[t;x] ...}

// WRONG — \d switch (avoid)
\d .latency
upd:{[t;x] ...}    // now .latency.upd but invisible to tooling
\d .
```

**One namespace per file.** A file named `latency.q` defines only `.latency.*`.

---

## 5. Loops and Iteration — Prefer Vectorised q

**Avoid `each` when a native vectorised form exists. Never use `do`/`while` loops for data processing.**

```q
// SLOW — each drives a per-symbol scan of the full table on every iteration
bidValue: symList ! {first value sum select [10;>px] from select from `bidLiveBk where sym=x} each symList

// FAST — single vectorised pass; q handles the grouping internally
bidValue: exec sum px by sym from (select [10;>px] from bidLiveBk where sym in symList)
```

**Rule:** if you find yourself writing `{...} each someList` over a table column, ask first whether a `select ... by sym` form can replace it. It almost always can and will be 10–100× faster.

`peach` is the correct tool for CPU-bound parallelism, not `each` loops (needs `-s` slave threads;
workers cannot amend globals — `'noupdate`).

---

## 6. Comments

**q is terse. Comment anything non-obvious.** The bar is: would a competent q dev need more than 5 seconds to understand what this line does? If yes, comment it.

- Explain the *purpose* of tables/functions and any non-obvious logic (e.g. why an attribute is re-applied).
- Never comment the obvious (`// add 1 to x`).
- Function-level doc comment: one line above the function stating what it computes and its params.

---

## 7. Type System — Traps

**Symbol interning — symbols live forever:**
```q
// DANGEROUS: each unique string becomes a permanent symbol
`$string til 1000000
// SAFE: keep as strings or use enumerations for high-cardinality data
```
Keep alert/log message symbols low-cardinality by construction; high-cardinality context belongs
in dedicated typed columns, not in an interned symbol.

---

## 8. Performance

```q
// Functional select is faster than string parse in hot paths
?[`trade; enlist(=;`date;2024.01.01); 0b; ()]   // fast: pre-parsed
value "select from trade where date=2024.01.01"  // slow: re-parses every call

// Direct column access — no copy
trade`sym

// Check count before expensive aggregation
if[bound>count r:select from trade where ...; ...]

// Build lists outside loops — never extend inside do[]
```
Attributes dramatically change query cost — always apply correctly (see Section 3).

---

## 9. Error Handling

```q
// Re-raise after logging (unary trap; use .[f;args;h] for higher rank)
@[dangerousFn; arg; {.log.error x; 'x}]
```

**Nested traps — only the innermost handler fires.**

**Temporary mutation of a global inside a timer/handler (`.z.ts`, `.z.pg`, `upd`, …) is only
safe against interleaving, not against errors.** q's single-threaded run-to-completion
guarantees no other message can observe the global mid-swap — but a signal (`'type`, `'length`)
aborts the callback with NO unwind/finally, leaving the global however it was at the throw
point, and the process carries on with the next message on the corrupted state.

```q
// WRONG — swap/restore around shared machinery; an error between swap and restore
// leaves .state.tab pointing at the wrong buffer for every subsequent message
.z.ts:{saved:.state.tab; .state.tab:otherBuf; doWork[]; .state.tab:saved};

// BETTER — protected evaluation whose handler restores
.z.ts:{saved:.state.tab; .state.tab:otherBuf;
       @[doWork; (::); {[s;e] .state.tab::s; 'e}[saved]];
       .state.tab:saved};

// BEST — no global mutation at all: pass the state as an argument
.z.ts:{doWorkOn[otherBuf]};
```

---

## 10. Date and Time

```q
.z.p   // UTC timestamp (nanosecond) — use this
.z.P   // local timestamp
// Never use .z.z (deprecated datetime float)
```

**JSON null trap:** `.j.j (0N;0n;0Nd)` → `"[null,null,\"\"]"` — temporal nulls serialise to empty string, not JSON null.

---

## 11. IPC — Traps

- `hopen (`:host:5000; 2000)` — **always use a timeout in production.**
- **After SIGINT on a blocking sync call the handle is poisoned** — `hclose` and reopen; all
  subsequent calls on it give `"Bad file descriptor"`.
- **Enumerated columns are de-enumerated to raw symbols before transmission.** Never assume enum
  metadata survives an IPC round-trip.

---

## 12. Namespaces and Scope

```q
// Safe variable lookup with default — the config-at-load idiom
result: @[value; `myVar; defaultVal]

f:{a:20; a}    // local; use :: to assign a global from inside a function
```

---

## 13. Idioms and Nice Tricks

```q
x,()                             // ensure x is a list even if atom
(c:cols t) where c like "*price*" // inline assignment
d1,d2                            // dict merge — right wins on conflict
.Q.s1 x                          // format any value as string without printing
// 'value' is a reserved word — never use it as a variable name
```

**Seeded scan includes the seed; seedless scan does not** — `0 +\ 1 2 3` vs `(+\) 1 2 3`.
The most common off-by-one error with `\`.

---

## 14. Ecosystem Integration

### PyKX
- Attributes (`g#`, `p#`) are lost on conversion to Python/Pandas.
- Connections are not thread-safe — one connection per thread.
- Always set `timeout=` — default has no timeout.
- High-cardinality string data → use `CharVector`, not `SymbolVector`.

### JSON
`.j.k` round-trip loses types: symbols become strings.

### HTTP
**Default `.z.ph` evaluates arbitrary q — always override in production.**
