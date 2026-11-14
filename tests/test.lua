-- Runs WowGPS against tests/mock.lua. Usage: see tests/run.py
local ROOT = ...
local mock = dofile(ROOT .. "/tests/mock.lua")

local FILES = { "Core", "Locale", "Data", "Maps", "Taxi", "Router", "Places", "Navigation",
                "RoutesBridge", "UI", "Commands" }

local ns
local function boot(faction)
    mock.faction = faction
    mock.taxi = {}
    WowGPSDB, WowGPSCharDB, Routes, TomTom = nil, nil, nil, nil
    ns = {}
    local coreFrameIndex = #mock.frames + 1
    for _, f in ipairs(FILES) do
        local chunk = assert(loadfile(ROOT .. "/WowGPS/" .. f .. ".lua"))
        chunk("WowGPS", ns)
    end
    local onEvent = mock.frames[coreFrameIndex]._OnEvent
    onEvent(nil, "ADDON_LOADED", "WowGPS")
    onEvent(nil, "PLAYER_LOGIN")
    return ns
end

local passed = 0
local function check(cond, msg)
    if not cond then error("FAILED: " .. msg, 2) end
    passed = passed + 1
end

local function plan(from, to)
    local s = assert(ns.Places:Resolve(from))
    local d = assert(ns.Places:Resolve(to))
    local opts = assert(ns.Router:Plan(s, d))
    local by = {}
    for _, o in ipairs(opts) do by[o.key] = o end
    return by, opts
end

