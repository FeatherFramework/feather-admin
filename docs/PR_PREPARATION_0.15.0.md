# Feather Admin 0.15.0 — PR preparation

Status: implemented and automatically tested; ready for focused live UI review,
not yet live-accepted or merged. No commit, push or pull request created.

## Proposed title

```text
feat(admin): improve menu usability and add scoped weapon evidence controls
```

## Proposed summary

```text
- Use shared Menu V2 styling with grouped player actions, responsive filter rows and native pagination.
- Add searchable player, inventory, weapon and ammunition lists with clear target context and simpler navigation.
- Show readable weapon details and optional read-only metadata; guard high-impact confirmations against repeat/stale clicks.
- Integrate administrator-scoped native weapon evidence controls with expiring previews, normal authority checks and audit feedback.
- Preserve noclip styling and bump Admin to 0.15.0.
```

## Reviewed scope

- Earlier evidence integration remains part of the accumulated Admin diff:
  90 capabilities, administrator/owner evidence grants, own-current-item scope,
  default-off Weapons evidence mutation opt-in, one-use preview tickets, unknown
  results without automatic retry, explicit provenance reasons and audit enqueue.
- Current UI uses Menu V2's existing accordion, section, row and pagearrows
  contract. Reviewed/tested against local Menu V2 `2.0.0-alpha.8`; no provider
  edits or frontend build. Install matching prepared Menu V2 runtime if the server
  predates these layout features; old bundles are not validated by these tests.
- Selected-player sections expose Inventory/Weapons, overview/moderation and
  player tools directly; staff/effects groups start collapsed. Character management
  retains economy/model operations; duplicate Inventory/Weapons entries removed.
- Catalog search is literal name/definition-ID filtering, privately sorted and
  bounded to 15 entries/page. Existing unique-item grant restrictions remain.
- Inventory quantity survives review/back. Grant/removal confirmations capture
  target/selection/menu lifetime and allow one dispatch per rendered confirmation.
  This is not a new server idempotency contract or universal pending protocol.
- No CSS added. Admin menu theme overrides removed; original noclip HUD retained.
- Existing `allowSelf['booster.kill']=true` is a pre-existing branch change from
  earlier death testing, not a new requirement of this UI. Review this policy
  explicitly before production; the dev helper remains default-off.

## Verification

- Five Lua specs PASS: dev self-kill, evidence authority, evidence server,
  evidence client and menu usability. Dependencies are mocked at their boundaries.
- Runtime/config/translation Lua and manifest syntax PASS.
- Seven Node tests PASS; `git diff --check` PASS.
- Usability tests validate emitted element settings using the actual local Menu V2
  validator, plus section ordering, shared defaults, private sorting, literal
  search/empty/clamped paging, selected entry, quantity retention, duplicate/stale
  confirmations, online/offline context and no submission-as-success toast.
- Prior Inventory revision projection regression passed its Lua runner.
- Prior own-current evidence UI hold/release live gate accepted 2026-10-15;
  that does not prove this later layout is live accepted. Audit enqueued is not
  independently verified durable audit delivery.

## Server deployment — current UI/version delta

Repository `C:/coding/feather-scripts/feather-admin`:

```text
fxmanifest.lua
client/ui/menu.lua
client/ui/pages/active_bans.lua
client/ui/pages/announcements.lua
client/ui/pages/boosters.lua
client/ui/pages/character_administration.lua
client/ui/pages/inventory.lua
client/ui/pages/main.lua
client/ui/pages/moderation.lua
client/ui/pages/player_notes.lua
client/ui/pages/players.lua
client/ui/pages/reports.lua
client/ui/pages/staff_management.lua
client/ui/pages/trolls.lua
client/ui/pages/weapons_admin.lua
client/services/inventory.lua
server/services/inventory.lua
translations/en_us.lua
```

Repository `C:/coding/feather-scripts/feather-inventory`, only if the prior
inspection revision projection has not been deployed:

```text
server/controllers/inventory.lua
```

Noclip HTML is unchanged; no copy needed unless restoring the temporary unstyled
version. Tests/docs do not go to the runtime server.

This is incremental to the already-tested evidence deployment. A full branch
installation also contains Admin `server/services/authority_catalog.lua`,
`server/services/authority_contract.lua`, `server/services/policy_provider.lua`
and exact policy additions in `configs/permissions.lua` and `configs/hierarchy.lua`.
Merge policy keys only; never replace customized configs wholesale. Matching
Weapons evidence exports and native Inventory services are companion dependencies,
not files to silently include in the Admin PR.

Because the version changes the manifest, run server-console `refresh` before
restarting Admin. If Inventory also needs restarting, prepare-stop Weapons using
the current player source, wait for PASS, stop Weapons, deploy/restart Inventory,
restore dependent Admin/Shops, then ensure Weapons. No new feature flag required.
Keep `feather_native_evidence_transactions` off during this read-only UI check.

## Remaining live gate

1. Open Admin: shared theme, natural height, close/back/focus and target name/ID.
2. Open a player: grouped actions visible; staff/effects collapse/expand locally;
   Inventory/Weapons and status/appearance have direct access and sensible Back.
3. Search players and catalogs by name/ID; empty search, pagination and Back keep
   useful context. Check narrow window row stacking and native page arrows.
4. Inspect a firearm: readable serial/revision/wear and optional raw metadata;
   no horizontal clipping. Review a grant then Back: quantity retained. Cancel
   Kill/effects/removal confirmation; do not execute destructive actions.
5. Noclip still shows original HUD and exits normally. Check keyboard/controller
   focus on actual host/device; automated Lua tests do not establish device support.

Do not repeat accepted Weapons payment/evidence matrices for this UI-only gate.
Cross-owner custody, destruction, broad legacy acknowledgement/idempotency redesign,
all-locale translation completion and a full tab/stepper conversion are excluded.
