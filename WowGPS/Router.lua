-- WowGPS: travel graph and route search.
--
-- Nodes: zone borders, transport stations, flight points, named places, road
-- points, plus the start and the destination. Edges:
--   road      between consecutive points of a road (Data.roads or recorded)
--   walk      between any two nodes of the same zone, cross-country
--   flight    between two usable flight points on the same continent
--   transport boat / zeppelin / tram / portal links from Data.lua
--   hearth    from the start to the hearthstone's bind location
-- Edge weights are seconds. Cross-country edges are penalised where a zone
-- has roads, so routes follow the road unless a shortcut is clearly shorter.
local _, ns = ...
local L = ns.L

local Router = {}
ns.Router = Router

local ROAD = 1.05             -- recorded points cut the bends a little
local OFFROAD = 1.5           -- cross-country in a zone that has road data
local PLAIN = 1.2             -- straight line in a zone without road data
local FLIGHT_SPEED = 32.0     -- yards per second on a taxi
local FLIGHT_DETOUR = 1.15
local FLIGHT_OVERHEAD = 20    -- talk to the flight master, take off, land
local AVOID = { contested = 3, hostile = 8 }  -- search penalty, not time

function Router:Invalidate()
    self.nodes = nil
end

local function stationName(st)
    return ns.Maps:AreaName(st.area, st.name) or st.name
end

local function linkRoad(a, b)
    if a == b then return end
    a.roads = a.roads or {}
    b.roads = b.roads or {}
    a.roads[b], b.roads[a] = true, true
end

