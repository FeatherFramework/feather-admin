# Admin UI review — 2026-10-16

Latest follow-up: Admin 0.15.0 now also implements native Menu V2 accordions,
responsive catalog filter rows and pagearrows; weapon/ammo/item catalog search;
direct status/appearance/effects navigation; retained grant quantity and bounded
grant/removal confirmations. Local Menu V2 schema tests pass. Noclip unchanged.
See PR_PREPARATION_0.15.0.md for the superseding deployment list/version refresh
requirement and live gate. Older lists below record earlier slices.

Scope: code review of navigation, players, character administration, inventory,
weapons, status tools, moderation, self tools and audit pages, plus the supplied
screenshots. This is not a complete live usability/accessibility acceptance run.
Existing server authority and fail-closed transaction rules must remain intact.

## Prioritized findings

1. **Keep the selected target visible.** `client/ui/menu.lua` (`AddHeader`) only
   renders generic headings. Player status and teleport screens depend on global
   selection without a persistent name/ID strip. Weapon grant confirmation in
   `client/ui/pages/weapons_admin.lua` shows the item/quantity but not the recipient.
   Add a consistent target name, server ID, self/offline state and breadcrumb;
   confirmations should repeat the exact recipient and effect.
2. **Separate request submission from acknowledged results.** `RunAction` in
   `client/ui/menu.lua` notifies whenever a callback returns anything except false,
   including nil from callbacks that merely send a request. The notification is
   an action label, not evidence of success. Use pending/confirmed/refused/unknown
   states and disable duplicate submissions. Unknown outcomes must not invite
   retries. Existing acknowledged toggle and evidence flows offer reusable patterns.
3. **Make high-impact actions deliberately different.** The kill entry in
   `client/ui/pages/boosters.lua` dispatches directly, whereas inventory removal
   and evidence changes have confirmation screens. Establish a shared confirmation
   pattern for destructive/high-impact actions, including target and consequences;
   keep harmless actions low-friction. Do not add privileged routes or weaken checks.
4. **Reduce navigation depth.** Player work is split among selected-player,
   character management, inventory actions, inspection, instance details and tools.
   Use a player workspace grouped by Overview, Moderation, Inventory/Weapons and
   Status. Keep self tools distinct and server/staff/developer tools secondary.
5. **Standardize large lists.** Online players, inspected instances and weapon
   catalogs do not consistently provide search, sorting, paging and empty/loading
   states. Reuse the existing paged inventory grant/audit approaches; preserve
   selection and back-navigation context.
6. **Restore visual hierarchy through supported primitives.** `AddButton`,
   `AddHtmlButton` and `AddText` accept but ignore their style argument. Pages can
   appear indistinguishable despite passing styles. Map semantic primary,
   secondary, danger and status treatments to supported Menu V2 elements; do not
   reintroduce arbitrary HTML/CSS. Supplied screenshots also show clipped metadata
   and oversized sparse message pages; panel sizing needs live verification.
7. **Handle empty permission-filtered forms.** Character administration indexes
   `operationOptions[1].value` and `fieldOptions[1].value` without local empty checks.
   Earlier permission gates reduce exposure, and economy is disabled by default,
   but permission/target changes should show an unavailable state rather than risk
   a nil-index failure. Add a focused regression before enabling this path.

## Implemented slice, not yet live accepted

Item details now show revision, serial, condition, wear and attachments as readable
fields. Raw metadata is optional, read-only, wrapped and paginated; its display is
not an export/editor. Inventory's existing inspection SELECT now includes the
existing row revision, with no extra per-item query or mutation. English labels
use the existing fallback mechanism. Evidence transaction behavior is unchanged.

Admin Lua specs/runtime syntax and Node tests pass; Inventory Lua runner passes,
including the read-only revision projection regression. Live visual readability,
keyboard/controller focus and alternate resolutions remain unverified.

## Recommended implementation order

1. Shared target/context, safe confirmation and acknowledged feedback foundation.
2. Player workspace, searchable/paged lists and preserved navigation context.
3. Form empty/error states, validation and consistent visual hierarchy.
4. Focused live walkthrough of representative tasks, resolutions and inputs.

## Implemented follow-up — 2026-10-16

User authorized Admin menu improvements before returning to Weapons and removal
of Admin-only menu styling. Implemented:

- Shared redemption preset without Admin accent, radius, sizing or position
  overrides; removed dead Styles table/call arguments and inline HTML list CSS.
  Lists use plain shared-menu text buttons. No shared Menu V2 resource change.
- Target name/ID/online-or-offline context on player, status, appearance, economy,
  inventory and weapon/ammo workflows. Offline inventory/weapon context does not
  fall back to a previously selected online player.
- Direct Inventory and Weapons shortcuts from selected player; Players first on
  the root page. Existing routes and authority checks retained.
- Online players and inspected inventory have literal name/ID filtering and
  bounded 15-entry paging, counts, empty states and refresh.
- Kill and non-toggle special effects require target-bound one-shot confirmation.
  Changing target/page/open lifetime prevents old confirmation dispatch.
- Generic RunAction only emits local success-label notification for explicit true,
  not nil request submission. Server-owned result messages remain authoritative;
  this is not a new universal acknowledgement protocol for all legacy actions.
- Economy form handles an empty target-permission option list safely.
- Noclip HUD retains its original gold/border/shadow/typeface styling by explicit
  user preference. It is separate from the shared Admin menu presentation.

Five Lua specs, runtime Lua syntax and seven Node tests PASS. New mocked UI tests
cover shared defaults, online/offline target labels, notification semantics,
duplicate/stale target confirmations and player paging/filtering. Not live accepted.
Further workspace restructuring, catalog search, broader form preservation and
full controller/accessibility/resolution walkthrough remain deferred.

Do not rerun accepted evidence/payment matrices solely for presentation changes.

## Current presentation deployment delta

- feather-admin: `client/ui/pages/inventory.lua`,
  `client/services/inventory.lua`, `server/services/inventory.lua`,
  `translations/en_us.lua`.
- feather-inventory: `server/controllers/inventory.lua`.

No config replacement, manifest change, new runtime script, web build or refresh.
Prepare-stop Weapons and wait for PASS before stopping it, restart Inventory with
the projection change, restore dependent Admin/Shops with the Admin files, then
ensure Weapons. Leave evidence transactions disabled for the read-only visual
check. This list is the current presentation delta, not all accumulated branch work.

### Follow-up menu deployment (includes prior presentation delta)

From `C:/coding/feather-scripts/feather-admin`:

```text
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

From `C:/coding/feather-scripts/feather-inventory`:
`server/controllers/inventory.lua` (prior inspection revision projection).

Noclip HTML is unchanged from its original styling and need not be deployed unless
the temporary unstyled version was already copied; in that case copy
`web/noclip.html` to restore it.

Restart Admin after copying. If the Inventory projection is not deployed, first
prepare-stop Weapons with the current source ID and wait for PASS, stop Weapons,
restart Inventory and restore dependent Admin/Shops, then ensure Weapons. No new
feature flag; preserve configs and leave evidence transactions off during review.
Live check: root/player navigation, list filter/paging/refresh, target context,
readable item/raw metadata, Kill confirmation cancellation (do not execute),
noclip HUD readability/exit, menu close/back/focus. No destructive test required.
