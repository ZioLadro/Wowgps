-- WowGPS: map resolution and coordinate conversion.
-- Everything is converted to world coordinates (instanceID + yards) so that
-- distances can be measured across zone maps.
local _, ns = ...

local Maps = {}
ns.Maps = Maps

local MT = (Enum and Enum.UIMapType) or {}
local T_CONTINENT = MT.Continent or 2
local T_ZONE = MT.Zone or 3
local T_ORPHAN = MT.Orphan or 6
Maps.T_CONTINENT, Maps.T_ZONE = T_CONTINENT, T_ZONE

Maps.zones = {}       -- [uiMapID] = { map, name, area, cont }
Maps.byArea = {}      -- [areaID] = uiMapID
Maps.continents = {}  -- [uiMapID] = name
Maps.ready = false

local FALLBACK_ROOTS = { 947, 946, 1414, 1415, 12, 13 }

local function isZoneType(t)
    return t == T_ZONE or t == T_ORPHAN
end

local function continentOf(mapID)
    local guard = 0
    while mapID and mapID > 0 and guard < 10 do
        local info = C_Map.GetMapInfo(mapID)
        if not info then return nil end
        if info.mapType == T_CONTINENT then return mapID end
        mapID = info.parentMapID
        guard = guard + 1
    end
end

-- Builds the areaID -> uiMapID table. Returns true once usable.
function Maps:Ensure()
    if self.ready then return true end
    if not (C_Map and C_Map.GetMapInfo) then return false end

    local all, seen = {}, {}
    local function add(info)
        if info and not seen[info.mapID] then
            seen[info.mapID] = true
            all[#all + 1] = info
        end
    end
    local function collect(root)
        local info = C_Map.GetMapInfo(root)
        if not info then return end
        add(info)
        local kids = C_Map.GetMapChildrenInfo(root, nil, true)
        if kids then
            for i = 1, #kids do add(kids[i]) end
        end
    end

    -- Walk up from the player's map to the top of the hierarchy.
    local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local root, guard = nil, 0
    while m and m > 0 and guard < 10 do
        local info = C_Map.GetMapInfo(m)
        if not info then break end
        root = m
        m = info.parentMapID
        guard = guard + 1
    end
    if root then collect(root) end
    for i = 1, #FALLBACK_ROOTS do collect(FALLBACK_ROOTS[i]) end

    local byName = {}
    for i = 1, #all do
        local info = all[i]
        if info.mapType == T_CONTINENT then
            self.continents[info.mapID] = info.name
        elseif isZoneType(info.mapType) and info.name and not byName[info.name] then
            byName[info.name] = info
        end
    end

    local count = 0
    for i = 1, #ns.Data.zones do
        local area, classicID = ns.Data.zones[i][1], ns.Data.zones[i][2]
        local areaName = C_Map.GetAreaInfo and C_Map.GetAreaInfo(area)
        local info = areaName and byName[areaName]
        if not info then
            local c = C_Map.GetMapInfo(classicID)
            if c and isZoneType(c.mapType) and (not areaName or c.name == areaName) then
                info = c
            end
        end
        if info then
            local cont = continentOf(info.mapID)
            if cont and not self.continents[cont] then
                local ci = C_Map.GetMapInfo(cont)
                self.continents[cont] = ci and ci.name or tostring(cont)
            end
            self.zones[info.mapID] = { map = info.mapID, name = info.name, area = area, cont = cont }
            self.byArea[area] = info.mapID
            count = count + 1
        end
    end

    -- Zones that exist in the client but are not in our data (new Forever
    -- zones): keep them so they can be picked by name.
    self.extra = {}
    for name, info in pairs(byName) do
        if not self.zones[info.mapID] then
            self.extra[info.mapID] = { map = info.mapID, name = name, cont = continentOf(info.mapID) }
        end
    end

    self.ready = count > 0
    return self.ready
end

function Maps:Name(mapID)
    local z = self.zones[mapID] or (self.extra and self.extra[mapID])
    if z then return z.name end
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("#" .. tostring(mapID))
end

function Maps:AreaName(area, fallback)
    local n = C_Map.GetAreaInfo and C_Map.GetAreaInfo(area)
    return n or fallback
end

-- map percentages are 0-1 here.
function Maps:ToWorld(mapID, x, y)
    local inst, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if not inst or not pos then return nil end
    return inst, pos.x, pos.y
end

function Maps:FromWorld(inst, wx, wy, mapID)
    local _, pos = C_Map.GetMapPosFromWorldPos(inst, CreateVector2D(wx, wy), mapID)
    if not pos then return nil end
    return pos.x, pos.y
end

-- Creates a routable point. x, y in 0-1 on mapID (any map type: continent
-- coordinates are converted to the zone under them).
function Maps:Point(mapID, x, y, name)
    local info = C_Map.GetMapInfo(mapID)
    if not info then return nil end
    local inst, wx, wy = self:ToWorld(mapID, x, y)
    if not inst then return nil end
    local zmap, zx, zy = mapID, x, y
    if not isZoneType(info.mapType) then
        local child = C_Map.GetMapInfoAtPosition(mapID, x, y)
        if child and child.mapID ~= mapID then
            local cx, cy = self:FromWorld(inst, wx, wy, child.mapID)
            if cx then zmap, zx, zy = child.mapID, cx, cy end
        end
    end
    return {
        kind = "point", name = name,
        map = zmap, x = zx, y = zy,
        inst = inst, wx = wx, wy = wy,
        zones = { [zmap] = true },
    }
end

-- Point from data coordinates (areaID + percentages 0-100).
function Maps:AreaPoint(area, x, y, name)
    local mapID = self.byArea[area]
    if not mapID then return nil end
    return self:Point(mapID, x / 100, y / 100, name)
end

-- The player's position as a point on its zone map.
function Maps:PlayerPoint(name)
    local mapID = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while mapID and guard < 6 do
        local info = C_Map.GetMapInfo(mapID)
        if not info then return nil end
        if info.mapType <= T_ZONE or info.mapType == T_ORPHAN then break end
        mapID = info.parentMapID
        guard = guard + 1
    end
    if not mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    return self:Point(mapID, pos.x, pos.y, name)
end

function Maps:Distance(a, b)
    if a.inst ~= b.inst then return nil end
    local dx, dy = a.wx - b.wx, a.wy - b.wy
    return math.sqrt(dx * dx + dy * dy)
end
