-- Minimal fake of the WoW API, enough to run WowGPS outside the game.
-- The world is a grid: every zone is one 2500 x 2000 yard cell.
local M = {}

local CELL_W, CELL_H = 2500, 2000

local NAMES = {
    [1] = "Dun Morogh", [3] = "Badlands", [4] = "Blasted Lands", [8] = "Swamp of Sorrows",
    [10] = "Duskwood", [11] = "Wetlands", [12] = "Elwynn Forest", [28] = "Western Plaguelands",
    [33] = "Stranglethorn Vale", [36] = "Alterac Mountains", [38] = "Loch Modan", [40] = "Westfall",
    [41] = "Deadwind Pass", [44] = "Redridge Mountains", [45] = "Arathi Highlands",
    [46] = "Burning Steppes", [47] = "The Hinterlands", [51] = "Searing Gorge",
    [85] = "Tirisfal Glades", [130] = "Silverpine Forest", [139] = "Eastern Plaguelands",
    [267] = "Hillsbrad Foothills", [1497] = "Undercity", [1519] = "Stormwind City",
    [1537] = "Ironforge", [14] = "Durotar", [15] = "Dustwallow Marsh", [16] = "Azshara",
    [17] = "The Barrens", [141] = "Teldrassil", [148] = "Darkshore", [215] = "Mulgore",
    [331] = "Ashenvale", [357] = "Feralas", [361] = "Felwood", [400] = "Thousand Needles",
    [405] = "Desolace", [406] = "Stonetalon Mountains", [440] = "Tanaris",
    [490] = "Un'Goro Crater", [493] = "Moonglade", [618] = "Winterspring", [1377] = "Silithus",
    [1637] = "Orgrimmar", [1638] = "Thunder Bluff", [1657] = "Darnassus",
    [392] = "Ratchet", [35] = "Booty Bay", [150] = "Menethil Harbor", [513] = "Theramore Isle",
    [442] = "Auberdine", [702] = "Rut'theran Village", [117] = "Grom'gol Base Camp",
}

-- areaID -> { classic uiMapID, continent, col, row }
local EK, KAL = 1415, 1414
local GRID = {
    [85] = { 1420, EK, 0, 0 }, [28] = { 1422, EK, 1, 0 }, [139] = { 1423, EK, 2, 0 }, [1497] = { 1458, EK, -1, 0 },
    [130] = { 1421, EK, 0, 1 }, [36] = { 1416, EK, 1, 1 }, [47] = { 1425, EK, 2, 1 },
    [267] = { 1424, EK, 1, 2 }, [45] = { 1417, EK, 2, 2 },
    [11] = { 1437, EK, 1, 3 },
    [1] = { 1426, EK, 0, 4 }, [38] = { 1432, EK, 1, 4 }, [1537] = { 1455, EK, -1, 4 },
    [51] = { 1427, EK, 0, 5 }, [3] = { 1418, EK, 1, 5 },
    [46] = { 1428, EK, 0, 6 },
    [12] = { 1429, EK, 0, 7 }, [44] = { 1433, EK, 1, 7 }, [1519] = { 1453, EK, -1, 7 },
    [40] = { 1436, EK, -1, 8 }, [10] = { 1431, EK, 0, 8 }, [41] = { 1430, EK, 1, 8 }, [8] = { 1435, EK, 2, 8 },
    [33] = { 1434, EK, 0, 9 }, [4] = { 1419, EK, 2, 9 },
    [141] = { 1438, KAL, 0, 0 }, [1657] = { 1457, KAL, -1, 0 }, [493] = { 1450, KAL, 1, 0 }, [618] = { 1452, KAL, 2, 0 },
    [148] = { 1439, KAL, 0, 1 }, [361] = { 1448, KAL, 1, 1 },
    [331] = { 1440, KAL, 1, 2 }, [16] = { 1447, KAL, 2, 2 },
    [406] = { 1442, KAL, 0, 3 }, [1637] = { 1454, KAL, 2, 3 },
    [17] = { 1413, KAL, 1, 4 }, [14] = { 1411, KAL, 2, 4 },
    [405] = { 1443, KAL, 0, 5 }, [215] = { 1412, KAL, 0, 6 }, [1638] = { 1456, KAL, -1, 6 },
    [15] = { 1445, KAL, 2, 6 },
    [357] = { 1444, KAL, 0, 7 }, [400] = { 1441, KAL, 1, 7 },
    [1377] = { 1451, KAL, 0, 8 }, [490] = { 1449, KAL, 1, 8 }, [440] = { 1446, KAL, 2, 8 },
}

local maps = {
    [947] = { mapID = 947, name = "Azeroth", mapType = 1, parentMapID = 0 },
    [EK] = { mapID = EK, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947, inst = 0 },
    [KAL] = { mapID = KAL, name = "Kalimdor", mapType = 2, parentMapID = 947, inst = 1 },
    -- A zone that is not in Data.lua, standing in for a new Forever zone.
    [9001] = { mapID = 9001, name = "Zephras Isle", mapType = 3, parentMapID = EK, inst = 0, col = 2, row = 5 },
}
for area, g in pairs(GRID) do
    maps[g[1]] = { mapID = g[1], name = NAMES[area], mapType = 3, parentMapID = g[2],
                   inst = maps[g[2]].inst, col = g[3], row = g[4] }
end
M.maps = maps
M.area = function(area) return GRID[area][1] end

