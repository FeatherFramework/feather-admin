----- Pulling Essentials ----
Feather = exports['feather-core'].initiate()
FeatherMenu = exports['feather-menu'].initiate()

--Global Variables
FeatherAdminMenu = FeatherMenu:RegisterMenu('feather-admin:Menu', {
  top = '40%',
  left = '20%',
  ['720width'] = '500px',
  ['1080width'] = '600px',
  ['2kwidth'] = '700px',
  ['4kwidth'] = '900px',
  style = {},
  contentslot = {
      style = { --This style is what is currently making the content slot scoped and scrollable. If you delete this, it will make the content height dynamic to its inner content.
          ['height'] = '300px',
          ['min-height'] = '300px'
      }
  },
  draggable = true
})

---- Functions ----
function DrawText3D(x, y, z, text)
  local onScreen,_x,_y = GetScreenCoordFromWorldCoord(x, y, z)
  local px,py,pz=table.unpack(GetGameplayCamCoord())
  local dist = GetDistanceBetweenCoords(px,py,pz, x,y,z, 1)
  local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
  if onScreen then
      SetTextScale(0.30, 0.30)
      SetTextFontForCurrentCommand(1)
      SetTextColor(255, 255, 255, 215)
      SetTextCentre(1)
      DisplayText(str,_x,_y)
      local factor = (string.len(text)) / 225
      DrawSprite("feeds", "hud_menu_4a", _x, _y+0.0125,0.015+ factor, 0.03, 0.1, 35, 35, 35, 190, 0)
  end
end

function DrawTxt(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
  local str = CreateVarString(10, "LITERAL_STRING", str)
  SetTextScale(w, h)
  SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
  SetTextCentre(centre)
  if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
  DisplayText(str, x, y)
end

function loadModel(model)
  RequestModel(model)
  while not HasModelLoaded(model) do
    Wait(100)
  end
end
