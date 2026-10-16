# Evidence controls in Inventory inspection

2026-10-16 presentation follow-up: raw JSON is no longer the default details view.
Readable revision, serial, condition, wear and attachments plus separate read-only
wrapped/paged metadata implemented and automatically tested; live layout still
pending. Evidence transaction scope/accepted result is unchanged. See
PR_PREPARATION_0.15.0.md for the current release/deployment instructions; older
deployment paragraphs below are chronological test records, not the full delta.

LIVE gate accepted2026-10-15: UI hold committed image/Admin audit queued, UI
release SQL:6857/8queries committed/Admin audit queued; status135rev19/clear/
reservationnone/unequipped/unbound/serial+wear unchanged. Ledger10hold/11release
persisted with reasons. Details clear state screenshot. Audit queue is not
independent durable Admin audit acceptance. Earlier failed attempt cause remains
unknown. Final output optin1; set feather_native_evidence_transactions0. No more
files/repeated live transaction needed. Raw metadata details text clips: separate
presentation issue, not transactional failure. Own current actor only.

Live checkpoint: disabled preview screenshot accepted135rev17/clear/correctserial.
User clicked hold confirmation after enabling, generic refusal; independent status
still135rev17/evidencefalse/reservationnone and history6-9 only, so no committed
hold. Exact cause unknown. Independent expiry UX fix now disables stale visible
confirmation after30s; server logs actual refusal stage/native reason, explicit
missing/expired/consumed UI text. Tests pass. Incremental deployment ONLY Admin
server/services/inventory.lua,client/services/inventory.lua,translations/en_us.lua;
restartAdmin/no refresh/Weapons or Inventory restart. Fresh preview, confirm within
30s once; capture server evidence confirmation REFUSED reason on failure, no
blind retries. Do not label earlier refusal expired without matching log.

2026-10-15 implemented/automatically tested, live UI pending. Own current-character
native firearm only; no cross-character police custody or destruction controls.

Inventory instance details show evidence state and a Weapon evidence button for
permitted self-targets. Preview reads authoritative state/permissions/revision and
issues a private server ticket expiring30s. Explicit confirmation sends only
ticket/operation/target, never client metadata/serial mutation authority. Server
consumes ticket before yielding, rechecks permission/self-hierarchy/current session,
and sends expectedRevision to Weapons exact reserved transaction. Unavailable/
unresolved and timeout states offer no mutation/retry button. Late results cannot
reopen closed/navigated/changed-target pages. Confirmed mutation with failed
Weapons provenance is shown as committed-with-warning, not retryable failure.
Admin records ordinary target audit on acknowledged success.

## Deployment

Weapons existing file: server/services/evidence.lua (trusted Admin read export,
stale expectedRevision veto, explicit evidence provenance reason).

Admin existing files:

- server/services/inventory.lua
- client/services/inventory.lua
- client/ui/pages/inventory.lua
- translations/en_us.lua (English labels; existing fallback for other locales)
- configs/hierarchy.lua: merge allowSelf weapons.evidence.hold/release=true only.

PrepareStop current ID, waitPASS, stopWeapons, copy/merge preserving configs.
Restart Admin, set feather_native_evidence_transactions0, ensureWeapons. Existing
files/no refresh/Inventory restart/new manifest/UI asset build required.

First live check: Admin select own Jane→Inventory inspection→existing Carbine135
details→Weapon evidence. Expect clear state, correct serial/revision (last17),
no confirm action while optin0. Stop for user observation/screenshot; no mutation.
Then one focused UI hold/release gate will verify new buttons+result path, reusing
accepted transaction/storage-veto evidence (no repeat storage matrix or grants).

## Verification

Admin Lua specs and all runtime Lua syntax pass;7 existing Node tests pass;
126WeaponsLua pass including stale UI revision refusal. Tests exercise actual
Admin server RPCs/page builder/client lifetime with mocked providers, private
preview/one use/permissions/session/expiry/audit/unknown outcomes. No claim of live
Menu rendering or UI hold/release until supplied outputs.
