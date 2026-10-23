# Audited dollars wallet funding

Implemented 2026-10-22. Live menu/issue acceptance pending.

The owner-level economy.dollars.add action is enabled in Admin. Select an online
player, open Character management -> Balances and economy, choose dollars/Add,
enter a display amount such as 1.00 and submit. The balance comes from Economy's
wallet. XP, tokens, gold and removals stay hidden until integrated with their
domain APIs. No legacy character balance fields or Economy SQL are edited.

The server reads currency precision and converts exact decimal input into integer
base units. With current dollars precision=2, menu 1.00 means 100 base units;
console amount 1 means one base unit. Extra decimals, unsupported actions,
nonpositive and over-limit amounts are rejected. walletFunding.maxBaseUnits is
the authoritative server limit (default 1000000); allowed currencies default to
dollars. Existing wallets are used; none are provisioned by funding.

## Authority and audit

Existing Authority owner capability and target hierarchy control menu access and
both RPCs. Requests pin the target character UUID and resolve actor/target sessions
through Core. Permission, hierarchy and session-current checks run again after
the potentially yielding audit-intent call, immediately before Issue.

Economy Issue is a trusted Admin service call; its journal actor account/character
come from the resolved staff session. The Economy policy broker authenticates
feather-admin and only economy.currency.issue is granted. A service-only action
exception permits that exact action despite the legacy economy prefix being
hidden. No player currency.issue/destroy grant or wildcard is added. Explicit
disabledActions still wins. Only economy.dollars.add has a UI enabledActions
exception; the prefix remains disabled for other legacy controls.

Audit intent must be durably queued before issuance. Success/failure audit events
record the target, currency, base amount, request key, reason and transaction UUID.
Economy's own issue journal is authoritative and atomic for currency. If outcome
audit enqueue fails after success, the response reports auditRecorded=false; a new
request key must not be used to repeat that issuance.

## Retry behavior

Console uses admin.wallet.issue:<stable request ID>; menu adds server-derived
actor account ID before its client request ID. The same complete key is the
admin_wallet_issue reference ID. Economy binds target wallet, amount, currency,
reason and reference to that key and replays committed receipts. Changed terms
under a key conflict instead of issuing twice. Account closure does not prevent
an otherwise valid historical replay; Economy refuses a new issue into a closed
account. No direct balance edits or alternate issuance resource are used.

The client retains an unresolved request key, target and amount; retrying the same
form reuses it. Changing target/amount while uncertain is refused. A first invalid
input can be corrected; an invalid input after an uncertain outcome cannot clear
the earlier pending identity. This pending form is in memory, not persisted across
client/resource restart. After a lost response followed by restart, reconcile the
audit/known key before making a fresh request. This is not automatic crash recovery
for the Admin UI. For current menu-generated keys, console recovery can use
<actor account UUID>:<menu request ID> as the stable request ID with identical
target/currency/base-unit amount; the full Economy key/reference then matches.

Optional console fallback (trusted server console only; no player command):

```text
AdminWalletIssue <characterUUID> dollars <integerBaseUnits> <stableRequestId> <reason>
```

It validates the active character through the Core Character profile provider
(including CFX callable-table support), uses an existing wallet and follows the
same audit/Economy path. No active player session is required for console targeting.
Use stable request IDs for retries and different IDs only for intentional new issues.

## Verification

12/12 new wallet cases pass: console/limits, service call and audit, changed-term
conflict, lost response, missing audit/holder/wallet, exact decimals, wrong action/
target, revoked permission/hierarchy/session during audit, menu receipt replay,
balance units, client pending identity and exact UI/service action scope. Existing
7/7 Assets policy cases and every Admin Lua test script pass, including evidence
authority/server/client, menu usability and developer command regressions. All
Admin Lua sources parse under Lua 5.4. Boundaries are mocked; live Authority/menu,
Economy service policy, actual issue and audit delivery remain pending.

## Deployment / Stables unblock

Upload these runtime files to feather-admin, merging server-local config/policy:

```text
configs/config.lua
configs/service_policy.lua
server/core/init.lua
server/services/policy_provider.lua
server/services/wallet_funding.lua
client/services/character_administration.lua
client/ui/pages/character_administration.lua
translations/en_us.lua
```

Existing manifest server/services/*.lua includes the new file. Run server console
refresh before restart to refresh the script inventory:

```text
refresh
restart feather-admin
```

No Economy, Core, Authority, Stables or database/schema updates in this slice.
Owner: reopen Admin with Page Down (or configured menu command), select the intended
character (last confirmed server player ID 1), Character management -> Balances
and economy, Add dollars 1.00. Confirm the refreshed balance before retrying the
retained Stables proof. If funding fails, retain output and do not use a new issue
key to bypass an uncertain result. Non-owner should not see the addition action.

After funding, server console:

```text
BccStablesPaymentProof run 1 1
```

First 1 is the intended current server player ID; second acknowledges the single
base-unit test charge. Reconfirm ID if they reconnected. This resumes the same
payment_pending Stables fixture. Keep paymentProof=true until the later fence/
refund completes; other Stables proofs remain false. No commits or pushes made.

### Live checkpoint — 2026-10-22

User provided wallet.issue.requested and wallet.issue audit queue events, followed
by successful payment from the previously empty character wallet in Stables.
Positive funding/audit queue path observed. Exact issue receipt/amount, refreshed
balance, replay/negative policy tests and audit delivery remain unconfirmed by
this output. No new runtime changes for this evidence update.


### PR preparation verification â€” 2026-10-23

All seven Admin Lua specs pass, including 12/12 wallet and 7/7 Stables Assets policy cases; 198 Lua files parse; both Node test files pass all seven tests. No funds moved during these modeled tests. Prior live positive funding/audit-queue evidence remains limited as described above. Unrelated regression-audit documentation is outside this PR. Version unchanged; preparation only, no commit/push/PR created.


### Release version

Admin is now 0.15.4, including audited wallet funding and scoped Stables Assets policy. Manifest version changed: upload fxmanifest.lua with the release and run server-console refresh before restart feather-admin. No commit or push created.
