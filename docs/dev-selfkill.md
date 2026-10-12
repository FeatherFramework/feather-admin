# Alpha-only self-kill helper

`AdminDevKillSelf` is a retained alpha testing convenience for checking death
and UI cleanup while Inventory owns NUI focus. It is not a normal player command
or a new administrator permission. Remove it during production release cleanup;
the normal Admin Kill action is separate and remains supported.

The helper is disabled by default. Temporarily enable it from the server console:

```text
setr feather_admin_dev_selfkill 1
```

Run `AdminDevKillSelf` in the client's F8 console without arguments. It targets
only the current player and applies a two-second local request cooldown. Disable
it after testing, and do not leave the enable setting in production server.cfg:

```text
setr feather_admin_dev_selfkill 0
```

The replicated convar and local cooldown are convenience gates, not security
boundaries. Every request still uses the existing server `booster.kill`
permission, target hierarchy and action audit path. The helper calls the normal
Admin RPC; it does not directly invoke a health native or bypass authorization.
The console's "requested" message is not confirmation of server acceptance.

Run `lua tests/dev_selfkill_spec.lua` from the resource root with Lua 5.4.
The client regression checks default/explicit disable, argument and invalid-target
refusal, cooldown (including timer wrap), ordinary RPC forwarding and no direct
health write. It is not an independent server authorization or audit test.

Live acceptance: the opted-in helper requested the existing Kill path while
Inventory/Ammunition was open. Medical persisted death, the panels cleared and
NUI focus was released; doctor recovery reactivated native Weapons without
reopening those panels. Final ammo/equipment verification was unchanged. The
replicated helper flag was explicitly disabled afterward.
