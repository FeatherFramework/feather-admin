# Admin regression audit — 2026-10-17

Scope: compare HEAD98a2def/#39 to parent584e360, review menu/provider/authority
contracts, run existing tests and a read-only before/after permission-profile
render harness. User clarified Jane is administrator. No runtime fixes, role
changes, grants, commits or server mutations were made by this audit.

## Reported missing tools

### Role management: intentional permission restriction, not removed

Both revisions require owner for staff.view/search/history/role.assign and
roles.assignment.manage. Jane's administrator role does not include these
capabilities under shipped defaults. Selected-player Staff Role remains in
players.lua70–77 (collapsed Staff oversight section); Staff Directory remains
registered under main Staff oversight. Server authorization/self/hierarchy rules
remain. Do not restore visibility by weakening permissions or promoting John.

### Ordinary item grants: moved, not removed; live absence unexplained

The earlier path was Players → selected player → Character Management → Inventory.
The new path is Players → selected player → Inventory and equipment → Inventory
→ Give Item. The old Character Management shortcuts were removed rather than
redirected, a discoverability regression. Inventory and equipment starts expanded.

players.lua27–32 retains the target-setting callback; inventory.lua49–63 renders
Give Item for an online target with inventory.give. The shipped role is
administrator in both revisions. A read-only Lua render harness with the actual
old/new menu, pages and permissions produced this matrix identically:

| Profile | Inventory entry | Give Item to online target | Weapons/Ammo entry | Staff Role |
|---|---|---|---|---|
| Moderator | yes | no | no | no |
| Administrator | yes | yes | yes | no |
| Owner | yes | yes | yes | yes |

This is mocked UI/schema evidence, not a screenshot of the deployed build or
Jane's live effective permissions. If Give Item is absent on the selected-online
target Inventory page, inspect actual permissions/deployed files/UI errors.
Do not assume it is permission-correct merely because the role label says admin.

Unique item definitions are deliberately excluded from generic grants; firearms
must use their issuer. That exclusion predates #39. Loose ammunition remains a
separate ordinary grant; it must not directly credit carried native pools.

## Confirmed cross-resource blocker to the requested weapon test

Admin weapon issuance is still wired to Weapons IssueWeapon → IssuanceService →
InventoryAdapter.CreateWeapon. Native-alpha startup in Weapons server/main.lua
returns before installing that legacy provider. InventoryAdapter therefore refuses
CreateWeapon/ListWeaponsForCharacter in this mode. Issuance also builds legacy
loaded/reserve/chambered ammo metadata, not the character-owned ammo shape.

The native capability response can be ready while Admin's catalog checks only
ready, not issuance support. Thus a qualified owner may see an Issue Weapon action
that cannot complete against native alpha. Administrator additionally lacks
weapons.issue by default. This is a native-cutover integration gap, not a role UI
deletion caused by #39. Correct fix needs a native-compatible idempotent issuer
and truthful per-feature UI; never reinstall the hybrid provider or bypass serial,
ownership, payment/request binding, provenance or character ammo constraints.

My earlier advice to grant John's Cattleman through Jane's Admin menu overlooked
both this restriction and administrator's lack of issuance authority.

## Broader UI and action audit

- No AdminUI action/page function was removed in #39. Only AddHtmlButton was
  removed; no remaining Admin callers or AdminUI.Styles references exist.
- Player tools were flattened: status, appearance and special effects now open
  directly from selected player. Old selected-player-tools function still exists.
- Inventory inspection/removal, notes/archive, bans/unban, moderation, reports,
  cases, announcements, overview, audit, staff search and role confirmation routes
  remain. The changed files preserve their server request actions.
- Noclip implementation/style was not changed by #39.
- Economy and character.restore_model are disabled by shipped identity config;
  they were not lost in this UI change. Self role assignment remains prohibited.
- Staff/special-effect accordions default closed; this can look like removal.
  Local Menu V2 renderer supports the section keys and true/false value contract.
- Older deployed Menu V2 builds without accordion/section/row/pagearrows support
  can fail during page construction. Admin does not preflight these layout
  features, so dependency skew is a real diagnostic risk, not a proven live cause.
- Inventory's contract discovery runs at Admin startup; provider shutdown clears
  readiness. Its lack of an in-place reacquisition path predates #39; ensure
  Admin is restarted after provider recovery. Do not silently infer this happened
  on the user's server. Hidden UI entries and provider RPC refusals are distinct.
- Generic catalog/inspection replies have no request/target correlation, unlike
  evidence's lifetime-bound handshake. Late replies can reopen stale workflows;
  this is an existing asynchronous UX risk, not newly removed functionality.

## Verification and limits

All five Admin Lua specs,101 runtime/config/translation Lua syntax checks, and
seven Node tests pass. Existing usability tests validate local Menu V2 schemas,
paging/filtering, target context and one-shot confirmations. The additional
ephemeral old/new render harness tested moderator/administrator/owner visibility.
This was not a live NUI visual test, real Authority role/session query, actual
item grant, exhaustive callback end-to-end test or proof that every server action
is healthy. No new server files need copying for this report.

## Recommended fixes, not applied

1. Improve discoverability with explicit Inventory/Give item shortcuts or old-path
   redirects and visible permission/feature-unavailable explanations.
2. Make weapon catalog/action availability follow explicit provider features;
   implement native-compatible issuance as a separate Weapons/Inventory slice.
3. Add permission-profile navigation regressions (including online/offline/self),
   dependency-feature checks, and correlated catalog/inspection responses.
4. Verify the deployed selected-online-player page and effective inventory.give
   permission before attributing Jane's missing ordinary grant to this commit.

Do not automatically broaden role-management or issuance permissions.
