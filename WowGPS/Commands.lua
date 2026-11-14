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
    print(L["  /gps mount 0|60|100  - mount speed"])
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
        local v = tonumber(rest)
        if v and ns.MOUNT_SPEEDS[v] then
            ns.db.mountSpeed = v
            ns:Print(string.format(L["Mount speed set to %s."], v == 0 and L["none"] or ("+" .. v .. "%")))
            ns.UI:Refresh()
        else
            help()
        end
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
