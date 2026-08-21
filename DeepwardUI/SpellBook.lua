--[[
  DeepwardUI: Spell Book — a custom window listing every spell you know, ported from
  the GaarVanilla "Spell Browser" to the stock 3.3.5a (WotLK) client.

  One tab per real spellbook tab (school / skill line) plus an "All (Highest)" tab that
  combines the best-known rank of every spell. Each tab has a search box and three
  filters: "Highest rank only" (hides lower ranks), "Hide passives" (drops passive /
  non-castable entries), "Hide effects" (drops internal "...Effect" proc spells). The
  last two default ON. Hover a row for the real tooltip.

  Row actions:  click = pick the spell up (like the real spellbook);  Shift-click = drop
  it in the first empty action-bar slot.  (The Vanilla reagent action is dropped — Deepward
  has no reagent requirement / GaarReagents.)

  Open with the keybind (default Å, rebindable in Key Bindings -> Deepward) or /spellbook.

  3.3.5a port notes vs the 1.12 original: event args come through function parameters
  (self/button/delta) not the global `arg1`; spellbook APIs are PickupSpellBookItem and
  GameTooltip:SetSpellBookItem (1.12 used PickupSpell / SetSpell).
]]

local _G = _G
local ROWS = 14
local ROW_H = 28   -- per-row height/stride (bigger rows)

-- 3.3.5a spellbook APIs take (index, "spell"): PickupSpell + GameTooltip:SetSpell.
-- (The ...BookItem variants are Cataclysm+.) Prefer the 3.3.5a name, fall back otherwise.
local function PickupBookSpell(slot)
  if PickupSpell then PickupSpell(slot, "spell")
  elseif PickupSpellBookItem then PickupSpellBookItem(slot, "spell") end
end
local function TooltipBookSpell(slot)
  if GameTooltip.SetSpell then GameTooltip:SetSpell(slot, "spell")
  elseif GameTooltip.SetSpellBookItem then GameTooltip:SetSpellBookItem(slot, "spell") end
end

local function Norm(s)
  local r = string.lower(s or "")
  r = string.gsub(r, "[^%w]", "")
  return r
end

local function SpellIsPassive(slot)
  if IsPassiveSpell then return IsPassiveSpell(slot, "spell") end
  return false
end

local function BuildSpellIndex()
  local tabs = {}
  local numTabs = GetNumSpellTabs() or 0
  for t = 1, numTabs do
    local tabName, _, offset, numSpells = GetSpellTabInfo(t)
    local entries = {}
    if offset and numSpells then
      for i = offset + 1, offset + numSpells do
        local name, rank = GetSpellName(i, "spell")
        if name then
          local tex = GetSpellTexture(i, "spell")
          local effectlike = string.find(string.lower(name), "effect", 1, true) ~= nil
          table.insert(entries, { slot = i, name = name, rank = rank, texture = tex,
                                  passive = SpellIsPassive(i) and true or false,
                                  effectlike = effectlike })
        end
      end
    end
    table.insert(tabs, { name = tabName or ("Tab " .. t), entries = entries })
  end
  return tabs
end

local function HighestRanksOnly(entries)
  local byName, order = {}, {}
  for _, e in ipairs(entries) do
    local key = Norm(e.name)
    if not byName[key] then table.insert(order, key) end
    local cur = byName[key]
    if not cur or e.slot > cur.slot then byName[key] = e end
  end
  local out = {}
  for _, key in ipairs(order) do table.insert(out, byName[key]) end
  return out
end

local function BuildAllHighest(tabs)
  local combined = {}
  for _, t in ipairs(tabs) do
    for _, e in ipairs(t.entries) do table.insert(combined, e) end
  end
  return HighestRanksOnly(combined)
end

local function FindEmptyActionSlot()
  for slot = 1, 120 do
    if not HasAction(slot) then return slot end
  end
  return nil
end

local READY_CHECK_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"
local function BuildActionTextureSet()
  local set = {}
  for slot = 1, 120 do
    local tex = GetActionTexture(slot)
    if tex then set[tex] = true end
  end
  return set
end

local function PlaceOnBar(slot, label)
  local target = FindEmptyActionSlot()
  if not target then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff6666Deepward:|r no empty action bar slot found.")
    return
  end
  ClearCursor()
  PickupBookSpell(slot)
  PlaceAction(target)
  ClearCursor()
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Deepward:|r added '" .. label .. "' to action bar slot " .. target .. ".")
end

