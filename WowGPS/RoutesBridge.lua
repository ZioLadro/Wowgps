-- WowGPS: integration with the Routes addon (by Xinhuan).
--
--  * Export: the ground segments of a computed path become Routes routes
--    (one per zone, named "WowGPS: <destination>"). Routes then draws them on
--    the world map and minimap, and its own TomTom waypoint feature can
--    follow them node by node.
--  * Import: every route stored in Routes can be typed as a start or a
--    destination ("Routes: <name>"), e.g. to travel to your farming loop.
--
-- Routes stores routes in Routes.db.global.routes[uiMapID][name].route as a
-- list of packed coordinates. Everything here is guarded: if a future Routes
-- changes its internals we fail quietly instead of throwing errors.
local _, ns = ...
local L = ns.L

local Bridge = {}
ns.RoutesBridge = Bridge

local PREFIX = "WowGPS: "

local function routesDB()
    local R = _G.Routes
    if type(R) ~= "table" or type(R.db) ~= "table" or type(R.db.global) ~= "table" then return nil end
    local t = R.db.global.routes
    if type(t) ~= "table" then return nil end
    return t, R
end

function Bridge:Available()
    return routesDB() ~= nil
end

local function pack(R, x, y)
    if type(R.getID) == "function" then
        local ok, id = pcall(R.getID, R, x, y)
        if ok and type(id) == "number" then return id end
    end
    return math.floor(x * 10000 + 0.5) * 10000 + math.floor(y * 10000 + 0.5)
end

local function unpackID(R, id)
    if type(R.getXY) == "function" then
        local ok, x, y = pcall(R.getXY, R, id)
        if ok and type(x) == "number" and type(y) == "number" then return x, y end
    end
    return math.floor(id / 10000) / 10000, (id % 10000) / 10000
end

local function redraw(R)
    if type(R.DrawWorldmapLines) == "function" then pcall(R.DrawWorldmapLines, R) end
    if type(R.DrawMinimapLines) == "function" then pcall(R.DrawMinimapLines, R, true) end
end

-- { name, map, x, y } for the first node of every stored route.
function Bridge:ListRoutes()
    local out = {}
    local db, R = routesDB()
    if not db then return out end
    for zone, routes in pairs(db) do
        if type(zone) == "number" and type(routes) == "table" then
            for name, data in pairs(routes) do
                if type(name) == "string" and name:sub(1, #PREFIX) ~= PREFIX
                    and type(data) == "table" and type(data.route) == "table" and data.route[1] then
                    local x, y = unpackID(R, data.route[1])
                    out[#out + 1] = { name = name, map = zone, x = x, y = y }
                end
            end
        end
    end
    return out
end

function Bridge:Clear(silent)
    local db, R = routesDB()
    local n = 0
    if db then
        for _, e in ipairs(ns.db.exported) do
            if type(db[e.map]) == "table" and db[e.map][e.name] ~= nil then
                db[e.map][e.name] = nil
                n = n + 1
            end
        end
        redraw(R)
    end
    ns.db.exported = {}
    if not silent then ns:Print(string.format(L["Removed %d WowGPS route(s) from Routes."], n)) end
    return n
end

-- Pushes the walking parts of path into Routes. Returns number of routes made.
function Bridge:Export(path, destName)
    local db, R = routesDB()
    if not db then
        ns:Print(L["Routes addon not found."])
        return 0
    end
    self:Clear(true)

    -- Group consecutive ground steps by the zone they cross.
    local perZone, order = {}, {}
    local function push(mapID, node)
        local x, y = node.x, node.y
        if node.map ~= mapID then
            -- A border is stored on one zone's map; on the neighbour's map it
            -- can fall just off the edge. Clamp near misses, drop far ones.
            x, y = ns.Maps:FromWorld(node.inst, node.wx, node.wy, mapID)
            if not x or x < -0.2 or x > 1.2 or y < -0.2 or y > 1.2 then return end
            x = math.min(1, math.max(0, x))
            y = math.min(1, math.max(0, y))
        end
        local list = perZone[mapID]
        if not list then
            list = {}
            perZone[mapID] = list
            order[#order + 1] = mapID
        end
        local id = pack(R, x, y)
        if list[#list] ~= id then list[#list + 1] = id end
    end
    for _, st in ipairs(path.steps) do
        if st.kind == "walk" then
            local zone
            for z in pairs(st.from.zones) do
                if st.to.zones[z] then zone = z break end
            end
            zone = zone or st.to.map
            push(zone, st.from)
            push(zone, st.to)
        end
    end

    local made = 0
    local name = PREFIX .. (destName or "?")
    for _, mapID in ipairs(order) do
        local pts = perZone[mapID]
        if #pts >= 2 then
            -- Routes treats routes as closed loops. Walking the list back to
            -- the start makes the closing segment overlap the path instead of
            -- cutting a straight line across the zone.
            local route = {}
            for i = 1, #pts do route[#route + 1] = pts[i] end
            for i = #pts - 1, 2, -1 do route[#route + 1] = pts[i] end

            local ok = pcall(function()
                -- Indexing through AceDB creates the entry with Routes' own defaults.
                local zoneRoutes = db[mapID]
                if zoneRoutes == nil then
                    zoneRoutes = {}
                    db[mapID] = zoneRoutes
                end
                local entry = zoneRoutes[name]
                if entry == nil then
                    entry = {}
                    zoneRoutes[name] = entry
                end
                entry.route = route
                entry.hidden = false
                entry.visible = true
                entry.looped = false
                entry.color = entry.color or { 0.2, 0.8, 1, 1 }
                entry.width = entry.width or 35
            end)
            if ok then
                made = made + 1
                ns.db.exported[#ns.db.exported + 1] = { map = mapID, name = name }
            end
        end
    end

    redraw(R)
    if made > 0 then
        ns:Print(string.format(L["Sent to Routes: %d route(s). They are drawn on the map now; /reload to see them in the /routes list."], made))
    else
        ns:Print(L["Nothing to send: the route has no ground segments."])
    end
    return made
end
