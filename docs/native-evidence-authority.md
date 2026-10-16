# Weapons evidence authority integration

2026-10-15: Admin owns policy mappings for weapons.evidence.hold and
weapons.evidence.release, both minimum administrator tier/high-risk capabilities.
Capabilities are staff.admin.weapons.evidence.hold/release. The reviewed catalog
is90 actions, role grants moderator33/administrator67/owner90 (190 total).
Capability/grant registration request versions advance to005 to avoid old
idempotency receipt payload conflicts; role request version/keys/IDs stay stable.
Upgrade adds only missing administrator/owner grants. No user/account/Character role
assignment, service grant, hierarchy exception or destruction permission added.

The Admin-menu integration is now implemented; the own-current-item UI hold/release
gate was accepted on 2026-10-15. See evidence-inventory-ui.md for the test record.
Weapons keeps transaction ownership, exact serial/session/owner checks and the
default-off native evidence opt-in. Native test target remains current configured
actor's own unequipped item; cross-owner police custody is not implemented.

## Deployment

Admin existing runtime files:

- configs/permissions.lua: merge only the two administrator entries; preserve local policy.
- server/services/authority_catalog.lua
- server/services/authority_contract.lua
- server/services/policy_provider.lua

No refresh/new runtime script/UI/config replacement needed. Restart Admin only,
leave native evidence optin0 and do not restart Weapons/Inventory/Core/Authority.
Expected catalog ready capabilities90/roles3/grants190 on reviewed default config.
If local catalog differs, startup fails closed; inspect, do not weaken assertions.
Existing administrator/owner role holders gain their capabilities through the normal
catalog migration; no new person is assigned a staff role.

First read-only server-console check:

```text
WeaponNativeEvidenceStatus CURRENT_ID 135
```

Expect enabledfalse and hold/release true for an authorized administrator/owner.
Moderators stay denied. Do not bootstrap/promote a user to make a test pass.
Own-current-item hold/release was subsequently accepted; no destruction test.

## Automated evidence

Admin Lua specs and syntax checks plus7Node tests pass. Actual catalog provisioner
tested against mocked Authority seeded with old88-action or owner-only90-action
role grants: only missing administrator/owner grants, stable existing role IDs,
new receipt IDs, restart replay/no duplicate grants. Actual policy evaluator accepts
administrator/owner and refuses moderator, disabled actions and implicit
console/service use. No live Authority
migration or native evidence mutation acceptance claimed until supplied outputs.
