-- WowGPS: turn-by-turn navigation along a computed path.
-- One waypoint at a time: TomTom's arrow when TomTom is installed, the
-- built-in map pin otherwise. The waypoint advances when you get close; on a
-- road it moves from bend to bend.
local _, ns = ...
local L = ns.L

local Nav = {}
ns.Nav = Nav

local ROAD_RADIUS = 35    -- yards: intermediate road points
local RIDE_RADIUS = 60    -- yards: boats, flights and the like drop you nearby

local function clearWaypoint()
    if Nav.tomtomUID and TomTom and TomTom.RemoveWaypoint then
        pcall(TomTom.RemoveWaypoint, TomTom, Nav.tomtomUID)
    end
    Nav.tomtomUID = nil
    if Nav.nativePin and C_Map.ClearUserWaypoint then
        C_Map.ClearUserWaypoint()
    end
    Nav.nativePin = nil
end

local function setWaypoint(node, title)
    clearWaypoint()
    if TomTom and TomTom.AddWaypoint then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, node.map, node.x, node.y, {
            title = title, persistent = false, minimap = true, world = true,
            crazy = true, from = "WowGPS",
        })
        if ok and uid then
            Nav.tomtomUID = uid
            return
        end
    end
    if C_Map.SetUserWaypoint and UiMapPoint
        and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(node.map)) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(node.map, node.x, node.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        Nav.nativePin = true
    end
end

-- Points the waypoint at targets[pos]; announces the step when it changes.
function Nav:Goto(pos)
    local t = self.targets[pos]
    local st = self.path.steps[t.step]
    self.pos = pos
    if self.index ~= t.step then
        self.index = t.step
        ns:Print(string.format(L["Step %d/%d: %s"], t.step, #self.path.steps, st.text))
    end
    setWaypoint(t.node, st.text)
    if ns.UI then ns.UI:Refresh() end
end

function Nav:Start(path)
    if not path or #path.steps == 0 then
        ns:Print(L["Nothing to navigate: compute a route first."])
        return
    end
    self:Stop(true)
    self.path, self.index, self.targets = path, nil, {}
    for si, st in ipairs(path.steps) do
        local pts = st.points or { st.from, st.to }
        for i = 2, #pts do
            local radius = RIDE_RADIUS
            if st.kind == "walk" then radius = (i == #pts) and ns.db.arriveDist or ROAD_RADIUS end
            self.targets[#self.targets + 1] = { node = pts[i], step = si, radius = radius }
        end
    end
    self:Goto(1)
    self.ticker = C_Timer.NewTicker(0.5, function() Nav:Tick() end)
end

function Nav:Stop(silent)
    if self.ticker then self.ticker:Cancel() end
    self.ticker = nil
    local was = self.path
    self.path, self.index, self.targets, self.pos = nil, nil, nil, nil
    clearWaypoint()
    if was and not silent then ns:Print(L["Navigation stopped."]) end
    if ns.UI then ns.UI:Refresh() end
end

function Nav:Arrive(pos)
    if pos >= #self.targets then
        ns:Print(L["You have arrived."])
        self:Stop(true)
    else
        self:Goto(pos + 1)
    end
end

-- Skips the rest of the current step.
function Nav:Next()
    if not self.path then return end
    local pos = self.pos
    while self.targets[pos + 1] and self.targets[pos + 1].step == self.index do pos = pos + 1 end
    self:Arrive(pos)
end

function Nav:Tick()
    if not self.path then return end
    local here = ns.Maps:PlayerPoint()
    if not here then return end
    -- Reaching a later point of the same step counts too (cutting a bend).
    local last = self.pos
    while self.targets[last + 1] and self.targets[last + 1].step == self.index do last = last + 1 end
    for pos = last, self.pos, -1 do
        local t = self.targets[pos]
        local d = ns.Maps:Distance(here, t.node)
        if d and d <= t.radius then
            self:Arrive(pos)
            return
        end
    end
end