local function describe(path)
    local t = {}
    for _, st in ipairs(path.steps) do t[#t + 1] = st.kind end
    return table.concat(t, ",")
end

-- 1. Alliance, Stormwind -> Ironforge ------------------------------------
boot("Alliance")
check(ns.Maps:Ensure(), "maps resolve")
check(ns.Maps.byArea[12] == 1429, "Elwynn resolved by area name")
local by = plan("Stormwind City", "Ironforge")
check(by.walk.path and not by.walk.path.kinds.tram, "walk SW->IF is a land route: " .. describe(by.walk.path))
check(#by.walk.notes == 0, "walk SW->IF needs no transport note")
check(by.transit.path.kinds.tram, "transit SW->IF takes the tram: " .. describe(by.transit.path))
check(by.transit.path.time < by.mount.path.time, "tram beats riding")
check(by.mount.path.time < by.walk.path.time, "riding beats walking")

-- 2. Alliance, Elwynn -> Darkshore needs boats ---------------------------
by = plan("Elwynn Forest 42 65", "Darkshore")
check(by.walk.path and by.walk.path.kinds.boat, "cross-continent walk falls back to the boat")
check(#by.walk.notes == 1, "walk option explains it needs a boat")
check(not by.transit.path.kinds.zeppelin, "Alliance never rides the zeppelin")

-- 3. Flights --------------------------------------------------------------
mock.addTaxi(2, "Stormwind", 1519, 2)
mock.addTaxi(6, "Ironforge", 1537, 2)
mock.addTaxi(8, "Thelsamar", 38, 2)
mock.addTaxi(23, "Orgrimmar", 1637, 1)
ns.Router:Invalidate()
by = plan("Stormwind City", "Loch Modan")
check(by.flight.path.kinds.flight, "flight option flies when not scanned: " .. describe(by.flight.path))
check(#by.flight.notes == 1, "flight option warns that taxi was not scanned")
check(by.flight.fastest, "flight is the fastest SW -> Loch Modan")
-- Scanned, but only Stormwind known: no flight possible.
ns.chardb.taxiSeen[0] = true
ns.chardb.knownTaxi[2] = true
by = plan("Stormwind City", "Loch Modan")
check(not by.flight.path.kinds.flight, "unknown flight points are not used")
ns.chardb.knownTaxi[8] = true
by = plan("Stormwind City", "Loch Modan")
check(by.flight.path.kinds.flight, "known flight points are used")
ns.db.knownOnly = false
ns.chardb.knownTaxi[8] = nil
by = plan("Stormwind City", "Loch Modan")
check(by.flight.path.kinds.flight, "knownOnly off ignores discovery")
check(ns.Places:Resolve("Thelsamar"), "flight point names are places")
check(not ns.Places:Resolve("Orgrimmar 1 1 x"), "garbage is rejected")

-- 4. Places ---------------------------------------------------------------
local p = assert(ns.Places:Resolve("elwynn 42 65"))
check(p.map == 1429 and math.abs(p.x - 0.42) < 1e-9, "zone + coords")
p = assert(ns.Places:Resolve("10 20"))
check(p.map == 1429 and math.abs(p.y - 0.20) < 1e-9, "bare coords use the current zone")
p = assert(ns.Places:Resolve(""))
check(p.map == 1429, "empty = player")
check(not ns.Places:Resolve("pin"), "no pin set")
mock.userWaypoint = UiMapPoint.CreateFromCoordinates(1415, 0.5, 0.75)
p = assert(ns.Places:Resolve("pin"))
check(p.map ~= 1415 and ns.Maps.zones[p.map], "continent pin lands in a zone: " .. ns.Maps:Name(p.map))
mock.userWaypoint = nil
local sug = ns.Places:Suggest("st", 6)
check(#sug > 0 and sug[1]:lower():sub(1, 2) == "st", "suggestions, prefix first: " .. table.concat(sug, "|"))

-- 5. Zone without road data ----------------------------------------------
by = plan("Zephras Isle", "Badlands")
check(by.walk.path and #by.walk.path.steps == 1 and #by.walk.notes == 1, "straight-line fallback with a warning")

-- 6. Routes bridge --------------------------------------------------------
check(not ns.RoutesBridge:Available(), "Routes missing is detected")
Routes = { db = { global = { routes = { [1429] = { Farm = { route = { 12345678 } } } } } }, drawn = 0 }
function Routes:DrawWorldmapLines() self.drawn = self.drawn + 1 end
check(ns.RoutesBridge:Available(), "Routes detected")
local list = ns.RoutesBridge:ListRoutes()
check(#list == 1 and math.abs(list[1].x - 0.1234) < 1e-9 and math.abs(list[1].y - 0.5678) < 1e-9, "route list decodes coords")
p = assert(ns.Places:Resolve("Routes: Farm"))
check(p.map == 1429, "a Routes route is a place")
by = plan("Stormwind City", "Redridge Mountains")
local made = ns.RoutesBridge:Export(by.walk.path, "Redridge Mountains")
check(made >= 1, "export makes routes for the ground segments, got " .. made)
local elw = Routes.db.global.routes[1429]["WowGPS: Redridge Mountains"]
check(elw and #elw.route >= 2 and elw.looped == false, "Elwynn route stored")
check(Routes.drawn > 0, "Routes asked to redraw")
check(#ns.RoutesBridge:ListRoutes() == 1, "our own exports are not offered as places")
check(ns.RoutesBridge:Clear(true) == made, "clear removes exactly what we exported")
check(Routes.db.global.routes[1429].Farm, "user routes untouched")

-- 7. Navigation -----------------------------------------------------------
TomTom = { added = {}, removed = 0 }
function TomTom:AddWaypoint(map, x, y, o)
    self.added[#self.added + 1] = { map = map, x = x, y = y, title = o.title }
    return #self.added
end
function TomTom:RemoveWaypoint() self.removed = self.removed + 1 end
mock.player = { map = 1453, x = 0.5, y = 0.5 }
by = plan("", "Elwynn Forest 60 60")
local path = by.walk.path
check(#path.steps == 2, "SW -> Elwynn is gate + destination: " .. describe(path))
ns.Nav:Start(path)
check(#TomTom.added == 1 and ns.Nav.index == 1, "first waypoint set")
mock.player = { map = path.steps[1].to.map, x = path.steps[1].to.x, y = path.steps[1].to.y }
ns.Nav:Tick()
check(ns.Nav.index == 2 and #TomTom.added == 2, "advances at the gate")
mock.player = { map = 1429, x = 0.6, y = 0.6 }
ns.Nav:Tick()
check(ns.Nav.path == nil and TomTom.removed == 2, "arrival ends navigation and clears waypoints")
-- Without TomTom the built-in pin is used.
TomTom = nil
ns.Nav:Start(path)
check(mock.userWaypoint and mock.userWaypoint.uiMapID == path.steps[1].to.map, "native pin fallback")
ns.Nav:Stop(true)
check(mock.userWaypoint == nil, "native pin cleared")

-- 8. Slash commands and window -------------------------------------------
mock.player = { map = 1429, x = 0.5, y = 0.5 }
SlashCmdList.WOWGPS("from Stormwind City to Ironforge")
check(ns.UI.options and ns.UI:Selected().path, "/gps from A to B computes")
SlashCmdList.WOWGPS("da Elwynn Forest a Westfall")
check(ns.UI.options and ns.UI.destName == "Westfall", "/gps da A a B computes")
SlashCmdList.WOWGPS("Wetlands")
check(ns.UI.destName == "Wetlands", "/gps <place>")
SlashCmdList.WOWGPS("go 1")
check(ns.Nav.path == ns.UI.options[1].path, "/gps go 1 navigates option 1")
SlashCmdList.WOWGPS("stop")
check(ns.Nav.path == nil, "/gps stop")
SlashCmdList.WOWGPS("mount 100")
check(ns.db.mountSpeed == 100, "/gps mount")
SlashCmdList.WOWGPS("nowhere-land")
check(ns.UI.options == nil, "unknown place leaves no options")
for _, cmd in ipairs({ "", "help", "mark", "routes", "routes clear", "next" }) do SlashCmdList.WOWGPS(cmd) end

-- 9. Horde ----------------------------------------------------------------
boot("Horde")
mock.player = { map = 1454, x = 0.5, y = 0.5 }
by = plan("Orgrimmar", "Undercity")
check(by.transit.path.kinds.zeppelin, "Horde Org -> UC takes the zeppelin: " .. describe(by.transit.path))
by = plan("Orgrimmar", "Ironforge")
check(by.transit.path and not by.transit.path.kinds.tram, "Horde does not use the tram")
by = plan("Orgrimmar", "Stranglethorn Vale")
check(by.transit.path.kinds.zeppelin or by.transit.path.kinds.boat, "Org -> STV by zeppelin or Ratchet boat")
by = plan("Durotar", "Teldrassil")
check(by.walk.path == nil or #by.walk.notes > 0, "Horde cannot reach Teldrassil by land")

return passed
