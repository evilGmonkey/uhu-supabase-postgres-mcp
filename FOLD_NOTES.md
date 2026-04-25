# supabase-mcp fold notes

Folded from `evilGmonkey/uhu-supabase-postgres-mcp` on 2026-04-25.

## Provenance chain

This is the third generation of the same idea. The two predecessors are
both archived and superseded by what's in this directory:

- `AGL-AOF-AFCOM/uhu-postgres-mcp` — earliest prototype, gh-archived.
- `Uhurulabs/uhuru-supabase-mcp-server` — second cut, gh-archived. Its
  README points at `evilGmonkey/uhu-supabase-postgres-mcp` as the
  successor; that successor is now folded here.

## What was skipped

- `.specstory/` — Cursor conversation history (~17 KB). Greybook excludes
  specstory from secret scanning globally and we don't ship it.

## Layout note

The upstream repo had a doubly-nested layout: an outer wrapper (README,
mcp.json, TODO.md, TESTING_CURSOR.md) pointing at an inner
`supabase-postgres-mcp-server/` with the actual server. That structure is
preserved here verbatim. Flattening (collapsing the inner directory up)
is a future cleanup if the duplication starts to bite.

## Publishing public updates

Greybook is now the source of truth; the public repo at
`https://github.com/evilGmonkey/uhu-supabase-postgres-mcp` is a one-way
mirror. Run from the greybook repo root after committing changes here:

```bash
git subtree push --prefix=tools/supabase-mcp \
  git@github.com:evilGmonkey/uhu-supabase-postgres-mcp.git master
```

Do not commit directly to the public repo. If `subtree push` fails because
the public repo has diverged, reset it via force-push:

```bash
git subtree split --prefix=tools/supabase-mcp -b export-supabase-mcp && \
  git push -f git@github.com:evilGmonkey/uhu-supabase-postgres-mcp.git \
    export-supabase-mcp:master && \
  git branch -D export-supabase-mcp
```
