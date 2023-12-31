----- Pulling Essentials ----
Feather = exports['feather-core'].initiate()
MenuAPI = {}
TriggerEvent("menuapi:getData", function(cb)
  MenuAPI = cb
end)

---- Functions ----
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