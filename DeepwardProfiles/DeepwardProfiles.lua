--[[
  Deepward Profiles — one place to save, load and share the settings of EVERY Deepward addon at once.
  Original code, client-side only (law I).

  A "profile" is a snapshot of all the Deepward addon setting tables (bars, nameplates, bags, unit frames,
  positions, sizes, colours, toggles). Profiles are stored ACCOUNT-WIDE, so:
    * Any character on the SAME account can load a saved profile directly — no export needed.
    * To move a setup to ANOTHER account/person, Export it to a text string and Import that string there
      (WoW never shares saved variables across accounts, so a string is the only way across accounts).

  Applying a profile overwrites the live setting tables and then reloads the UI so every addon rebuilds
  from the new values.

  Slash: /dwprofile  (opens the window).  Also: /dwprofile save <name> | load <name> | list.
]]

local _G = _G

-- Every Deepward addon's saved-variable table. DeepwardUIDB is per-character; the rest are account-wide —
-- but a profile snapshots the CONTENTS regardless of scope, so it copies cleanly either way.
local DB_NAMES = {
    "DeepwardBagsDB", "DeepwardCCDB", "DeepwardCastDB", "DeepwardMeterDB", "DeepwardPawnDB",
    "DeepwardPlatesDB", "DeepwardThreatDB", "DeepwardTiersDB", "DeepwardUIDB",
}

local function PDB()
    if type(DeepwardProfilesDB) ~= "table" then DeepwardProfilesDB = {} end
    if type(DeepwardProfilesDB.profiles) ~= "table" then DeepwardProfilesDB.profiles = {} end
    return DeepwardProfilesDB
end

