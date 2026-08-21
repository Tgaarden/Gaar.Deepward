-- Deepward UI — every item is BoP server-wide, so the "…will bind it to you" confirmation popups are
-- pure noise. Auto-confirm them so looting/equipping/rolling is one click:
--   LOOT_BIND_CONFIRM / EQUIP_BIND_CONFIRM / AUTOEQUIP_BIND_CONFIRM / USE_BIND_CONFIRM — solo looting,
--     equipping and using BoP items.
--   CONFIRM_LOOT_ROLL — GROUP loot: rolling Need/Greed on a BoP item pops "this will bind to you, roll?"
--     (the dice UI). A different event from LOOT_BIND_CONFIRM, so it needs its own handler.
local f = CreateFrame("Frame")
f:RegisterEvent("LOOT_BIND_CONFIRM")
f:RegisterEvent("EQUIP_BIND_CONFIRM")
f:RegisterEvent("AUTOEQUIP_BIND_CONFIRM")
f:RegisterEvent("USE_BIND_CONFIRM")
f:RegisterEvent("CONFIRM_LOOT_ROLL")
f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "LOOT_BIND_CONFIRM" then
        ConfirmLootSlot(arg1)
    elseif event == "EQUIP_BIND_CONFIRM" or event == "AUTOEQUIP_BIND_CONFIRM" then
        EquipPendingItem(arg1)
    elseif event == "USE_BIND_CONFIRM" then
        ConfirmBindOnUse()
    elseif event == "CONFIRM_LOOT_ROLL" then
        ConfirmLootRoll(arg1, arg2)   -- arg1 = rollID, arg2 = rollType (need/greed/pass)
    end
    -- close any popup the default UI already put up
    StaticPopup_Hide("LOOT_BIND")
    StaticPopup_Hide("EQUIP_BIND")
    StaticPopup_Hide("AUTOEQUIP_BIND")
    StaticPopup_Hide("USE_BIND")
    StaticPopup_Hide("CONFIRM_LOOT_ROLL")
end)
