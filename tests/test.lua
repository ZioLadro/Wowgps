-- Runs WowGPS against tests/mock.lua. Usage: see tests/run.py
local ROOT = ...
local mock = dofile(ROOT .. "/tests/mock.lua")

local FILES = { "Core", "Locale", "Data", "World", "Maps", "Player", "Taxi", "Landmarks", "Router",
                "Places", "Navigation", "RoutesBridge", "UI", "Commands" }

local ns
local function boot(faction)
    mock.faction = faction
    mock.taxi = {}
    mock.runSpeed, mock.mounted = 7, false
    mock.bind, mock.hearthCount, mock.hearthCooldown, mock.pvpInfo = nil, 0, 0, nil
    mock.player = { map = 1429, x = 0.5, y = 0.5 }
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

local function hasNote(opt, fragment)
    for _, n in ipairs(opt.notes) do
        if n:find(fragment, 1, true) then return true end
    end
    return false
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
check(not hasNote(by.walk, "Needs a boat"), "walk SW->IF needs no transport note")
check(by.transit.path.kinds.tram, "transit SW->IF takes the tram: " .. describe(by.transit.path))
check(by.transit.path.time < by.mount.path.time, "tram beats riding")
check(by.mount.path.time < by.walk.path.time, "riding beats walking")

-- 2. Alliance, Elwynn -> Darkshore needs boats ---------------------------
by = plan("Elwynn Forest 42 65", "Darkshore")
check(by.walk.path and by.walk.path.kinds.boat, "cross-continent walk falls back to the boat")
check(hasNote(by.walk, "Needs a boat"), "walk option explains it needs a boat")
check(not by.transit.path.kinds.zeppelin, "Alliance never rides the zeppelin")

