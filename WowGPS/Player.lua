-- WowGPS: what we know about this character: real movement speed, where the
-- hearthstone is bound, and which zones are friendly, contested or hostile.
local _, ns = ...

local BASE_SPEED = 7.0
local HEARTHSTONE_ITEM = 6948
local HEARTH_CAST = 10

---------------------------------------------------------------------------
-- Movement speed
---------------------------------------------------------------------------

local function usableNumber(v)
    if type(v) ~= "number" then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return v > 0
end

-- Remembers the character's current run speed, on foot or mounted. Called on
-- login, when mounting or dismounting and before every route computation.
function ns:SampleSpeed()
    if not GetUnitSpeed or not self.chardb then return end
    if UnitOnTaxi and UnitOnTaxi("player") then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    local _, run = GetUnitSpeed("player")
    if not usableNumber(run) then return end
    if IsMounted and IsMounted() then
        self.chardb.mountSpeed = run
    else
        self.chardb.footSpeed = run
    end
end

function ns:FootSpeed()
    return self.chardb.footSpeed or BASE_SPEED
end

-- Yards per second on a mount. db.mountSpeed: "auto" (measured the last time
-- you were mounted), 0 (no mount), 60 or 100 (percent bonus).
function ns:MountSpeed()
    local setting = self.db.mountSpeed
    if setting == 0 then return self:FootSpeed() end
    if setting == 60 or setting == 100 then return BASE_SPEED * (1 + setting / 100) end
    return self.chardb.mountSpeed or BASE_SPEED * 1.6
end

function ns:SpeedPercent(speed)
    return math.floor((speed / BASE_SPEED - 1) * 100 + 0.5)
end

---------------------------------------------------------------------------
-- Hearthstone
---------------------------------------------------------------------------

local Hearth = {}
ns.Hearth = Hearth

-- The game only tells addons the *name* of the bind location. The exact spot
-- is saved when you bind; otherwise the name is looked up among known places.
function Hearth:OnBound()
    local p = ns.Maps:Ensure() and ns.Maps:PlayerPoint()
    local name = GetBindLocation and GetBindLocation()
    if p and name then
        ns.chardb.bind = { name = name, map = p.map, x = p.x, y = p.y }
    end
end

local function hasHearthstone()
    local count
    if C_Item and C_Item.GetItemCount then
        count = C_Item.GetItemCount(HEARTHSTONE_ITEM)
    elseif GetItemCount then
        count = GetItemCount(HEARTHSTONE_ITEM)
    else
        return true
    end
    return type(count) == "number" and count > 0
end

local function cooldownLeft()
    local get = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
    if not get or not GetTime then return 0 end
    local start, duration = get(HEARTHSTONE_ITEM)
    if not usableNumber(start) or not usableNumber(duration) then return 0 end
    return math.max(0, start + duration - GetTime())
end

-- Returns a table:
--   { node = point, time = seconds }      usable now
--   { reason = "none" }                    no hearthstone in the bags
--   { reason = "unknown", name = ... }     bound somewhere we cannot place
--   { reason = "cooldown", left = sec }    not ready
function Hearth:Get()
    if not hasHearthstone() then return { reason = "none" } end
    local name = GetBindLocation and GetBindLocation()
    if not name or name == "" then return { reason = "unknown" } end
    local node
    local saved = ns.chardb.bind
    if saved and saved.name == name then
        node = ns.Maps:Point(saved.map, saved.x, saved.y, name)
    end
    if not node and ns.Places then
        node = ns.Places:FindExact(name)
    end
    if not node then return { reason = "unknown", name = name } end
    node.kind, node.place = "hearth", name
    local left = cooldownLeft()
    if left > 1 then return { reason = "cooldown", left = left, name = name } end
    return { node = node, time = HEARTH_CAST, name = name }
end

---------------------------------------------------------------------------
-- Zone ownership
---------------------------------------------------------------------------

local PvP = {}
ns.PvP = PvP

local VALID = { friendly = true, contested = true, hostile = true, sanctuary = true }

-- "friendly" | "contested" | "hostile" | "sanctuary" | nil (unknown zone)
function PvP:Status(mapID)
    local faction = ns.faction or UnitFactionGroup("player")
    local learned = ns.db.pvp[faction or "?"]
    if learned and learned[mapID] then return learned[mapID] end
    local zone = ns.Maps.zones[mapID]
    if not zone then return nil end
    if not self.static then
        self.static = {}
        for owner, list in pairs(ns.Data.territory) do
            for i = 1, #list do self.static[list[i]] = owner end
        end
    end
    local owner = self.static[zone.area]
    if not owner then return "contested" end
    return owner == faction and "friendly" or "hostile"
end

function PvP:OnZoneChanged()
    local get = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
    if not get or not ns.Maps:Ensure() then return end
    local kind = get()
    if not VALID[kind] then return end
    local p = ns.Maps:PlayerPoint()
    local faction = ns.faction or UnitFactionGroup("player")
    if not p or not faction then return end
    ns.db.pvp[faction] = ns.db.pvp[faction] or {}
    ns.db.pvp[faction][p.map] = kind
end
