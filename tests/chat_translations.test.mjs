import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
const root = new URL('../', import.meta.url)
const read = (path) => readFileSync(new URL(path, root), 'utf8')
const keys = (text) => new Set([...text.matchAll(/\b([a-z][a-z0-9_]*)\s*=/g)].map((match) => match[1]))
const english = keys(read('translations/en_us.lua'))
const chatKeys = [...english].filter((key) => key.startsWith('chat_') || key === 'mute_chat')
test('general Admin navigation falls back for incomplete locales', () => {
  const helper = read('client/core/init.lua').split('function AdminTranslate(key)')[1]
  assert.ok(helper.includes('AdminEnglishTranslations[key]'))
  for (const key of ['player_information', 'moderation', 'player_notes', 'staff_role', 'teleportation', 'character_management']) {
    assert.ok(english.has(key), key)
  }
})
for (const locale of ['ro', 'es']) {
  test(`${locale} covers all English Chat keys`, () => {
    const available = keys(read(`translations/${locale}.lua`))
    assert.ok(chatKeys.length > 50)
    for (const key of chatKeys) assert.ok(available.has(key), key)
  })
}
test('literal Chat UI keys and configured options exist', () => {
  for (const path of ['client/services/chat_cases.lua', 'client/ui/pages/moderation.lua', 'client/services/chat_translation.lua']) {
    for (const match of read(path).matchAll(/AdminChatTranslate\('([^']+)'/g)) assert.ok(english.has(match[1]), `${path}: ${match[1]}`)
  }
  for (const match of read('configs/config.lua').matchAll(/translationKey\s*=\s*'([^']+)'/g)) assert.ok(english.has(match[1]), match[1])
})
test('mute notice uses recipient-localized data after committed success', () => {
  const server = read('server/services/moderation.lua')
  assert.ok(server.includes("TriggerClientEvent('feather-admin:chat-moderation:notice'"))
  assert.ok(!server.includes('chatMuteNotice'))
  assert.ok(server.indexOf("if type(result) == 'table' and result.ok then", server.indexOf("chat-moderation:issue"))
    < server.indexOf("TriggerClientEvent('feather-admin:chat-moderation:notice'"))
  assert.ok(read('client/services/chat_translation.lua').includes("AdminChatTranslate('chat_mute_notice'"))
})
test('conversation statuses use localized labels and mute failures do not display raw API messages', () => {
  const cases = read('client/services/chat_cases.lua')
  assert.ok(cases.includes('AdminChatStatus(row.status)'))
  assert.ok(cases.includes('AdminChatStatus(AdminChatCases.status)'))
  const handler = read('client/services/moderation.lua').split("RegisterNetEvent('feather-admin:chat-moderation:result'")[1]
  assert.ok(handler.includes('chat_action_failed_code'))
  assert.ok(!handler.includes('result.message'))
})
