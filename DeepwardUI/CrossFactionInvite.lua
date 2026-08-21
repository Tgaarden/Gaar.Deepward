--[[
  DeepwardUI — cross-faction right-click Invite.

  The 3.3.5 client hides the "Invite" entry from the right-click (UnitPopup) menu of an
  OPPOSITE-faction player — it's a hardcoded client-UI rule (UnitPopup_HideButtons calls
  UnitCanCooperate, which is false across factions), even though the server allows the invite
  (AllowTwoSide.Interaction.Group = 1). That's why /invite <name> and the /who list work but the
  right-click menu shows only Duel.

  This re-shows the invite button after the client hides it, for any player target we can name —
  so right-click -> Invite works cross-faction. InviteUnit() itself is faction-agnostic and the
  server accepts it, so the click does the right thing. Purely additive: it only flips an existing
  hidden button back to shown for player targets (never for yourself); worst case an invite that
  the server would reject is simply offered.
]]

local function ReshowInvite()
    local menu = UIDROPDOWNMENU_INIT_MENU
    if not menu or not menu.which then
        return
    end
    local buttons = UnitPopupMenus and UnitPopupMenus[menu.which]
    local shownLevel = UnitPopupShown and UnitPopupShown[UIDROPDOWNMENU_MENU_LEVEL]
    if not buttons or not shownLevel then
        return
    end

    -- Must be a player target that isn't us, and we must be able to resolve a name so the
    -- click has something to invite.
    local unit = menu.unit
    if unit and (not UnitIsPlayer(unit) or UnitIsUnit(unit, "player")) then
        return
    end
    local name = (unit and UnitName(unit)) or menu.name
    if not name then
        return
    end

    for index, value in ipairs(buttons) do
        if value == "PARTY_INVITE" or value == "RAID_INVITE" then
            shownLevel[index] = 1   -- 1 = shown (UnitPopup_HideButtons had set it to 0)
        end
    end
end

if type(UnitPopup_HideButtons) == "function" then
    hooksecurefunc("UnitPopup_HideButtons", ReshowInvite)
end
