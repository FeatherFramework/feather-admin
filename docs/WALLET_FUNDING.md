# Audited cash and gold wallet adjustments

## Cash/gold adjustments accepted live - 2026-10-28

After the server catalog90/96 configuration alignment guidance, maintainer reports
it is all working now. Accept cash/gold add/remove and resolved startup blocker at
that reported level. No specific amounts, receipts, balances or independent live
fault/replay/insufficient-funds observations were supplied. Earlier unchanged
balance/removal refusal is no longer the current blocker; its exact error code was
not provided, so do not assert the catalog mismatch caused that refusal.
Existing19 wallet tests and Authority upgrade/replay/mismatch checks remain offline
evidence. No repeated deployment or test is needed. Documentation-only acceptance
update; no runtime/config/SQL changes, commands, version bump or commit.

## Server reports loaded90 - 2026-10-28

Diagnostic confirms server builds90 actions while deployed Authority provisioning
expects96. This matches the prior catalog size before the six reviewed weather
entries; exact server file contents were not supplied. Local six entries are
weather.view=moderator and weather.clock/weather.weather/weather.wind/
weather.seasons/weather.reset=administrator. Align existing server
configs/permissions.lua keys and configs/authority_actions.lua derived mapping
with the local96 configuration, preserving other intended minimum-role choices.
Do not lower/remove the count guard or add service Issue/Destroy to staff keys.
Existing modeled90->96 provisioning/replay checks already pass.

Required configuration references/destinations:
C:/coding/feather-scripts/feather-admin/configs/permissions.lua -> feather-admin/configs/permissions.lua;
C:/coding/feather-scripts/feather-admin/configs/authority_actions.lua -> feather-admin/configs/authority_actions.lua.
Merge the six missing entries into Config.permissions; keep authorityActions built
from all Config.permissions keys using configured capabilityPrefix. Existing
Authority role keys/IDs must remain unchanged. Close Admin, copy/merge, then
server console `restart feather-admin`. No refresh/manual SQL/Authority restart.
Verify authority.catalog.ready reports capabilities=96 before retrying a small
funded removal through Admin. If removal still refuses, return wallet diagnostic
line; startup mismatch itself does not prove the earlier removal failure cause.
No runtime code/test/doc server copies beyond the existing diagnostic file needed.

## Authority catalog startup mismatch - 2026-10-28

Maintainer reports Admin startup fails at the reviewed96-action catalog assertion.
Local configs/permissions.lua + configs/authority_actions.lua still generate96;
wallet work adds no new staff catalog keys (all4 cash/gold keys already existed).
Maintainer confirms Destroy was added only to service_policy.lua, not permissions.lua.
Server count/difference unknown. Do not remove/increase the assertion or register
currency supply service actions as staff permissions. They belong in the existing
service-policy grant/exception tables. Diagnostic now reports actual loaded count
and relevant config paths; unchanged safety check refuses97/95 actions before
Authority capability/grant writes. Authority replay/upgrade/mismatch tests pass.

For diagnostic only, close Admin and copy
C:/coding/feather-scripts/feather-admin/server/services/authority_catalog.lua to
resource-relative feather-admin/server/services/authority_catalog.lua, then server
console `restart feather-admin`. No refresh/SQL/Authority restart. Return the
reported loaded count, and compare server configs with these exact local sources:
C:/coding/feather-scripts/feather-admin/configs/permissions.lua -> feather-admin/configs/permissions.lua;
C:/coding/feather-scripts/feather-admin/configs/authority_actions.lua -> feather-admin/configs/authority_actions.lua.
Preserve intentional minimum-role choices; align the reviewed action keys/mapping
rather than blanket overwriting custom configuration. No docs/tests server copy.
Removal runtime cause remains unconfirmed until startup/catalog and wallet error
codes are available. No balance reset or database catalog deletion authorized.

## Removal live refusal diagnostic - 2026-10-28

Maintainer reports additions work but removal shows the old Wallet addition was
not confirmed notification; balance remains unchanged. New removal/gold paths are
not accepted live yet. Exact failure code is unknown; do not assert a policy cause
without runtime evidence. Local grant and service exception both include Destroy.
Added bounded server-console failure output with source/code/policyCode/action;
client distinguishes authorization denial and English strings use adjustment.
No mutation/permission bypass or automatic retry added.19 wallet tests pass,
including an Economy policy-denial response with unchanged balances and exact
operator diagnostic.

Copy C:/coding/feather-scripts/feather-admin/server/services/wallet_funding.lua to
feather-admin/server/services/wallet_funding.lua;
C:/coding/feather-scripts/feather-admin/client/services/character_administration.lua
to feather-admin/client/services/character_administration.lua; and
C:/coding/feather-scripts/feather-admin/translations/en_us.lua to
feather-admin/translations/en_us.lua. Destinations are resource-relative.
Verify existing server feather-admin/configs/service_policy.lua contains
['economy.currency.destroy']=true in both servicePolicy['feather-economy']['feather-admin']
and servicePolicyActionExceptions, preserving other entries. Local reference is
C:/coding/feather-scripts/feather-admin/configs/service_policy.lua.
Close Admin menu, copy/merge, then server console `restart feather-admin`.
No refresh/SQL/Economy/other-provider restart or docs/tests server copy.
Reopen Page Down -> Players -> select player -> Character management -> Balances
and economy -> Remove -> Dollars -> a small funded amount -> confirm. If refused,
return the server-console [feather-admin:wallet] line so the exact runtime failure
can be resolved; no fabricated proof command or repeat currency addition needed.

Updated2026-10-28. Cash-add had prior limited positive live funding/audit evidence;
cash/gold add/remove are now reported working live (see acceptance above).