-- 3. Flights --------------------------------------------------------------
mock.addTaxi(2, "Stormwind", 1519, 2)
mock.addTaxi(6, "Ironforge", 1537, 2)
mock.addTaxi(8, "Thelsamar", 38, 2)
mock.addTaxi(23, "Orgrimmar", 1637, 1)
ns.Router:Invalidate()
by = plan("Stormwind City", "Loch Modan")
check(by.flight.path.kinds.flight, "flight option flies when not scanned: " .. describe(by.flight.path))
check(hasNote(by.flight, "not scanned"), "flight option warns that taxi was not scanned")
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
check(by.walk.path and #by.walk.path.steps == 1 and hasNote(by.walk, "Straight line"), "straight-line fallback with a warning")

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
check(#path.steps == 2, "SW -> Elwynn is gate + road to destination: " .. describe(path))
check(path.steps[1].to.kind == "border", "first step ends at the city gate")
check(path.steps[2].onRoad and #path.steps[2].points > 2, "second step follows the road through several points")
ns.Nav:Start(path)
check(#TomTom.added == 1 and ns.Nav.index == 1, "first waypoint set")
local function standOn(n) mock.player = { map = n.map, x = n.x, y = n.y } end
standOn(path.steps[1].to)
ns.Nav:Tick()
check(ns.Nav.index == 2 and #TomTom.added == 2, "advances at the gate")
local pts = path.steps[2].points
standOn(pts[2])
ns.Nav:Tick()
check(ns.Nav.index == 2 and #TomTom.added == 3, "moves from bend to bend on the road")
standOn(pts[#pts - 1])
ns.Nav:Tick()
check(ns.Nav.index == 2 and ns.Nav.targets[ns.Nav.pos].node == pts[#pts], "cutting a bend skips ahead")
mock.player = { map = 1429, x = 0.6, y = 0.6 }
ns.Nav:Tick()
check(ns.Nav.path == nil and TomTom.removed == #TomTom.added, "arrival ends navigation and clears waypoints")
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

-- 9. Places inside zones and roads ---------------------------------------
boot("Alliance")
p = assert(ns.Places:Resolve("Goldshire"))
check(p.map == 1429 and math.abs(p.x - 0.42) < 1e-9, "towns are places")
check(ns.Places:Resolve("Booty Bay") and ns.Places:Resolve("gadget"), "more towns, partial names")
by = plan("Stormwind City", "Goldshire")
path = by.walk.path
local lastStep = path.steps[#path.steps]
check(lastStep.onRoad and lastStep.text:find("Follow the road", 1, true), "walks along the road: " .. lastStep.text)
check(#lastStep.points >= 3, "road step keeps its bends")
-- The road is longer than the crow flies but must beat the off-road penalty.
local gate = path.steps[1].to
local straight = ns.Maps:Distance(gate, p)
check(lastStep.dist > straight and lastStep.dist < straight * 1.5, "road length is plausible")
-- Roads continue across borders.
by = plan("Goldshire", "Lakeshire")
check(by.walk.path and #by.walk.notes == 1 and by.walk.notes[1]:find("Redridge", 1, true),
    "Goldshire -> Lakeshire warns about contested Redridge")
for _, st in ipairs(by.walk.path.steps) do
    check(st.onRoad, "every leg Goldshire -> Lakeshire is on a road: " .. st.text)
end
Routes = { db = { global = { routes = {} } } }
check(ns.RoutesBridge:Export(by.walk.path, "Lakeshire") == 2, "Routes gets one route per zone")
check(#Routes.db.global.routes[1429]["WowGPS: Lakeshire"].route > 4, "the exported route follows the bends")
Routes = nil

-- 10. Real movement speed -------------------------------------------------
by = plan("Stormwind City", "Goldshire")
local slow = by.walk.path.time
mock.runSpeed = 9.1
by = plan("Stormwind City", "Goldshire")
check(math.abs(by.walk.path.time - slow * 7 / 9.1) < 0.01, "walking time follows the character's run speed")
check(math.abs(by.mount.path.time - by.walk.path.time * 9.1 / 11.2) < 0.01, "unmeasured mount defaults to +60%")
mock.mounted, mock.runSpeed = true, 14
by = plan("Stormwind City", "Goldshire")
check(ns:MountSpeed() == 14 and ns:FootSpeed() == 9.1, "mount speed is measured while mounted")
check(math.abs(by.mount.path.time - slow * 7 / 14) < 0.01, "riding time follows the measured mount speed")
ns.db.mountSpeed = 0
check(ns:MountSpeed() == 9.1, "mount 0 means on foot")
ns.db.mountSpeed = "auto"
mock.mounted, mock.runSpeed = false, 7

-- 11. Hearthstone ----------------------------------------------------------
mock.player = { map = 1446, x = 0.5, y = 0.3 }   -- Tanaris
by = plan("", "Elwynn Forest 45 60")
check(by.hearth.path == nil and by.hearth.notes[1]:find("No Hearthstone", 1, true), "no hearthstone, no option")
mock.hearthCount, mock.bind = 1, "Goldshire"
by = plan("", "Elwynn Forest 45 60")
check(by.hearth.path and by.hearth.path.steps[1].kind == "hearth", "hearth to Goldshire first: " .. describe(by.hearth.path))
check(by.hearth.fastest and by.hearth.path.time < 120, "hearthstone is by far the fastest")
check(not by.flight.path.kinds.hearth, "other options do not use the hearthstone")
by = plan("", "Tanaris 55 35")
check(by.hearth.path == nil and by.hearth.notes[1]:find("does not shorten", 1, true), "hearth ignored when it does not help")
mock.hearthCooldown = 1500
by = plan("", "Elwynn Forest 45 60")
check(by.hearth.path == nil and by.hearth.notes[1]:find("ready in 25 min", 1, true), "cooldown is reported: " .. by.hearth.notes[1])
mock.hearthCooldown = 0
mock.bind = "The Salty Sailor"
by = plan("", "Elwynn Forest 45 60")
check(by.hearth.path == nil and by.hearth.notes[1]:find("do not know", 1, true), "unknown inn is reported")
-- Binding (or /gps home) at the inn records the exact spot.
mock.player = { map = 1434, x = 0.27, y = 0.77 }
SlashCmdList.WOWGPS("home")
check(ns.chardb.bind and ns.chardb.bind.map == 1434, "/gps home records the bind spot")
mock.player = { map = 1429, x = 0.5, y = 0.5 }
by = plan("", "Stranglethorn Vale 30 70")
check(by.hearth.path and by.hearth.path.kinds.hearth, "recorded inn is used")
p = assert(ns.Places:Resolve("home"))
check(p.map == 1434, "'home' is a place")

-- 12. Contested zones ------------------------------------------------------
check(ns.PvP:Status(1429) == "friendly" and ns.PvP:Status(1431) == "contested" and ns.PvP:Status(1411) == "hostile",
    "static zone ownership for the Alliance")
mock.hearthCount = 0
by = plan("Elwynn Forest", "Westfall")
check(#by.walk.notes == 0, "friendly trip has no warning")
by = plan("Elwynn Forest", "Darkshire")
check(by.walk.notes[1]:find("contested", 1, true) and by.walk.notes[1]:find("Duskwood", 1, true), "contested zones are listed")
-- Elwynn -> Raven Hill: through Westfall is friendly until Duskwood itself.
local function contestedYards(path2)
    local n = 0
    for z in pairs(path2.zones) do if ns.PvP:Status(z) ~= "friendly" then n = n + 1 end end
    return n
end
local normal = plan("Lakeshire", "Sentinel Hill").walk.path
ns.db.avoidContested = true
local careful = plan("Lakeshire", "Sentinel Hill").walk.path
check(careful.time >= normal.time - 0.01, "avoiding never makes the trip faster")
check(contestedYards(careful) <= contestedYards(normal), "avoiding never adds contested zones")
SlashCmdList.WOWGPS("avoid")
check(ns.db.avoidContested == false, "/gps avoid toggles")
-- What the game says about a zone wins over the table.
mock.player = { map = 1431, x = 0.5, y = 0.5 }
mock.pvpInfo = "sanctuary"
ns.PvP:OnZoneChanged()
check(ns.PvP:Status(1431) == "sanctuary", "zone status is learned in game")
by = plan("Elwynn Forest", "Darkshire")
check(not hasNote(by.walk, "Duskwood"), "learned status removes the warning for that zone")

-- 13. Saved places and recorded roads --------------------------------------
mock.player = { map = 9001, x = 0.2, y = 0.2 }
SlashCmdList.WOWGPS("save Fishing spot")
p = assert(ns.Places:Resolve("fishing"))
check(p.map == 9001, "saved places resolve")
SlashCmdList.WOWGPS("record")
for _, xy in ipairs({ { 0.3, 0.3 }, { 0.5, 0.35 }, { 0.7, 0.6 } }) do
    mock.player = { map = 9001, x = xy[1], y = xy[2] }
    mock.tickers[#mock.tickers].fn()
end
SlashCmdList.WOWGPS("record")
check(ns.db.userRoads[9001] and #ns.db.userRoads[9001][1] == 8, "recorded road has four points")
by = plan("Zephras Isle 20 20", "Zephras Isle 70 60")
check(by.walk.path.steps[1].onRoad, "recorded roads are used for routing")
SlashCmdList.WOWGPS("record clear")
check(ns.db.userRoads[9001] == nil, "/gps record clear")
SlashCmdList.WOWGPS("forget Fishing spot")
check(not ns.Places:Resolve("fishing"), "/gps forget")

-- 14. Horde ----------------------------------------------------------------
boot("Horde")
mock.player = { map = 1454, x = 0.5, y = 0.5 }
by = plan("Orgrimmar", "Undercity")
check(by.transit.path.kinds.zeppelin, "Horde Org -> UC takes the zeppelin: " .. describe(by.transit.path))
by = plan("Orgrimmar", "Ironforge")
check(by.transit.path and not by.transit.path.kinds.tram, "Horde does not use the tram")
by = plan("Orgrimmar", "Stranglethorn Vale")
check(by.transit.path.kinds.zeppelin or by.transit.path.kinds.boat, "Org -> STV by zeppelin or Ratchet boat")
by = plan("Durotar", "Teldrassil")
check(by.walk.path == nil or hasNote(by.walk, "Needs a boat") or hasNote(by.walk, "Straight line"), "Horde cannot reach Teldrassil by land")

return passed
