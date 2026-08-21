-- Deepward UI — quests are auto-granted and non-optional, so the player must not abandon them
-- (CHANGE-NOTES 2026-08-18). Hide the quest-log Abandon button; the server also ignores the abandon
-- opcode (core-patch), so this is just the visible half.
local function hideAbandon()
    if QuestLogFrameAbandonButton then
        QuestLogFrameAbandonButton:Hide()
        QuestLogFrameAbandonButton:SetScript("OnShow", QuestLogFrameAbandonButton.Hide)
    end
end
hideAbandon()
-- Re-hide whenever the quest log opens (the frame re-lays-out its buttons on show).
if QuestLogFrame then QuestLogFrame:HookScript("OnShow", hideAbandon) end
