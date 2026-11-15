-- WowGPS: slash commands (/gps, /wowgps).
local _, ns = ...
local L = ns.L

local function help()
    ns:Print(L["Commands:"])
    print(L["  /gps  - open the window"])
    print(L["  /gps <place>  - directions from your position"])
    print(L["  /gps from <A> to <B>  - directions between two places"])
    print(L["  /gps go [1-4]  - start navigation (option number)"])
    print(L["  /gps stop | next  - stop / skip a step"])
    print(L["  /gps routes | routes clear  - export to Routes / remove"])
    print(L["  /gps mount auto|0|60|100  - mount speed"])
    print(L["  /gps avoid  - toggle avoiding contested zones"])
    print(L["  /gps save <name> | forget <name>  - save / remove your position as a place"])
    print(L["  /gps home  - remember this spot as your Hearthstone location"])
    print(L["  /gps record | record clear  - record the road you travel / forget this zone's"])
    print(L["  /gps mark  - print your position (to fix data)"])
end

local function mark()
    local p = ns.Maps:Ensure() and ns.Maps:PlayerPoint()
    if not p then
        ns:Print(L["Cannot read your position here."])
        return
    end
    local zone = ns.Maps.zones[p.map]
    ns:Print(string.format(L["Position: %s %.1f %.1f (areaID data line: map = %d, x = %.1f, y = %.1f)"],
        ns.Maps:Name(p.map), p.x * 100, p.y * 100, zone and zone.area or 0, p.x * 100, p.y * 100))
end

SLASH_WOWGPS1 = "/gps"
SLASH_WOWGPS2 = "/wowgps"
SlashCmdList["WOWGPS"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if msg == "" then
        ns.UI:Toggle()
    elseif cmd == "help" or cmd == "?" then
        help()
    elseif cmd == "stop" then
        ns.Nav:Stop()
    elseif cmd == "next" then
        ns.Nav:Next()
    elseif cmd == "go" then
        local n = tonumber(rest)
        if n then ns.UI:Select(n) end
        local opt = ns.UI:Selected()
        ns.Nav:Start(opt and opt.path)
    elseif cmd == "routes" then
        if rest:lower() == "clear" then
            ns.RoutesBridge:Clear()
        else
            ns.UI:ExportToRoutes()
        end
    elseif cmd == "mount" then
        local v = rest:lower() == "auto" and "auto" or tonumber(rest)
        if v == "auto" or v == 0 or v == 60 or v == 100 then
            ns.db.mountSpeed = v
            ns:Print(string.format(L["Mount speed set to %s."],
                v == 0 and L["none"] or ("+" .. ns:SpeedPercent(ns:MountSpeed()) .. "%")))
            ns.UI:Refresh()
        else
            help()
        end
    elseif cmd == "avoid" then
        ns.db.avoidContested = not ns.db.avoidContested
        ns:Print(ns.db.avoidContested and L["Avoiding contested zones: on."] or L["Avoiding contested zones: off."])
    elseif cmd == "save" and rest ~= "" then
        local p = ns.Maps:Ensure() and ns.Maps:PlayerPoint()
        if p then
            ns.db.saved[rest] = { map = p.map, x = p.x, y = p.y }
            ns:Print(string.format(L["Saved place: %s"], rest))
        else
            ns:Print(L["Cannot read your position here."])
        end
    elseif cmd == "forget" and rest ~= "" then
        ns.db.saved[rest] = nil
        ns:Print(string.format(L["Removed place: %s"], rest))
    elseif cmd == "home" and rest == "" then
        ns.Hearth:OnBound()
        local b = ns.chardb.bind
        ns:Print(b and string.format(L["Hearthstone location recorded: %s"], b.name) or L["Cannot read your position here."])
    elseif cmd == "record" then
        if rest:lower() == "clear" then ns.Recorder:ClearZone() else ns.Recorder:Toggle() end
    elseif cmd == "lang" and (rest == "it" or rest == "en") then
        ns.db.lang = rest
        ns:ApplyLocale()
        ReloadUI()
    elseif cmd == "mark" then
        mark()
    else
        local a, b = msg:match("^[Ff]rom%s+(.-)%s+to%s+(.+)$")
        if not a then a, b = msg:match("^[Dd]a%s+(.-)%s+a%s+(.+)$") end
        if a then
            ns.UI:Compute(a, b)
        else
            ns.UI:Compute("", msg)
        end
    end
end