function Router:Build()
    if self.nodes then return true end
    local Maps = ns.Maps
    if not Maps:Ensure() then return false end
    local nodes = {}
    local borderOf = {}   -- [areaA][areaB] = border node

    for i = 1, #ns.Data.borders do
        local b = ns.Data.borders[i]
        local ma, mb = Maps.byArea[b[1]], Maps.byArea[b[2]]
        if ma and mb then
            local p = Maps:AreaPoint(b[3], b[4], b[5])
            if p then
                p.kind = "border"
                p.zoneA, p.zoneB = ma, mb
                p.zones = { [ma] = true, [mb] = true }
                p.name = string.format(L["the %s / %s border"], Maps:Name(ma), Maps:Name(mb))
                nodes[#nodes + 1] = p
                borderOf[b[1]] = borderOf[b[1]] or {}
                borderOf[b[2]] = borderOf[b[2]] or {}
                borderOf[b[1]][b[2]], borderOf[b[2]][b[1]] = p, p
            end
        end
    end

    for i = 1, #ns.Data.transports do
        local t = ns.Data.transports[i]
        local a = Maps:AreaPoint(t.a.map, t.a.x, t.a.y)
        local b = Maps:AreaPoint(t.b.map, t.b.x, t.b.y)
        if a and b then
            a.kind, b.kind = "station", "station"
            a.transport, b.transport = t.kind, t.kind
            a.faction, b.faction = t.faction, t.faction
            a.place, b.place = stationName(t.a), stationName(t.b)
            a.links = { [b] = t }
            b.links = { [a] = t }
            nodes[#nodes + 1] = a
            nodes[#nodes + 1] = b
        end
    end

    self.taxi = {}
    local taxi = ns.Taxi:GetNodes()
    for i = 1, #taxi do
        local n = taxi[i]
        local p = Maps:Point(n.cont, n.x, n.y)
        if p then
            p.kind = "taxi"
            p.taxiID = n.id
            p.faction = n.faction
            p.place = n.name or "?"
            nodes[#nodes + 1] = p
            self.taxi[#self.taxi + 1] = p
        end
    end

    local places = ns.Landmarks:Collect()
    for i = 1, #places do nodes[#nodes + 1] = places[i] end

    -- Roads. Points shared by several roads become a single node.
    self.zoneRoads = {}
    local roadNodes = {}
    local function roadNode(mapID, x, y)
        local key = mapID .. ":" .. x .. ":" .. y
        local p = roadNodes[key]
        if not p then
            p = Maps:Point(mapID, x / 100, y / 100)
            if not p then return nil end
            p.kind = "road"
            p.zones = { [mapID] = true }
            p.map, p.x, p.y = mapID, x / 100, y / 100
            roadNodes[key] = p
            nodes[#nodes + 1] = p
        end
        return p
    end
    local function addRoad(mapID, area, line)
        local prev, i = nil, 1
        while i <= #line do
            local node
            if type(line[i]) == "string" then
                local other = tonumber(line[i]:sub(2))
                node = area and borderOf[area] and borderOf[area][other]
                i = i + 1
            else
                node = roadNode(mapID, line[i], line[i + 1])
                i = i + 2
            end
            if node then
                if prev then linkRoad(prev, node) end
                prev = node
                self.zoneRoads[mapID] = true
            end
        end
    end
    for area, roads in pairs(ns.Data.roads) do
        local mapID = Maps.byArea[area]
        if mapID then
            for i = 1, #roads do addRoad(mapID, area, roads[i]) end
        end
    end
    for mapID, roads in pairs(ns.db.userRoads) do
        if C_Map.GetMapInfo(mapID) then
            for i = 1, #roads do addRoad(mapID, nil, roads[i]) end
        end
    end

    self.byZone = {}
    for i = 1, #nodes do
        for z in pairs(nodes[i].zones) do
            local list = self.byZone[z]
            if not list then
                list = {}
                self.byZone[z] = list
            end
            list[#list + 1] = nodes[i]
        end
    end

    self.nodes = nodes
    return true
end

local function nodeLabel(n)
    if n.kind == "taxi" then
        return string.format(L["the flight master at %s"], n.place)
    elseif n.kind == "station" then
        if n.transport == "boat" then return string.format(L["the dock at %s"], n.place) end
        if n.transport == "zeppelin" then return string.format(L["the zeppelin tower at %s"], n.place) end
        if n.transport == "tram" then return string.format(L["the tram station in %s"], n.place) end
        return string.format(L["the portal at %s"], n.place)
    elseif n.kind == "border" then
        return n.name
    elseif n.kind == "place" or n.kind == "hearth" then
        return n.place
    end
    return n.name or L["your destination"]
end
Router.NodeLabel = nodeLabel

local function sharedZone(a, b)
    for z in pairs(a.zones) do
        if b.zones[z] then return z end
    end
end
Router.SharedZone = sharedZone

local function stepText(st, mounted)
    local a, b, kind = st.from, st.to, st.kind
    if kind == "walk" then
        if st.onRoad then return string.format(L["Follow the road to %s"], nodeLabel(b)) end
        return string.format(mounted and L["Ride to %s"] or L["Walk to %s"], nodeLabel(b))
    elseif kind == "flight" then
        return string.format(L["Fly from %s to %s"], a.place, b.place)
    elseif kind == "boat" then
        return string.format(L["Take the boat from %s to %s"], a.place, b.place)
    elseif kind == "zeppelin" then
        return string.format(L["Take the zeppelin from %s to %s"], a.place, b.place)
    elseif kind == "tram" then
        return string.format(L["Take the Deeprun Tram from %s to %s"], a.place, b.place)
    elseif kind == "hearth" then
        return string.format(L["Use your Hearthstone to %s"], b.place)
    end
    return string.format(L["Take the portal from %s to %s"], a.place, b.place)
end

-- Dijkstra from s to e.
-- o = { speed, mounted, flights, transports, knownOnly, avoid, hearth }
function Router:Search(s, e, o)
    local Maps = ns.Maps
    local faction = ns.faction or UnitFactionGroup("player")
    local function usable(n)
        return not n.faction or n.faction == faction
    end

    -- Start, destination and hearth location are not in the zone index.
    local temp = { s, e }
    if o.hearth then temp[3] = o.hearth.node end

    local cost, prev, via, done = { [s] = 0 }, {}, {}, {}
    local open = { s }

    local function relax(a, b, base, c, kind, time, yards, zone, onRoad)
        if done[b] then return end
        local total = base + c
        if not cost[b] then open[#open + 1] = b end
        if not cost[b] or total < cost[b] then
            cost[b] = total
            prev[b] = a
            via[b] = { kind = kind, time = time, dist = yards, zone = zone, onRoad = onRoad }
        end
    end

    local function walk(a, b, base)
        if a == b or done[b] or not usable(b) then return end
        local z = sharedZone(a, b)
        if not z then return end
        local d = Maps:Distance(a, b)
        if not d then return end
        local road = a.roads and a.roads[b]
        local factor = road and ROAD or (self.zoneRoads[z] and OFFROAD or PLAIN)
        local time = d * factor / o.speed
        local c = time
        if o.avoid then c = c * (AVOID[ns.PvP:Status(z)] or 1) end
        relax(a, b, base, c, "walk", time, d * factor, z, road and true or false)
    end

    while true do
        local u, uc, ui = nil, math.huge, nil
        for i = 1, #open do
            local n = open[i]
            if cost[n] < uc then u, uc, ui = n, cost[n], i end
        end
        if not u then break end
        open[ui] = open[#open]
        open[#open] = nil
        done[u] = true
        if u == e then break end

        for z in pairs(u.zones) do
            local list = self.byZone[z]
            for i = 1, list and #list or 0 do walk(u, list[i], uc) end
        end
        for i = 1, #temp do walk(u, temp[i], uc) end

        if o.flights and u.kind == "taxi" and (not o.knownOnly or ns.Taxi:IsKnown(u.taxiID)) then
            for i = 1, #self.taxi do
                local b = self.taxi[i]
                if b ~= u and usable(b) and (not o.knownOnly or ns.Taxi:IsKnown(b.taxiID)) then
                    local d = Maps:Distance(u, b)
                    if d then
                        local t = FLIGHT_OVERHEAD + d * FLIGHT_DETOUR / FLIGHT_SPEED
                        relax(u, b, uc, t, "flight", t, d * FLIGHT_DETOUR)
                    end
                end
            end
        end
        if o.transports and u.links then
            for b, t in pairs(u.links) do
                if usable(b) then relax(u, b, uc, t.time, t.kind, t.time, 0) end
            end
        end
        if o.hearth and u == s then
            relax(u, o.hearth.node, uc, o.hearth.time, "hearth", o.hearth.time, 0)
        end
    end
    if not cost[e] then return nil end

    -- Edges, start to destination.
    local edges, n = {}, e
    while prev[n] do
        local st = via[n]
        st.from, st.to = prev[n], n
        table.insert(edges, 1, st)
        n = prev[n]
    end

    -- Merge runs of ground edges that only pass through unnamed road points
    -- into one step; the points in between are kept for navigation.
    local path = { steps = {}, time = 0, dist = 0, kinds = {}, zones = {} }
    local cur
    for i = 1, #edges do
        local st = edges[i]
        path.time = path.time + st.time
        path.dist = path.dist + st.dist
        if st.kind == "walk" then
            if st.zone then path.zones[st.zone] = true end
            if st.dist >= 15 or st.to == e then
                if cur and cur.to.kind == "road" then
                    cur.to = st.to
                    cur.time = cur.time + st.time
                    cur.dist = cur.dist + st.dist
                    cur.onRoad = cur.onRoad or st.onRoad
                    cur.points[#cur.points + 1] = st.to
                else
                    cur = { kind = "walk", from = st.from, to = st.to, time = st.time, dist = st.dist,
                            onRoad = st.onRoad, points = { st.from, st.to } }
                    path.steps[#path.steps + 1] = cur
                end
            end
        else
            cur = nil
            st.points = { st.from, st.to }
            path.steps[#path.steps + 1] = st
        end
        path.kinds[st.kind] = true
    end
    for i = 1, #path.steps do
        path.steps[i].text = stepText(path.steps[i], o.mounted)
    end
    return path
end

local function zoneNote(path, status, fmt, notes)
    local names = {}
    for z in pairs(path.zones) do
        if ns.PvP:Status(z) == status then names[#names + 1] = ns.Maps:Name(z) end
    end
    if #names > 0 then
        table.sort(names)
        notes[#notes + 1] = string.format(fmt, table.concat(names, ", "))
    end
end

-- Returns the list of travel options for start -> dest (points from Maps).
-- Each option: { key, label, path = nil|path, notes = {} }
function Router:Plan(start, dest)
    if not self:Build() then return nil, L["Map data is not ready yet, try again in a moment."] end
    start.name = start.name or L["My position"]
    dest.kind = dest.kind == "hearth" and "place" or "dest"

    ns:SampleSpeed()
    local footSpeed, mountSpeed = ns:FootSpeed(), ns:MountSpeed()
    local mounted = mountSpeed > footSpeed
    local knownOnly = ns.db.knownOnly
    local scanned = ns.chardb.taxiSeen[start.inst] and ns.chardb.taxiSeen[dest.inst]
    if knownOnly and not scanned then knownOnly = false end
    local avoid = ns.db.avoidContested
    local hearth = ns.Hearth:Get()

    local defs = {
        { key = "walk", label = L["On foot"], speed = footSpeed, fallback = true },
        { key = "mount", label = L["Mount"], speed = mountSpeed, mounted = mounted, fallback = true },
        { key = "transit", label = L["Boats / zeppelins / tram"], speed = mountSpeed, mounted = mounted, transports = true },
        { key = "flight", label = L["Flight paths"], speed = mountSpeed, mounted = mounted, transports = true, flights = true },
        { key = "hearth", label = L["Hearthstone"], speed = mountSpeed, mounted = mounted, transports = true, flights = true, hearth = true },
    }

    local options = {}
    for i = 1, #defs do
        local d = defs[i]
        local opt = { key = d.key, label = d.label, notes = {} }
        local o = { speed = d.speed, mounted = d.mounted, transports = d.transports,
                    flights = d.flights, knownOnly = knownOnly, avoid = avoid }
        if d.hearth then
            if hearth.node then
                o.hearth = hearth
            elseif hearth.reason == "none" then
                opt.notes[#opt.notes + 1] = L["No Hearthstone in your bags."]
            elseif hearth.reason == "cooldown" then
                opt.notes[#opt.notes + 1] = string.format(L["Hearthstone (%s) ready in %s."], hearth.name, ns.FormatTime(hearth.left))
            else
                opt.notes[#opt.notes + 1] = L["I do not know where your Hearthstone is bound: set it at an innkeeper again, or record the spot with /gps home."]
            end
        end
        if not d.hearth or o.hearth then
            opt.path = self:Search(start, dest, o)
        end
        if d.hearth and opt.path and not opt.path.kinds.hearth then
            opt.path = nil
            opt.notes[#opt.notes + 1] = string.format(L["Hearthstone (%s) does not shorten this trip."], hearth.name)
        end
        if not opt.path and d.fallback then
            o.transports = true
            opt.path = self:Search(start, dest, o)
            if opt.path then opt.notes[#opt.notes + 1] = L["Needs a boat/zeppelin/tram: there is no land route."] end
        end
        if not opt.path and not d.flights then
            -- Zone without road data (e.g. a new Forever zone): straight line.
            local dist = ns.Maps:Distance(start, dest)
            if dist then
                local st = { kind = "walk", from = start, to = dest, dist = dist * PLAIN,
                             time = dist * PLAIN / d.speed, points = { start, dest } }
                st.text = stepText(st, d.mounted)
                opt.path = { steps = { st }, time = st.time, dist = st.dist, kinds = { walk = true }, zones = {} }
                opt.notes[#opt.notes + 1] = L["Straight line, no road data for this area (rough estimate)."]
            end
        end
        if opt.path then
            zoneNote(opt.path, "contested", L["Crosses contested zones: %s"], opt.notes)
            zoneNote(opt.path, "hostile", L["Crosses enemy territory: %s"], opt.notes)
        end
        if d.flights and opt.path and not scanned then
            opt.notes[#opt.notes + 1] = L["Flight points not scanned yet on this continent: open a flight master once for exact results."]
        end
        options[#options + 1] = opt
    end

    local fastest
    for i = 1, #options do
        local p = options[i].path
        if p and (not fastest or p.time < fastest.path.time - 0.5) then fastest = options[i] end
    end
    if fastest then fastest.fastest = true end
    return options
end