-- Continents span cols -1..3 and rows 0..10.
local function toWorld(mapID, x, y)
    local m = maps[mapID]
    if not m or not m.inst then return nil end
    if m.mapType == 2 then
        return m.inst, (-1 + x * 4) * CELL_W, y * 10 * CELL_H
    end
    return m.inst, (m.col + x) * CELL_W, (m.row + y) * CELL_H
end

local function fromWorld(inst, wx, wy, mapID)
    local m = maps[mapID]
    if not m or m.inst ~= inst then return nil end
    if m.mapType == 2 then
        return (wx / CELL_W + 1) / 4, wy / CELL_H / 10
    end
    return wx / CELL_W - m.col, wy / CELL_H - m.row
end

function CreateVector2D(x, y) return { x = x, y = y } end

M.player = { map = 1429, x = 0.5, y = 0.5 }
M.faction = "Alliance"
M.taxi = {}       -- list of { nodeID, name, cont, x, y, faction }
M.userWaypoint = nil

C_Map = {
    GetMapInfo = function(id)
        local m = maps[id]
        if not m then return nil end
        return { mapID = m.mapID, name = m.name, mapType = m.mapType, parentMapID = m.parentMapID }
    end,
    GetMapChildrenInfo = function(id)
        local out = {}
        local function isUnder(m)
            local guard = 0
            while m and guard < 5 do
                if m.parentMapID == id then return true end
                m = maps[m.parentMapID]
                guard = guard + 1
            end
        end
        for _, m in pairs(maps) do
            if isUnder(m) then out[#out + 1] = C_Map.GetMapInfo(m.mapID) end
        end
        return out
    end,
    GetAreaInfo = function(area) return NAMES[area] end,
    GetBestMapForUnit = function() return M.player.map end,
    GetPlayerMapPosition = function(mapID)
        local inst, wx, wy = toWorld(M.player.map, M.player.x, M.player.y)
        local x, y = fromWorld(inst, wx, wy, mapID)
        return x and CreateVector2D(x, y) or nil
    end,
    GetWorldPosFromMapPos = function(mapID, v)
        local inst, wx, wy = toWorld(mapID, v.x, v.y)
        if not inst then return nil end
        return inst, CreateVector2D(wx, wy)
    end,
    GetMapPosFromWorldPos = function(inst, v, mapID)
        local x, y = fromWorld(inst, v.x, v.y, mapID)
        if not x then return nil end
        return mapID, CreateVector2D(x, y)
    end,
    GetMapInfoAtPosition = function(mapID, x, y)
        local inst, wx, wy = toWorld(mapID, x, y)
        for _, m in pairs(maps) do
            if m.mapType == 3 and m.inst == inst then
                local zx, zy = fromWorld(inst, wx, wy, m.mapID)
                if zx >= 0 and zx <= 1 and zy >= 0 and zy <= 1 then return C_Map.GetMapInfo(m.mapID) end
            end
        end
    end,
    GetUserWaypoint = function() return M.userWaypoint end,
    SetUserWaypoint = function(p) M.userWaypoint = p end,
    ClearUserWaypoint = function() M.userWaypoint = nil end,
}

UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, position = CreateVector2D(x, y) } end }

C_TaxiMap = {
    GetTaxiNodesForMap = function(cont)
        local out = {}
        for _, n in ipairs(M.taxi) do
            if n.cont == cont then
                out[#out + 1] = { nodeID = n.nodeID, name = n.name, position = CreateVector2D(n.x, n.y), faction = n.faction }
            end
        end
        return out
    end,
}

-- Adds a flight point in the middle of a zone. faction: 0 neutral, 1 Horde, 2 Alliance.
function M.addTaxi(id, name, area, faction)
    local g = GRID[area]
    local inst, wx, wy = toWorld(g[1], 0.5, 0.5)
    local x, y = fromWorld(inst, wx, wy, g[2])
    M.taxi[#M.taxi + 1] = { nodeID = id, name = name, cont = g[2], x = x, y = y, faction = faction }
end

Enum = {
    UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 },
    FlightPathFaction = { Neutral = 0, Horde = 1, Alliance = 2 },
    FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 },
}

function UnitFactionGroup() return M.faction end
function GetLocale() return "enUS" end
function ReloadUI() end

M.printed = {}
function print(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    M.printed[#M.printed + 1] = table.concat(t, " ")
end

M.tickers = {}
C_Timer = {
    NewTicker = function(_, fn)
        local t = { fn = fn, Cancel = function(self) self.cancelled = true end }
        M.tickers[#M.tickers + 1] = t
        return t
    end,
    After = function(_, fn) fn() end,
}

-- Frames: every unknown method is a no-op; a few keep state.
local frameMT = {}
frameMT.__index = function(_, k)
    if k == "SetText" then return function(self, t) self._text = t end end
    if k == "GetText" then return function(self) return self._text or "" end end
    if k == "Show" then return function(self) self._shown = true end end
    if k == "Hide" then return function(self) self._shown = false end end
    if k == "IsShown" then return function(self) return self._shown ~= false end end
    if k == "GetStringHeight" then return function() return 0 end end
    if k == "CreateFontString" or k == "CreateTexture" or k == "GetFontString" then
        return function() return setmetatable({}, frameMT) end
    end
    if k == "SetScript" then return function(self, name, fn) self["_" .. name] = fn end end
    if k == "GetChecked" then return function() return true end end
    if k:match("^[A-Z]") then return function() end end
end
M.frames = {}
function CreateFrame(_, name)
    local f = setmetatable({}, frameMT)
    M.frames[#M.frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = CreateFrame("Frame")
UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}

return M