-- ---------------- UI ----------------
local BASE_HEIGHT = 560
local f = CreateFrame("Frame", "DeepwardSpellBookFrame", UIParent)
f:SetWidth(640); f:SetHeight(BASE_HEIGHT)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
f:SetBackdrop({
  bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
  edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
f:SetFrameStrata("HIGH")
f:SetMovable(true); f:EnableMouse(true)
f:SetScript("OnMouseDown", function(self) self:StartMoving() end)
f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
f:EnableMouseWheel(true)
f:Hide()
table.insert(UISpecialFrames, "DeepwardSpellBookFrame")

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", f, "TOP", 0, -14)
title:SetText("Deepward — Spell Book")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

local searchBox = CreateFrame("EditBox", "DeepwardSpellSearchBox", f, "InputBoxTemplate")
searchBox:SetWidth(200); searchBox:SetHeight(20); searchBox:SetAutoFocus(false)
searchBox:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)

local hideLower = CreateFrame("CheckButton", "DeepwardHideLowerRanks", f, "UICheckButtonTemplate")
hideLower:SetWidth(22); hideLower:SetHeight(22)
hideLower:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -66)
hideLower:SetChecked(true)
_G["DeepwardHideLowerRanksText"]:SetText("Highest rank only")
_G["DeepwardHideLowerRanksText"]:SetFontObject(GameFontHighlightSmall)

local hidePassive = CreateFrame("CheckButton", "DeepwardHidePassives", f, "UICheckButtonTemplate")
hidePassive:SetWidth(22); hidePassive:SetHeight(22)
hidePassive:SetPoint("LEFT", _G["DeepwardHideLowerRanksText"], "RIGHT", 12, 0)
hidePassive:SetChecked(true)
_G["DeepwardHidePassivesText"]:SetText("Hide passives")
_G["DeepwardHidePassivesText"]:SetFontObject(GameFontHighlightSmall)

local hideEffects = CreateFrame("CheckButton", "DeepwardHideEffects", f, "UICheckButtonTemplate")
hideEffects:SetWidth(22); hideEffects:SetHeight(22)
hideEffects:SetPoint("LEFT", _G["DeepwardHidePassivesText"], "RIGHT", 12, 0)
hideEffects:SetChecked(true)
_G["DeepwardHideEffectsText"]:SetText("Hide effects")
_G["DeepwardHideEffectsText"]:SetFontObject(GameFontHighlightSmall)

local allTabsData, tabsBuilt = nil, false
local curTabIndex = 1
local offset, rows, tabButtons = 0, {}, {}

local function EnsureData()
  if not allTabsData then allTabsData = BuildSpellIndex() end
end

local RefreshList

local function CurrentEntries()
  EnsureData()
  local n = table.getn(allTabsData)
  if curTabIndex > n then
    return BuildAllHighest(allTabsData)
  end
  local entries = allTabsData[curTabIndex].entries
  if hideLower:GetChecked() then entries = HighestRanksOnly(entries) end
  return entries
end

local function FilteredEntries()
  local entries = CurrentEntries()
  local dropPassive = hidePassive:GetChecked()
  local dropEffects = hideEffects:GetChecked()
  local q = searchBox:GetText()
  local ql = (q and q ~= "") and string.lower(q) or nil
  if not dropPassive and not dropEffects and not ql then return entries end
  local out = {}
  for _, e in ipairs(entries) do
    if (not dropPassive or not e.passive)
       and (not dropEffects or not e.effectlike)
       and (not ql or string.find(string.lower(e.name), ql, 1, true)) then
      table.insert(out, e)
    end
  end
  return out
end

local TAB_ROW_Y, TAB_ROW_H = -98, 24
local TAB_PAD, TAB_MIN_W, TAB_MAX_ROW_W = 16, 40, 610

local function BuildTabButtons()
  if tabsBuilt then return end
  tabsBuilt = true
  EnsureData()
  local labels = {}
  for _, t in ipairs(allTabsData) do table.insert(labels, t.name) end
  table.insert(labels, "All (Highest)")

  local x, row = 0, 0
  for idx, label in ipairs(labels) do
    local idx = idx
    local tb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tb:SetHeight(20); tb:SetText(label)
    local fs = tb:GetFontString()
    local textW = (fs and fs:GetStringWidth()) or TAB_MIN_W
    local w = math.max(TAB_MIN_W, textW + TAB_PAD)
    if x > 0 and x + w > TAB_MAX_ROW_W then
      x = 0
      row = row + 1
    end
    tb:SetWidth(w)
    tb:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + x, TAB_ROW_Y - row * TAB_ROW_H)
    tb:SetScript("OnClick", function() curTabIndex = idx; offset = 0; RefreshList() end)
    table.insert(tabButtons, tb)
    x = x + w + 4
  end

  local tabRowCount = row + 1
  f:SetHeight(BASE_HEIGHT + (tabRowCount - 1) * TAB_ROW_H)
  local listTop = TAB_ROW_Y - (tabRowCount - 1) * TAB_ROW_H - TAB_ROW_H - 10
  for i, r in ipairs(rows) do
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 16, listTop - (i - 1) * ROW_H)
  end
end

