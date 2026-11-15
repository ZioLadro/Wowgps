-- WowGPS: turns what the user typed into a point on the map.
-- Accepted: empty / "here" / "qui" (player), "pin" (map pin), "42 65"
-- (current zone), "<zone> 42 65", a zone, a flight point, a station, or
-- "routes: <name>" (first node of a route from the Routes addon).
local _, ns = ...
local L = ns.L

local Places = {}
ns.Places = Places

local HERE = { [""] = true, here = true, me = true, qui = true, io = true }
local HOME = { home = true, hearth = true, hearthstone = true, casa = true, locanda = true }
local PIN = { pin = true, waypoint = true }

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- List of { name, lower, make = function() -> point }
function Places:Catalog()
    local Maps = ns.Maps
    local list = {}
    local function add(name, make)
        list[#list + 1] = { name = name, lower = name:lower(), make = make }
    end
    for mapID, z in pairs(Maps.zones) do
        add(z.name, function(x, y) return Maps:Point(mapID, x or 0.5, y or 0.5, z.name) end)
    end
    for mapID, z in pairs(Maps.extra or {}) do
        add(z.name, function(x, y) return Maps:Point(mapID, x or 0.5, y or 0.5, z.name) end)
    end
    if ns.Router:Build() then
        local seen = {}
        for _, n in ipairs(ns.Router.nodes) do
            if (n.kind == "taxi" or n.kind == "station" or n.kind == "place") and n.place and not seen[n.place]
                and (not n.faction or n.faction == ns.faction) then
                seen[n.place] = true
                add(n.place, function() return Maps:Point(n.map, n.x, n.y, n.place) end)
            end
        end
    end
    for name, sv in pairs(ns.db.saved) do
        add(name, function() return Maps:Point(sv.map, sv.x, sv.y, name) end)
    end
    if ns.RoutesBridge then
        for _, r in ipairs(ns.RoutesBridge:ListRoutes()) do
            local label = string.format(L["Routes: %s"], r.name)
            add(label, function() return Maps:Point(r.map, r.x, r.y, label) end)
        end
    end
    return list
end

local function match(list, text)
    local q = text:lower()
    local prefix, inside
    for i = 1, #list do
        local e = list[i]
        if e.lower == q then return e end
        local pos = e.lower:find(q, 1, true)
        if pos == 1 then
            if not prefix or #e.lower < #prefix.lower then prefix = e end
        elseif pos then
            if not inside or #e.lower < #inside.lower then inside = e end
        end
    end
    return prefix or inside
end

-- Point for a place with exactly this name (case-insensitive), or nil.
function Places:FindExact(name)
    if not ns.Maps:Ensure() then return nil end
    local q = name:lower()
    for _, e in ipairs(self:Catalog()) do
        if e.lower == q then return e.make() end
    end
end

-- Returns point or nil, errorText.
function Places:Resolve(text)
    local Maps = ns.Maps
    if not Maps:Ensure() then return nil, L["Map data is not ready yet, try again in a moment."] end
    text = trim(text or "")
    local key = text:lower()

    if HERE[key] or text == L["My position"] then
        local p = Maps:PlayerPoint(L["My position"])
        if not p then return nil, L["Cannot read your position here."] end
        return p
    end

    if PIN[key] or text == L["Map pin"] then
        local wp = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
        if not wp then return nil, L["No map pin set."] end
        local pos = wp.position
        return Maps:Point(wp.uiMapID, pos.x, pos.y, L["Map pin"])
    end

    if HOME[key] or text == L["Hearthstone"] then
        local h = ns.Hearth:Get()
        if h.node then return h.node end
        if h.reason == "cooldown" then
            local p = ns.Places:FindExact(h.name)
            local saved = ns.chardb.bind
            if saved and saved.name == h.name then p = Maps:Point(saved.map, saved.x, saved.y, h.name) end
            if p then return p end
        end
        return nil, L["I do not know where your Hearthstone is bound: set it at an innkeeper again, or record the spot with /gps home."]
    end

    -- Trailing "x y" coordinates (percentages).
    local name, xs, ys = text:match("^(.-)%s*(%d+%.?%d*)[%s,;]+(%d+%.?%d*)$")
    local x, y
    if xs then
        x, y = tonumber(xs) / 100, tonumber(ys) / 100
        name = trim(name)
        if name == "" then
            local here = Maps:PlayerPoint()
            if not here then return nil, L["Cannot read your position here."] end
            return Maps:Point(here.map, x, y, string.format("%s %.1f, %.1f", Maps:Name(here.map), x * 100, y * 100))
        end
    else
        name = text
    end

    local e = match(self:Catalog(), name)
    if not e then return nil, string.format(L["Unknown place: %s"], name) end
    local p = e.make(x, y)
    if not p then return nil, string.format(L["Unknown place: %s"], name) end
    if x then p.name = string.format("%s %.1f, %.1f", e.name, x * 100, y * 100) end
    return p
end

-- Up to max place names containing text, for the suggestion list.
function Places:Suggest(text, max)
    local out = {}
    text = trim(text or ""):lower()
    if text == "" or not ns.Maps:Ensure() then return out end
    local list = self:Catalog()
    table.sort(list, function(a, b) return a.lower < b.lower end)
    for pass = 1, 2 do
        for i = 1, #list do
            local pos = list[i].lower:find(text, 1, true)
            if pos and ((pass == 1 and pos == 1) or (pass == 2 and pos > 1)) then
                out[#out + 1] = list[i].name
                if #out >= max then return out end
            end
        end
    end
    return out
end
