-- WowGPS: named places inside zones (towns, camps, dungeon entrances) and
-- recording of real roads.
local _, ns = ...
local L = ns.L

local Landmarks = {}
ns.Landmarks = Landmarks

local MERGE_YARDS = 120

-- Returns a list of place points: the game's own map landmarks and dungeon
-- entrances first (localized, include new Forever places), then the entries
-- of Data.places that the game did not already report.
function Landmarks:Collect()
    local Maps = ns.Maps
    local out, byName = {}, {}

    local function add(name, mapID, x, y, static)
        if type(name) ~= "string" or name == "" or type(x) ~= "number" or type(y) ~= "number" then return end
        local key = name:lower() .. ":" .. mapID
        if byName[key] then return end
        local p = Maps:Point(mapID, x, y, name)
        if not p then return end
        if static then
            for i = 1, #out do
                local d = Maps:Distance(out[i], p)
                if d and d < MERGE_YARDS then return end
            end
        end
        p.kind, p.place = "place", name
        byName[key] = true
        out[#out + 1] = p
    end

    local function fromGame(mapID)
        if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap then
            local ids = C_AreaPoiInfo.GetAreaPOIForMap(mapID)
            for i = 1, ids and #ids or 0 do
                local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, ids[i])
                if info and info.position then add(info.name, mapID, info.position.x, info.position.y) end
            end
        end
        if C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap then
            local list = C_EncounterJournal.GetDungeonEntrancesForMap(mapID)
            for i = 1, list and #list or 0 do
                local e = list[i]
                if e and e.position then add(e.name, mapID, e.position.x, e.position.y) end
            end
        end
    end

    for mapID in pairs(Maps.zones) do pcall(fromGame, mapID) end
    for mapID in pairs(Maps.extra or {}) do pcall(fromGame, mapID) end

    for area, list in pairs(ns.Data.places) do
        local mapID = Maps.byArea[area]
        if mapID then
            for i = 1, #list do
                add(list[i][1], mapID, list[i][2] / 100, list[i][3] / 100, true)
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Road recorder: ride a road once and WowGPS will route along it.
---------------------------------------------------------------------------

local Recorder = {}
ns.Recorder = Recorder

local SAMPLE_YARDS = 40

local function flush(self)
    local line = self.line
    self.line, self.last = nil, nil
    if line and #line >= 4 then
        ns.db.userRoads[self.map] = ns.db.userRoads[self.map] or {}
        table.insert(ns.db.userRoads[self.map], line)
        self.saved = self.saved + 1
    end
end

function Recorder:Tick()
    local p = ns.Maps:PlayerPoint()
    if not p then return end
    if self.line and p.map ~= self.map then flush(self) end
    if not self.line then
        self.line, self.map, self.last = {}, p.map, nil
    end
    if not self.last or (ns.Maps:Distance(self.last, p) or 0) >= SAMPLE_YARDS then
        self.line[#self.line + 1] = math.floor(p.x * 10000 + 0.5) / 100
        self.line[#self.line + 1] = math.floor(p.y * 10000 + 0.5) / 100
        self.last = p
    end
end

function Recorder:Start()
    if self.ticker or not ns.Maps:Ensure() then return end
    self.saved = 0
    self.ticker = C_Timer.NewTicker(1, function() Recorder:Tick() end)
    self:Tick()
    ns:Print(L["Recording the road you travel. Type /gps record again to stop."])
end

function Recorder:Stop()
    if not self.ticker then return end
    self.ticker:Cancel()
    self.ticker = nil
    self:Tick()
    flush(self)
    ns.Router:Invalidate()
    ns:Print(string.format(L["Recording stopped: %d road segment(s) saved."], self.saved))
end

function Recorder:Toggle()
    if self.ticker then self:Stop() else self:Start() end
end

-- Forgets the recorded roads of the zone you are in.
function Recorder:ClearZone()
    local p = ns.Maps:Ensure() and ns.Maps:PlayerPoint()
    if not p then return end
    ns.db.userRoads[p.map] = nil
    ns.Router:Invalidate()
    ns:Print(string.format(L["Recorded roads removed for %s."], ns.Maps:Name(p.map)))
end
