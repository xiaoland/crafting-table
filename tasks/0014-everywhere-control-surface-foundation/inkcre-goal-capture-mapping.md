# InKCre Goal / Capture / Session mapping

## Source facts

The actual local InKCre core path is:

```text
/Users/lanzhijiang/Development/InKCre/core-py
```

`~/Development/core-py` does not exist on this machine.

Relevant InKCre facts from code:

- `BlockModel` has `id`, `created_at`, `updated_at`, optional `storage`, required `resolver`, and required string `content`.
- `RelationModel` has `id`, `updated_at`, `from_`, `to_`, and required string `content`.
- `SubGraphForm` is a root `block` plus `out_arcs` and `in_arcs`.
- `PUT /graph` accepts `SubGraphForm`.
- `InfoBaseManager` inserts blocks first, then relations.
- `RelationManager.fetchsert()` identifies relations by `from_ + to_ + content`.
- `BlockManager.fetchsert()` delegates block identity to the block resolver's `get_existing(...)`.
- Built-in native resolvers include at least `text` and `image`.
- Extension resolver guidance says extension resolvers should be namespaced; CT mapping uses `extensions.crafting_table.*` names.

## Mapping direction

Crafting Table should map durable personal graph concepts into InKCre graph forms:

- Goal Node -> CT-specific block resolver.
- Work Session -> CT-specific block resolver with status in content.
- Capture -> either native InKCre resolver when the content is clearly native, or CT-specific capture resolver for raw/unclassified items.
- Goal edge -> relation content vocabulary.
- Session/goal link -> relation content vocabulary.
- Capture/session and capture/goal links -> relation content vocabulary.
- Remote continuity -> CT-specific block linked from Work Session.

## Current CTCore slice

`CTCore` feature `inkcre-graph` now defines:

- InKCre wire-shape structs: block, relation, in/out arc, subgraph.
- CT content structs: goal node, work session, capture, remote continuity.
- Relation content constants for goal edges, session links, capture links, and remote continuity links.
- `SessionNeighborhood` mapping for session-centered graph insertion.
- Native text capture mapping through the InKCre `text` resolver.

This is pure mapping plus a transport-injected storage API. It does not change InKCre core-py, install a CT resolver extension, or migrate `WorkspaceDocument`.

## CTCore client API

`CraftingTableInKCreApi` is the client-facing API surface.

It currently supports:

- `save_goal_node`
- `update_goal_node`
- `save_goal_edge`
- `save_work_session`
- `update_work_session`
- `save_capture`
- `update_capture`
- `load_goal_forest`
- `list_captures`

The API depends on `InKCreGraphStore`, which platform clients implement or wrap. The trait corresponds to these InKCre capabilities:

- insert subgraph through `PUT /graph`
- list recent blocks filtered by resolver
- fetch relations by block
- update block content by block id

This is intentionally transport-injected. CTCore owns graph semantics; each client still owns base URL, auth token, network stack, retries, and offline behavior.

## Update rule

InKCre graph insertion is not a content update mechanism.

Because `BlockManager.fetchsert()` returns an existing block when a resolver finds one, updating a Goal Node title, Work Session status, or Capture detail requires block-level update after the client knows the InKCre block id.

CTCore exposes update methods for those content changes.

## Resolver requirement

Because InKCre block deduplication is resolver-owned, CT-specific resolvers should dedupe by stable CT ids such as `ctId`, not by full JSON content. If the default resolver behavior is used, edits to title/status/summary would create new blocks because block content changes.

That resolver implementation is not part of the current CTCore slice. Until it exists in InKCre, inserting CT-specific graph forms will depend on resolver availability on the target InKCre deployment.

## Relation vocabulary

Current relation content constants:

- `ct:goal_edge`
- `ct:session:goal`
- `ct:capture:goal`
- `ct:capture:session`
- `ct:session:remote_continuity`

These are stable relation labels, not mutable payload carriers. Mutable state should live in block content unless a later InKCre relation-content schema is explicitly designed.
