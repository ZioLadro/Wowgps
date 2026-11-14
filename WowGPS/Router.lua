-- WowGPS: travel graph and route search.
--
-- Nodes: zone borders, transport stations, flight points, plus the start and
-- the destination. Edges:
--   walk      between any two nodes that sit in the same zone (straight line)
--   flight    between two usable flight points on the same continent
--   transport boat / zeppelin / tram / portal links from Data.lua
-- Edge weights are seconds. Dijkstra over a few hundred nodes is instant.
local _, ns = ...
local L = ns.L

local Router = {}
ns.Router = Router

local DETOUR = 1.2            -- roads are not straight lines
local FLIGHT_SPEED = 32.0     -- yards per second on a taxi
local FLIGHT_DETOUR = 1.15
local FLIGHT_OVERHEAD = 20    -- talk to the flight master, take off, land

function Router:Invalidate()
    self.nodes = nil
end

local function stationName(st)
    return ns.Maps:AreaName(st.area, st.name) or st.name
end

function Router:Build()
    if self.nodes then return true end
    local Maps = ns.Maps
    if not Maps:Ensure() then return false end
    local nodes = {}

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
    end
    return n.name or L["your destination"]
end
Router.NodeLabel = nodeLabel

local function shareZone(a, b)
    for z in pairs(a.zones) do
        if b.zones[z] then return true end
    end
    return false
end

-- Cheapest direct edge a -> b under options o. Returns seconds, kind, yards.
local function edge(a, b, o)
    local best, kind, yards
    local d = ns.Maps:Distance(a, b)
    if d and shareZone(a, b) then
        best, kind, yards = d * DETOUR / o.speed, "walk", d * DETOUR
    end
    if o.flights and d and a.kind == "taxi" and b.kind == "taxi"
        and (not o.knownOnly or (ns.Taxi:IsKnown(a.taxiID) and ns.Taxi:IsKnown(b.taxiID))) then
        local c = FLIGHT_OVERHEAD + d * FLIGHT_DETOUR / FLIGHT_SPEED
        if not best or c < best then best, kind, yards = c, "flight", d * FLIGHT_DETOUR end
    end
    if o.transports and a.links and a.links[b] then
        local t = a.links[b]
        if not best or t.time < best then best, kind, yards = t.time, t.kind, 0 end
    end
    return best, kind, yards
end

local function stepText(kind, a, b, mounted)
    if kind == "walk" then
        return string.format(mounted and L["Ride to %s"] or L["Walk to %s"], nodeLabel(b))
    elseif kind == "flight" then
        return string.format(L["Fly from %s to %s"], a.place, b.place)
    elseif kind == "boat" then
        return string.format(L["Take the boat from %s to %s"], a.place, b.place)
    elseif kind == "zeppelin" then
        return string.format(L["Take the zeppelin from %s to %s"], a.place, b.place)
    elseif kind == "tram" then
        return string.format(L["Take the Deeprun Tram from %s to %s"], a.place, b.place)
    end
    return string.format(L["Take the portal from %s to %s"], a.place, b.place)
end

-- Dijkstra from s to e. o = { speed, flights, transports, knownOnly, mounted }.
function Router:Search(s, e, o)
    local faction = ns.faction or UnitFactionGroup("player")
    local nodes = { s, e }
    for i = 1, #self.nodes do
        local n = self.nodes[i]
        if not n.faction or n.faction == faction then
            nodes[#nodes + 1] = n
        end
    end
    local n = #nodes
    local cost, prev, via, done = { 0 }, {}, {}, {}
    while true do
        local u, uc = nil, math.huge
        for i = 1, n do
            if not done[i] and cost[i] and cost[i] < uc then u, uc = i, cost[i] end
        end
        if not u or u == 2 then break end
        done[u] = true
        local a = nodes[u]
        for v = 1, n do
            if not done[v] then
                local c, kind, yards = edge(a, nodes[v], o)
                if c and (not cost[v] or uc + c < cost[v]) then
                    cost[v] = uc + c
                    prev[v] = u
                    via[v] = { kind = kind, time = c, dist = yards }
                end
            end
        end
    end
    if not cost[2] then return nil end

    local steps, i = {}, 2
    while prev[i] do
        local st = via[i]
        st.from, st.to = nodes[prev[i]], nodes[i]
        table.insert(steps, 1, st)
        i = prev[i]
    end
    local path = { steps = {}, time = 0, dist = 0, kinds = {} }
    for k = 1, #steps do
        local st = steps[k]
        -- Drop zero-length hops (e.g. two borders stacked on the same spot).
        if not (st.kind == "walk" and st.dist < 1) then
            st.text = stepText(st.kind, st.from, st.to, o.mounted)
            path.steps[#path.steps + 1] = st
            path.kinds[st.kind] = true
        end
        path.time = path.time + st.time
        path.dist = path.dist + st.dist
    end
    return path
end

-- Returns the list of travel options for start -> dest (points from Maps).
-- Each option: { key, label, path = nil|path, notes = {} }
function Router:Plan(start, dest)
    if not self:Build() then return nil, L["Map data is not ready yet, try again in a moment."] end
    start.name = start.name or L["My position"]
    dest.kind = "dest"

    local mountSpeed = ns:GroundSpeed()
    local mounted = mountSpeed > ns.WALK_SPEED
    local knownOnly = ns.db.knownOnly
    local scanned = ns.chardb.taxiSeen[start.inst] and ns.chardb.taxiSeen[dest.inst]
    if knownOnly and not scanned then knownOnly = false end

    local defs = {
        { key = "walk", label = L["On foot"], speed = ns.WALK_SPEED, fallback = true },
        { key = "mount", label = L["Mount"], speed = mountSpeed, mounted = mounted, fallback = true },
        { key = "transit", label = L["Boats / zeppelins / tram"], speed = mountSpeed, mounted = mounted, transports = true },
        { key = "flight", label = L["Flight paths"], speed = mountSpeed, mounted = mounted, transports = true, flights = true },
    }

    local options = {}
    for i = 1, #defs do
        local d = defs[i]
        local opt = { key = d.key, label = d.label, notes = {} }
        local o = { speed = d.speed, mounted = d.mounted, transports = d.transports,
                    flights = d.flights, knownOnly = knownOnly }
        opt.path = self:Search(start, dest, o)
        if not opt.path and d.fallback then
            o.transports = true
            opt.path = self:Search(start, dest, o)
            if opt.path then opt.notes[#opt.notes + 1] = L["Needs a boat/zeppelin/tram: there is no land route."] end
        end
        if not opt.path and not d.flights then
            -- Zone without road data (e.g. a new Forever zone): straight line.
            local dist = ns.Maps:Distance(start, dest)
            if dist then
                local st = { kind = "walk", from = start, to = dest, dist = dist * DETOUR,
                             time = dist * DETOUR / d.speed }
                st.text = stepText("walk", start, dest, d.mounted)
                opt.path = { steps = { st }, time = st.time, dist = st.dist, kinds = { walk = true } }
                opt.notes[#opt.notes + 1] = L["Straight line, no road data for this area (rough estimate)."]
            end
        end
        if d.flights and not scanned then
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
