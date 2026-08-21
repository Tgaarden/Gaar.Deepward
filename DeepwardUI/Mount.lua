-- Deepward UI — mount anywhere. The 3.3.5 client greys the mount button indoors (caves/dungeons), and
-- grunnlov I forbids patching the client, so mounting goes through the server command `.dwmount` (picks a
-- random owned mount and summons it, indoors included). This wires that command to a keybinding AND a
-- slash command so players never have to type it:
--   * Key Bindings -> Deepward -> "Mount (Deepward)"  — bind any key.
--   * /dwmount  (or /dwm)                              — put on an action bar via a 1-line macro.
local function DeepwardMount()
    local eb = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
    if not eb then return end
    eb:SetText(".dwmount")        -- identical to typing the command + Enter
    ChatEdit_SendText(eb, 0)
    eb:SetText("")
end

_G.DeepwardMount = DeepwardMount   -- called by Bindings.xml

SLASH_DEEPWARDMOUNT1 = "/dwmount"
SLASH_DEEPWARDMOUNT2 = "/dwm"
SlashCmdList["DEEPWARDMOUNT"] = DeepwardMount

_G.BINDING_HEADER_DEEPWARD = "Deepward"           -- (also set in SpellBook.lua; harmless to repeat)
_G.BINDING_NAME_DEEPWARDUI_MOUNT = "Mount (anywhere)"
