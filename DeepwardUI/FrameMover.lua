--[[
  DeepwardUI: Frame Mover — hold SHIFT and drag to move the default unit frames.

  Covers Player, Target, Focus, Pet, Target-of-Target, Focus-ToT and the 4 Party frames.
  Positions are saved per character (DeepwardUIDB.frames) and restored on login. Shift-drag only, so
  normal clicking/targeting is unaffected. Client-side only (law I).

  Slash: /dwframes            — toggle the on-screen "shift-drag to move" hint + lock
         /dwframes lock       — lock/unlock moving (locked = shift-drag disabled)
         /dwframes reset       — clear saved positions (then /reload to restore Blizzard defaults)
         /dwframes scale <f>   — scale ALL managed frames (e.g. 1.15); /dwframes scale 1 resets
]]

local _G = _G

local function DB()
    if type(DeepwardUIDB) ~= "table" then DeepwardUIDB = {} end
    local d = DeepwardUIDB
    if type(d.frames) ~= "table" then d.frames = {} end   -- [frameName] = {point, rel, relPoint, x, y}
    if d.framesLocked == nil then d.framesLocked = false end
    if d.frameScale == nil then d.frameScale = 1 end
    return d
end

-- The frames we manage, by global name (resolved at runtime — all exist in the default 3.3.5a UI).
local NAMES = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame",
    "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",
}

local function SavePos(f)
    local name = f:GetName(); if not name then return end
    local point, rel, relPoint, x, y = f:GetPoint()
    DB().frames[name] = { point = point, relPoint = relPoint, x = x, y = y }   -- always relative to UIParent
end

local function ApplyPos(f)
    local name = f:GetName(); if not name then return end
    local p = DB().frames[name]
    if not p then return end
    f:SetMovable(true)
    f:ClearAllPoints()
    f:SetPoint(p.point or "CENTER", UIParent, p.relPoint or p.point or "CENTER", p.x or 0, p.y or 0)
end

-- Make one frame shift-draggable. Hooks (not replaces) OnMouseDown/Up so targeting still works.
local hooked = {}
local function MakeMovable(f)
    if not f or hooked[f] then return end
    hooked[f] = true
    f:SetMovable(true)
    f:SetUserPlaced(true)
    f:EnableMouse(true)
    f:HookScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() and not DB().framesLocked then
            self:StartMoving()
            self.__dwMoving = true
        end
    end)
    f:HookScript("OnMouseUp", function(self)
        if self.__dwMoving then
            self:StopMovingOrSizing()
            self.__dwMoving = false
            SavePos(self)
        end
    end)
end

local function ForEachFrame(fn)
    for _, n in ipairs(NAMES) do
        local f = _G[n]
        if f then fn(f) end
    end
end

local function ApplyScale()
    local s = DB().frameScale or 1
    ForEachFrame(function(f) f:SetScale(s) end)
end

-- Party frames get re-anchored by Blizzard on roster changes; re-apply our saved spots after that.
local reapply = CreateFrame("Frame")
reapply:RegisterEvent("PLAYER_LOGIN")
reapply:RegisterEvent("PLAYER_ENTERING_WORLD")
reapply:RegisterEvent("PARTY_MEMBERS_CHANGED")
reapply:RegisterEvent("RAID_ROSTER_UPDATE")
reapply:SetScript("OnEvent", function(_, event)
    ForEachFrame(MakeMovable)
    ForEachFrame(ApplyPos)
    if event == "PLAYER_LOGIN" then ApplyScale() end
end)

-- ---------------------------------------------------------------------------
-- Slash
-- ---------------------------------------------------------------------------
-- Globals so the config menu (FrameStyle / the Deepward panel button) can drive moving/scale.
function DeepwardFrames_ApplyScale() ApplyScale() end
function DeepwardFrames_ResetPositions()
    DB().frames = {}
    ForEachFrame(function(f) f:SetUserPlaced(false) end)
    print("|cff5599ffDeepward frames:|r positions cleared — |cffffd100/reload|r to restore defaults.")
end
function DeepwardFrames_ToggleLock()
    DB().framesLocked = not DB().framesLocked
    print("|cff5599ffDeepward frames:|r " .. (DB().framesLocked and "locked." or "unlocked (shift-drag to move)."))
    return DB().framesLocked
end
_G.DeepwardFrames_ApplyScale = DeepwardFrames_ApplyScale
_G.DeepwardFrames_ResetPositions = DeepwardFrames_ResetPositions
_G.DeepwardFrames_ToggleLock = DeepwardFrames_ToggleLock

SLASH_DEEPWARDFRAMES1 = "/dwframes"
SLASH_DEEPWARDFRAMES2 = "/dwmove"
SLASH_DEEPWARDFRAMES3 = "/dwframe"
SlashCmdList["DEEPWARDFRAMES"] = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    if cmd == "lock" then
        DB().framesLocked = not DB().framesLocked
        print("|cff5599ffDeepward frames:|r " .. (DB().framesLocked and "locked." or "unlocked (shift-drag to move)."))
    elseif cmd == "reset" then
        DB().frames = {}
        ForEachFrame(function(f) f:SetUserPlaced(false) end)
        print("|cff5599ffDeepward frames:|r positions cleared — |cffffd100/reload|r to restore defaults.")
    elseif cmd == "scale" then
        local s = tonumber(arg)
        if s and s >= 0.5 and s <= 2.0 then
            DB().frameScale = s; ApplyScale()
            print(("|cff5599ffDeepward frames:|r scale = %.2f"):format(s))
        else
            print("|cff5599ffDeepward frames:|r usage /dwframes scale 0.5-2.0")
        end
    else
        print("|cff5599ffDeepward frames:|r hold SHIFT and drag to move Player/Target/Focus/Pet/Party frames.")
        print("  /dwframes lock  ·  /dwframes reset  ·  /dwframes scale <0.5-2.0>")
    end
end
