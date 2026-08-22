--[[
  DeepwardUI — hides default UI for systems Deepward doesn't use:
  Achievements, Dungeon Finder (LFG), PvP, and the Calendar.
  (The Quest Log is KEPT — Deepward uses it for its own "Ascension" clear-tier quests.)

  Deepward has no achievements (law IV: progress is judged from the event log,
  not "completed" flags), no built-in group finder (handover §3 turns LFG off;
  bots fill the group, matching is a custom phase-2 system), no quests
  (dungeon-quest rewards fold into boss loot; other quests are ignored in phase 1
  — handover §7), no PvP/BG/arena (handover §3), and no calendar events. So the
  corresponding default windows/buttons are removed from the client.

  Client-side only, via addon — allowed under law I ("client files are never
  touched; addons are OK"). Nothing here talks to the server.
]]

-- A parked frame to re-home things we hide, kept permanently hidden.
local parkedFrame = CreateFrame("Frame")
parkedFrame:Hide()

-- Neutralise a micro button: hide it, stop it re-showing, unhook its events.
local function KillButton(button)
    if not button then
        return
    end
    button:Hide()
    button:UnregisterAllEvents()
    button:SetParent(parkedFrame)
    button.Show = function() end
end

-- Neutralise a UI frame if/when it exists.
local function KillFrame(frame)
    if not frame then
        return
    end
    frame:Hide()
    frame:UnregisterAllEvents()
    frame:SetParent(parkedFrame)
    frame.Show = function() end
end

-- No-op that a blocked toggle becomes (also silences any "eye" glow updates).
local function NoOp() end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    -- 1) Remove the micro-menu buttons so there is no click path.
    KillButton(_G.AchievementMicroButton)
    KillButton(_G.LFDMicroButton)

    -- 2) Block the toggle functions so keybinds and macros can't open them
    --    (the micro button, the keybind, and /macro all route through these).
    if _G.ToggleAchievementFrame then _G.ToggleAchievementFrame = NoOp end
    if _G.ToggleLFDParentFrame  then _G.ToggleLFDParentFrame  = NoOp end
    if _G.PVEFrame_ToggleFrame  then _G.PVEFrame_ToggleFrame  = NoOp end

    -- 3) The Achievement UI is load-on-demand; stop it loading at all.
    if _G.AchievementFrame_LoadUI then _G.AchievementFrame_LoadUI = NoOp end

    -- 3b) Achievements still fire server-side (level, exploration, cooking…). The earned-achievement
    --     alert popup (AchievementAlertFrame_ShowAlert) builds a shield whose OnLoad lives in the
    --     achievement UI we just blocked -> "AchievementShield_OnLoad (a nil value)" error spam.
    --     Suppress the alert; Deepward shows progress in the tier panel, not achievement popups.
    if _G.AchievementAlertFrame_ShowAlert then _G.AchievementAlertFrame_ShowAlert = NoOp end

    -- 4) If the frames are already present (or get built), keep them hidden.
    KillFrame(_G.AchievementFrame)
    KillFrame(_G.LFDParentFrame)
    KillFrame(_G.LFGParentFrame)

    -- 5) Quest log: KEPT. Deepward now uses the quest log for its own "Ascension" clear-tier
    --    quests (given by the Deepward Herald in the hub). All vanilla quests are made
    --    unobtainable server-side (quest-giver link tables emptied — see sql/deepward_quests_custom.sql),
    --    so the log only ever shows Deepward's own quests. The window, its "L" toggle, the
    --    micro-button and the on-screen objective tracker are all left enabled.

    -- 6) PvP is off (handover §3: no PvP/BG/arena): remove the PvP window + toggle.
    if _G.TogglePVPFrame then _G.TogglePVPFrame = NoOp end
    KillFrame(_G.PVPFrame)
    KillFrame(_G.PVPParentFrame)

    -- 7) Calendar: no events in Deepward — remove the minimap calendar button
    --    and block the toggle (also stops the load-on-demand calendar addon).
    KillButton(_G.GameTimeFrame)
    if _G.ToggleCalendar then _G.ToggleCalendar = NoOp end

    -- 8) Repaint the micro-button row so the removed buttons leave no gap.
    if _G.UpdateMicroButtons then
        _G.UpdateMicroButtons()
    end
end)
