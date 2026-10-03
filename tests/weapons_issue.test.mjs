import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

test('Admin issues with the Weapons purpose and the acting staff source', () => {
  const source = readFileSync(new URL('../server/services/weapons_admin.lua', import.meta.url), 'utf8')
  const request = source.split(":IssueWeapon({")[1].split("if failed(issued)")[0]
  assert.match(request, /purpose = 'admin_issue'/)
  assert.match(request, /requestId = \('admin:%s:%s'\):format\(actor.accountId, requestId\)/)
  assert.match(request, /actorSource = src/)
  assert.match(request, /reason = 'admin_weapon_grant'/)
  const weapons = readFileSync(new URL('../../feather-weapons/config.lua', import.meta.url), 'utf8')
  assert.match(weapons, /admin_issue = true/)
  const client = readFileSync(new URL('../client/services/weapons_admin.lua', import.meta.url), 'utf8')
  assert.match(client, /issueSequence = issueSequence \+ 1/)
  assert.match(client, /definitionId = definitionId, requestId = requestId/)
})
