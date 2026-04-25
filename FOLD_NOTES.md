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
