# Bug Report: Diff parser crashes with exit 2 on deleted SQL comments starting with `-- `

**Repository:** `luckyPipewrench/pipelock`  
**Affects:** `pipelock git scan-diff` (v3 / commit `71764c7c99cb772693d6d7e5cf4af00cc38df94a`)

---

### Description

When using `pipelock git scan-diff` (or the GitHub Action with `scan-diff: 'true'`), the diff parser crashes with exit code 2 and the following error:

```
ERROR: unverifiable input: content outside unified diff hunks
scan produced no verified result: unverifiable input: content outside unified diff hunks
```

This occurs whenever a PR diff contains deleted lines from a SQL file that begin with a standard SQL line comment `-- ` (for example, `pg_dump` headers in PostgreSQL schemas like Rails `db/structure.sql`: `-- Name: ...`).

### Root Cause Analysis

In a unified diff, deletions inside a hunk are prefixed with `-`. When a line in the original file begins with a SQL comment (`-- Name: ...`), the diff representation becomes:
```diff
--- Name: some_table; Type: TABLE; Schema: public; Owner: -
```

Because file headers in unified diffs start with `--- a/<filename>`, Pipelock's diff tokenizer/parser appears to treat any line starting with three dashes (`--- `) as the beginning of a file header rather than a deleted hunk line (`-` + `-- Name:`). Because this line appears inside an open hunk, Pipelock treats the input as corrupt/malformed and terminates execution with exit code 2 (`unverifiable input: content outside unified diff hunks`).

Furthermore, specifying `--exclude db/structure.sql` (or `exclude-paths: db/structure.sql` in `action.yml`) does **not** prevent this failure because:
1. `pipelock git scan-diff` parses the entire stream from `stdin` strictly before applying file-level path exclusions.
2. The GitHub Action `action.yml` executes `git diff "origin/${BASE_REF}...HEAD" | pipelock git scan-diff ...` without passing pathspec exclusions to `git diff`.

### Minimal Reproducer

Run the following command in a terminal:

```bash
echo -e "diff --git a/test.sql b/test.sql\nindex 1111111..2222222 100644\n--- a/test.sql\n+++ b/test.sql\n@@ -1,3 +1,2 @@\n- -- Name: schema_migrations; Type: TABLE;\n SELECT 1;" | pipelock git scan-diff --json
```

**Actual output:**
```
ERROR: unverifiable input: content outside unified diff hunks
scan produced no verified result: unverifiable input: content outside unified diff hunks
```
Exit code: `2`.

**Expected output:**
Pipelock parses `- -- Name: ...` as a deleted line within the hunk `@@ -1,3 +1,2 @@`, completes the scan, and reports exit 0 (clean).

### Suggested Fix

1. In the diff lexer/parser, ensure that state tracking inside an active hunk takes precedence: if the parser is currently inside a hunk, a line starting with `-` should be consumed as a hunk line (even if subsequent characters are `-- `), unless an explicit header pattern (`diff --git` or `--- a/` / `+++ b/` outside hunks) is encountered.
2. In `action.yml`, consider forwarding `PIPELOCK_EXCLUDE` to `git diff` as pathspec exclusions (`-- . ':(exclude)path1' ':(exclude)path2'`) to avoid feeding excluded files into the scanner diff stream.