Owner staff select an online player -> Character management -> Balances and economy.
The page reads both existing Economy wallets, selects Dollars or Gold and Add or
Remove, then accepts a displayed amount such as1.25. Removal uses the existing
confirmation page. Permissions remain independently controlled by
`economy.dollars.add`, `economy.dollars.remove`, `economy.gold.add` and
`economy.gold.remove`; their default minimum role is owner. Tokens and XP remain
hidden and unsupported. No legacy character-money fields or direct ledger SQL.

## Currency and provider contracts

Both currencies are enabled in walletFunding.currencies. maxBaseUnits remains the
server-authoritative integer limit (default1000000, or10000.00 at precision2).
The server reads each currency's actual precision and rejects extra decimals,
nonpositive/oversized amounts and unsupported fields/operations. It resolves the
current target character and an existing wallet; no wallet is provisioned here.
Summary reads are limited to currencies the actor can manage on that target.

Add calls Economy Issue; Remove calls Economy Destroy. Both use Economy's current
Contract1 supply/idempotency API. Independent exact staff permission, hierarchy
and actor/target session-current checks run before and after audit-intent enqueue.
Economy performs balance validation atomically; insufficient-funds removal does
not change the wallet. The actual provider enforces account status for a new
mutation while still permitting historical receipt replay after account closure.

The existing authenticated Economy->Admin service grant adds only
`economy.currency.destroy` alongside `economy.currency.issue`. Service-only prefix
exceptions contain both actions; exact broker/principal grants and explicit
disabledActions still control access. No player currency-supply action, broad
wildcard or new Stables grant is introduced. Stables Destroy remains denied.
The journal records resolved staff actor IDs; supply policy uses the existing
server service-principal flow rather than masquerading as a player.

## Audit and retries

Intent/success/failure audits use wallet.issue or wallet.destroy and contain the
target, currency, base-unit amount, request ID and reason; successful receipt audits
include the transaction UUID. Durable audit intent is required before mutation.
Outcome audit failure is reported separately through auditRecorded=false; it does
not justify performing a fresh currency adjustment.

Keys are admin.wallet.issue:<actorAccount>:<requestID> or
admin.wallet.destroy:<actorAccount>:<requestID> for the menu. Economy owns atomic
receipt/balance/journal replay. Client pending identity pins target, currency,
direction, amount and request ID. Unknown outcomes allow only the same request;
a certain first refusal (including insufficient funds) can be corrected. A certain
error following an unknown outcome cannot discard that earlier intent.

The pending client form remains in memory, not persistent across client/resource
restart. Reconcile an unknown outcome using audit/receipt identity before issuing
a fresh request after restart. No automatic Admin UI crash-recovery claim.
The existing server-console-only command is unchanged except that Gold is now an
allowed currency too; it issues, not removes, integer BASE UNITS:

```text
AdminWalletIssue <characterUUID> <dollars|gold> <integerBaseUnits> <stableRequestId> <reason>
```

No new commands are needed for menu testing. Generic wallet result/error messages
are resolved through each client's existing feather-settings/Core locale adapter,
falling back to English. Console diagnostics are not player messages.

## Verification

18 wallet cases pass with modeled providers: all4 directions, exact permission
selection, hierarchy/session revocation, input precision/limits, summary units,
removal confirmation, insufficient funds, lost removal response/idempotent retry,
currency conflict and pending client intent. Seven available Admin Lua regression
files pass, including Stables policy denial of Destroy, evidence, menu usability
and self-kill.203 Lua files parse;7 Node tests pass. Two existing weather suites
could not run because the local ../feather-weather checkout is absent. No real
funds were moved by automated tests. Cash/gold add/remove are now reported working live; injected fault/replay acceptance remains offline.

## Deployment and live gate

Required runtime copies (destinations relative to the server resources folder):

| Absolute local source | Destination |
| --- | --- |
| C:/coding/feather-scripts/feather-admin/server/services/wallet_funding.lua | feather-admin/server/services/wallet_funding.lua |
| C:/coding/feather-scripts/feather-admin/client/services/character_administration.lua | feather-admin/client/services/character_administration.lua |
| C:/coding/feather-scripts/feather-admin/client/ui/pages/character_administration.lua | feather-admin/client/ui/pages/character_administration.lua |
| C:/coding/feather-scripts/feather-admin/translations/en_us.lua | feather-admin/translations/en_us.lua |

Merge configuration changes separately, preserving other server values:

C:/coding/feather-scripts/feather-admin/configs/config.lua -> feather-admin/configs/config.lua:
- identity.enabledActions includes the4 exact cash/gold add/remove actions (true).
- walletFunding.currencies includes dollars=true,gold=true. Keep maxBaseUnits.

C:/coding/feather-scripts/feather-admin/configs/service_policy.lua -> feather-admin/configs/service_policy.lua:
- servicePolicy['feather-economy']['feather-admin'] includes
  ['economy.currency.issue']=true and ['economy.currency.destroy']=true.
- servicePolicyActionExceptions includes both same exact supply actions=true.
- Preserve all other broker/principal scopes, especially existing Stables Issue.

Close Admin menus, copy/merge above, then server console:

```text
restart feather-admin
```

No refresh (no manifest/script-list/new runtime file), SQL, Economy/Inventory/
Stables/Authority restart or full-server restart is needed. No version bump.
Docs/tests are optional development files, not required server copies.

Owner: Page Down (default) -> Players -> select intended player -> Character
management -> Balances and economy. Record initial balances. Add1.25 Dollars and
1.25 Gold, verifying only the selected wallet changes. Remove0.25 of each, confirming
each removal and verifying a single debit and refreshed balances. Try removing
more than the available funds: expect refusal and unchanged balances. No F8 or
extra console commands required during these UI checks. Keep Stables work paused
until this gate is reviewed.