-- ---------------------------------------------------------------------------
-- Snapshot / apply
-- ---------------------------------------------------------------------------
local function deepcopy(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local r = {}; seen[t] = r
    for k, v in pairs(t) do r[deepcopy(k, seen)] = deepcopy(v, seen) end
    return r
end

local function Snapshot()
    local snap = {}
    for _, n in ipairs(DB_NAMES) do
        if type(_G[n]) == "table" then snap[n] = deepcopy(_G[n]) end
    end
    return snap
end

local function wipe(t) for k in pairs(t) do t[k] = nil end end

-- Apply IN PLACE: keep each saved-variable table's identity (wipe + refill) so any addon that cached a
-- reference to it still sees the new values, and WoW persists it on the reload that follows.
local function ApplySnapshot(snap)
    local applied = {}
    for _, n in ipairs(DB_NAMES) do
        if type(snap[n]) == "table" then
            if type(_G[n]) ~= "table" then _G[n] = {} end
            wipe(_G[n])
            for k, v in pairs(deepcopy(snap[n])) do _G[n][k] = v end
            applied[#applied + 1] = n
        end
    end
    return applied
end

local function countKeys(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

-- short label + key count per DB, e.g. "Cast(11)"; flags an empty table with "(0!)" so a setting that
-- never got configured (and would fall back to defaults on the other char) is visible.
local function report(snap)
    local out = {}
    for _, n in ipairs(DB_NAMES) do
        if snap[n] ~= nil then
            local c = countKeys(snap[n])
            out[#out + 1] = (n:gsub("^Deepward", ""):gsub("DB$", "")) .. (c == 0 and "(0!)" or ("(" .. c .. ")"))
        else
            out[#out + 1] = (n:gsub("^Deepward", ""):gsub("DB$", "")) .. "(missing!)"
        end
    end
    return table.concat(out, ", ")
end

local function SaveProfile(name)
    if not name or name == "" then return false end
    local snap = Snapshot()
    PDB().profiles[name] = snap
    return true, report(snap)
end

local function LoadProfile(name)
    local p = PDB().profiles[name]
    if not p then return false end
    ApplySnapshot(p)
    -- stash a report to print AFTER the reload (the reload clears the chat), so you can confirm what landed
    PDB()._pending = "loaded '" .. name .. "' -> " .. report(p)
    return true
end

local function DeleteProfile(name)
    if PDB().profiles[name] then PDB().profiles[name] = nil; return true end
    return false
end

local function ProfileNames()
    local t = {}
    for k in pairs(PDB().profiles) do t[#t + 1] = k end
    table.sort(t)
    return t
end

-- ---------------------------------------------------------------------------
-- Serialize / deserialize (for Export / Import across accounts)
-- ---------------------------------------------------------------------------
local function ser(v, out)
    local t = type(v)
    if t == "string" then out[#out + 1] = ("%q"):format(v)
    elseif t == "number" then out[#out + 1] = tostring(v)
    elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, val in pairs(v) do
            out[#out + 1] = "["; ser(k, out); out[#out + 1] = "]="
            ser(val, out); out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    else out[#out + 1] = "nil" end
end

local function Serialize(tbl)
    local o = { "DWP1:return " }
    ser(tbl, o)
    return table.concat(o)
end

-- Safe deserialize: run the chunk in an EMPTY environment so a pasted string can only build a table, never
-- call functions or touch globals.
local function Deserialize(str)
    if type(str) ~= "string" then return nil end
    str = str:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^DWP1:", "")
    if str == "" then return nil end
    local chunk = loadstring(str)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok, res = pcall(chunk)
    if ok and type(res) == "table" then return res end
    return nil
end

local function say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff5599ffDeepward Profiles:|r " .. msg) end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------
local selected
local UI, listButtons, RefreshList

local function BuildUI()
    if UI then return UI end
    local f = CreateFrame("Frame", "DeepwardProfilesFrame", UIParent)
    f:SetSize(460, 420); f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH"); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    table.insert(UISpecialFrames, "DeepwardProfilesFrame")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14); title:SetText("Deepward Profiles")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -6, -6)

    -- name entry + save
    local nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", 18, -44); nameLabel:SetText("Profile name:")
    local nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    nameBox:SetSize(200, 20); nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameBox:SetAutoFocus(false)
    f.nameBox = nameBox
    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetSize(90, 22); saveBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0); saveBtn:SetText("Save current")
    saveBtn:SetScript("OnClick", function()
        local n = nameBox:GetText()
        if n and n ~= "" then
            local _, rep = SaveProfile(n)
            say("saved '" .. n .. "' -> " .. (rep or "")); RefreshList()
        else say("type a name first.") end
    end)

    -- profile list
    local listBG = CreateFrame("Frame", nil, f)
    listBG:SetPoint("TOPLEFT", 16, -74); listBG:SetSize(200, 250)
    listBG:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    listBG:SetBackdropColor(0, 0, 0, 0.5)
    listButtons = {}
    for i = 1, 11 do
        local b = CreateFrame("Button", nil, listBG)
        b:SetSize(190, 20); b:SetPoint("TOPLEFT", 5, -4 - (i - 1) * 21)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetTexture(1, 1, 1, 0.15)
        b.sel = b:CreateTexture(nil, "BACKGROUND"); b.sel:SetAllPoints(); b.sel:SetTexture(0.2, 0.5, 1, 0.3); b.sel:Hide()
        b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.txt:SetPoint("LEFT", 4, 0)
        b:SetScript("OnClick", function(self) selected = self.name; nameBox:SetText(self.name or ""); RefreshList() end)
        b:Hide()
        listButtons[i] = b
    end

    -- action buttons (right column)
    local function actBtn(txt, y, fn)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(200, 24); b:SetPoint("TOPLEFT", 232, y); b:SetText(txt); b:SetScript("OnClick", fn)
        return b
    end
    actBtn("Load selected (reloads UI)", -74, function()
        if selected and LoadProfile(selected) then say("loading '" .. selected .. "' …"); ReloadUI() else say("select a profile first.") end
    end)
    actBtn("Delete selected", -104, function()
        if selected then DeleteProfile(selected); say("deleted '" .. selected .. "'."); selected = nil; RefreshList() else say("select a profile first.") end
    end)
    actBtn("Export selected -> box", -134, function()
        if selected and PDB().profiles[selected] then
            f.textBox:SetText(Serialize(PDB().profiles[selected]))
            f.textBox:HighlightText(); f.textBox:SetFocus()
            say("exported '" .. selected .. "' — copy the text (Ctrl+C).")
        else say("select a profile first.") end
    end)
    actBtn("Import from box -> name", -164, function()
        local data = Deserialize(f.textBox:GetText())
        local n = nameBox:GetText()
        if not data then say("box does not contain a valid profile string.")
        elseif not n or n == "" then say("type a name to import into.")
        else PDB().profiles[n] = data; say("imported into '" .. n .. "'."); RefreshList() end
    end)

    -- export/import text box (multiline, scrollable)
    local boxLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    boxLabel:SetPoint("TOPLEFT", 232, -196); boxLabel:SetText("Export/Import string:")
    local scroll = CreateFrame("ScrollFrame", "DeepwardProfilesScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 232, -212); scroll:SetSize(190, 100)
    scroll:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    scroll:SetBackdropColor(0, 0, 0, 0.6)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFontObject(ChatFontNormal)
    box:SetWidth(180); box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(box)
    f.textBox = box

    local help = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", 16, 14); help:SetPoint("BOTTOMRIGHT", -16, 14)
    help:SetJustifyH("LEFT")
    help:SetText("Profiles are shared across all your characters on this account. Use Export/Import to move a setup to another account.")

    UI = f
    return f
end

RefreshList = function()
    if not listButtons then return end
    local names = ProfileNames()
    for i, b in ipairs(listButtons) do
        local n = names[i]
        if n then
            b.name = n; b.txt:SetText(n)
            if selected == n then b.sel:Show() else b.sel:Hide() end
            b:Show()
        else
            b.name = nil; b:Hide()
        end
    end
end

local function Toggle()
    BuildUI()
    if UI:IsShown() then UI:Hide() else UI:Show(); RefreshList() end
end
_G.DeepwardProfiles_Toggle = Toggle

-- ---------------------------------------------------------------------------
-- Slash
-- ---------------------------------------------------------------------------
-- after a profile Load reloads the UI, print what actually landed (survives the reload via _pending)
local flush = CreateFrame("Frame")
flush:RegisterEvent("PLAYER_LOGIN")
flush:SetScript("OnEvent", function()
    local p = PDB()
    if p._pending then say(p._pending); p._pending = nil end
end)

SLASH_DEEPWARDPROFILE1 = "/dwprofile"
SLASH_DEEPWARDPROFILE2 = "/dwprofiles"
SlashCmdList["DEEPWARDPROFILE"] = function(msg)
    msg = msg or ""
    local cmd, arg = msg:match("^(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "save" and arg ~= "" then
        local _, rep = SaveProfile(arg); say("saved '" .. arg .. "' -> " .. (rep or "")); RefreshList()
    elseif cmd == "load" and arg ~= "" then
        if LoadProfile(arg) then say("loading '" .. arg .. "' …"); ReloadUI() else say("no profile named '" .. arg .. "'.") end
    elseif cmd == "list" then
        local names = ProfileNames()
        if #names == 0 then say("no profiles saved.") else say("profiles: " .. table.concat(names, ", ")) end
    elseif cmd == "dump" then
        -- print the position-critical LIVE values so you can compare two characters directly
        local function P(t) if type(t) == "table" and t.point then return t.point .. " " .. math.floor(t.x or 0) .. "," .. math.floor(t.y or 0) else return "default" end end
        say("--- live positions on this character ---")
        local c = DeepwardCastDB and DeepwardCastDB.pos or {}
        say("Cast: player=" .. P(c.player) .. " target=" .. P(c.target) .. " focus=" .. P(c.focus) .. " pet=" .. P(c.pet))
        say("Meter: " .. P(DeepwardMeterDB) .. " | Threat: " .. P(DeepwardThreatDB))
        local nf = 0; if DeepwardUIDB and DeepwardUIDB.frames then for _ in pairs(DeepwardUIDB.frames) do nf = nf + 1 end end
        say("UI moved frames: " .. nf .. " | UI scale=" .. tostring(DeepwardUIDB and DeepwardUIDB.frameScale or 1))
    else
        Toggle()
    end
end
