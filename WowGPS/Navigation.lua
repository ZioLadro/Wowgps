-- WowGPS: turn-by-turn navigation along a computed path.
-- One waypoint at a time: TomTom's arrow when TomTom is installed, the
-- built-in map pin otherwise. The waypoint advances when you get close.
local _, ns = ...
local L = ns.L

local Nav = {}
ns.Nav = Nav

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

function Nav:Announce()
    local st = self.path.steps[self.index]
    ns:Print(string.format(L["Step %d/%d: %s"], self.index, #self.path.steps, st.text))
    setWaypoint(st.to, st.text)
    if ns.UI then ns.UI:Refresh() end
end

function Nav:Start(path)
    if not path or #path.steps == 0 then
        ns:Print(L["Nothing to navigate: compute a route first."])
        return
    end
    self:Stop(true)
    self.path, self.index = path, 1
    self:Announce()
    self.ticker = C_Timer.NewTicker(0.5, function() Nav:Tick() end)
end

function Nav:Stop(silent)
    if self.ticker then self.ticker:Cancel() end
    self.ticker = nil
    local was = self.path
    self.path, self.index = nil, nil
    clearWaypoint()
    if was and not silent then ns:Print(L["Navigation stopped."]) end
    if ns.UI then ns.UI:Refresh() end
end

function Nav:Next()
    if not self.path then return end
    if self.index >= #self.path.steps then
        ns:Print(L["You have arrived."])
        self:Stop(true)
        return
    end
    self.index = self.index + 1
    self:Announce()
end

function Nav:Tick()
    if not self.path then return end
    local here = ns.Maps:PlayerPoint()
    if not here then return end
    local st = self.path.steps[self.index]
    local d = ns.Maps:Distance(here, st.to)
    -- Rides drop you near, not on, the station marker: be generous there.
    local radius = st.kind == "walk" and ns.db.arriveDist or 60
    if d and d <= radius then self:Next() end
end