RefreshList = function()
  local list = FilteredEntries()
  local total = table.getn(list)
  if offset > total - ROWS then offset = total - ROWS end
  if offset < 0 then offset = 0 end
  local actionTex = BuildActionTextureSet()
  for i = 1, ROWS do
    local row = rows[i]
    local e = list[offset + i]
    if e then
      row.label:SetText(e.name .. "  |cff888888(" .. (e.rank or "") .. ")|r")
      row.icon:SetTexture(e.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.slot = e.slot
      row.ename = e.name
      if e.texture and actionTex[e.texture] then row.mark:Show() else row.mark:Hide() end
      row:Show()
    else
      row:Hide()
    end
  end
end

for i = 1, ROWS do
  local row = CreateFrame("Button", nil, f)
  row:SetWidth(608); row:SetHeight(ROW_H - 2)
  row:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -128 - (i - 1) * ROW_H)
  row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
  row:RegisterForClicks("LeftButtonUp")
  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetWidth(24); icon:SetHeight(24); icon:SetPoint("LEFT", 0, 0)
  row.icon = icon
  local mark = row:CreateTexture(nil, "OVERLAY")
  mark:SetTexture(READY_CHECK_TEX)
  mark:SetWidth(14); mark:SetHeight(14)
  mark:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
  mark:Hide()
  row.mark = mark
  local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", icon, "RIGHT", 6, 0); label:SetWidth(570); label:SetJustifyH("LEFT")
  row.label = label
  row:SetScript("OnClick", function(self)
    if not self.slot then return end
    if IsShiftKeyDown() then
      PlaceOnBar(self.slot, self.ename)
    else
      ClearCursor(); PickupBookSpell(self.slot)
    end
  end)
  row:SetScript("OnEnter", function(self)
    if not self.slot then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    TooltipBookSpell(self.slot)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:Hide()
  rows[i] = row
end

searchBox:SetScript("OnTextChanged", function() offset = 0; RefreshList() end)
hideLower:SetScript("OnClick", function() offset = 0; RefreshList() end)
hidePassive:SetScript("OnClick", function() offset = 0; RefreshList() end)
hideEffects:SetScript("OnClick", function() offset = 0; RefreshList() end)

f:SetScript("OnMouseWheel", function(self, delta)
  offset = offset - delta
  RefreshList()
end)

local markTicker = CreateFrame("Frame"); markTicker:Hide()
local lastMarkRefresh = 0
markTicker:SetScript("OnUpdate", function()
  if not f:IsShown() then markTicker:Hide(); return end
  local now = GetTime()
  if now - lastMarkRefresh < 0.2 then return end
  lastMarkRefresh = now
  local actionTex = BuildActionTextureSet()
  for i = 1, ROWS do
    local row = rows[i]
    if row:IsShown() then
      local tex = row.icon:GetTexture()
      if tex and actionTex[tex] then row.mark:Show() else row.mark:Hide() end
    end
  end
end)

local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
hint:SetText("|cff33ff99checkmark|r = on your action bar  |  hover = tooltip  |  click = pick up  |  Shift-click = action bar")

local function Toggle()
  if f:IsShown() then
    f:Hide()
  else
    BuildTabButtons()
    RefreshList()
    f:Show()
    markTicker:Show()
  end
end

-- Entry points: slash + a rebindable keybind (default Å).
SLASH_DEEPWARDSPELLBOOK1 = "/spellbook"
SLASH_DEEPWARDSPELLBOOK2 = "/spells"
SlashCmdList["DEEPWARDSPELLBOOK"] = Toggle

_G.DeepwardSpellBook_Toggle = Toggle
_G.BINDING_HEADER_DEEPWARD = "Deepward"
_G.BINDING_NAME_DEEPWARDUI_SPELLBOOK = "Toggle Spell Book"

-- Open BOTH books from P: mirror the native spellbook (P / the spellbook microbutton) to this
-- browser. Opening the native one opens this too; closing it closes this. The Å keybind still
-- toggles this browser on its own. (Both are draggable if they overlap.)
local function OpenAlongsideNative()
  if not f:IsShown() then
    BuildTabButtons()
    RefreshList()
    f:Show()
    markTicker:Show()
  end
end
local function MirrorNativeSpellbook()
  if SpellBookFrame and SpellBookFrame:IsShown() then
    OpenAlongsideNative()
  elseif f:IsShown() then
    f:Hide()
  end
end
if SpellBookFrame then
  SpellBookFrame:HookScript("OnShow", MirrorNativeSpellbook)
  SpellBookFrame:HookScript("OnHide", MirrorNativeSpellbook)
end

local binder = CreateFrame("Frame")
binder:RegisterEvent("PLAYER_LOGIN")
binder:SetScript("OnEvent", function()
  if not GetBindingKey("DEEPWARDUI_SPELLBOOK") then
    SetBinding("Å", "DEEPWARDUI_SPELLBOOK")
    SaveBindings(GetCurrentBindingSet() or 1)
  end
end)
