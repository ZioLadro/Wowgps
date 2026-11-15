-- WowGPS: core, saved variables, events.
local ADDON, ns = ...
_G.WowGPS = ns

ns.name = ADDON
ns.version = "0.2.0"

local globalDefaults = {
    mountSpeed = "auto", -- "auto" (measured), 0 (no mount), 60 or 100 (% bonus)
    avoidContested = false, -- steer ground travel away from contested / enemy zones
    userRoads = {},      -- [uiMapID] = { road, ... } recorded with /gps record
    saved = {},          -- [name] = { map, x, y } places saved with /gps save
    pvp = {},            -- [faction][uiMapID] = zone status learned in game
    knownOnly = true,    -- use only flight points this character has discovered
    arriveDist = 25,     -- yards: a waypoint counts as reached inside this radius
    lang = nil,          -- "it" / "en" override, nil = client locale
    taxiNodes = {},      -- cache of flight points seen on the taxi map
    exported = {},       -- routes we created inside the Routes addon
}

local charDefaults = {
    knownTaxi = {},      -- [nodeID] = true
    taxiSeen = {},       -- [instanceID] = true once a taxi map was opened there
}

local function applyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                applyDefaults(dst[k], v)
            else
                dst[k] = v
            end
        end
    end
    return dst
end

function ns:Print(...)
    print("|cff33ccffWowGPS|r:", ...)
end

function ns.FormatTime(sec)
    sec = math.floor(sec + 0.5)
    if sec < 60 then
        return sec .. " s"
    elseif sec < 3600 then
        return math.floor(sec / 60 + 0.5) .. " min"
    end
    local h = math.floor(sec / 3600)
    return h .. " h " .. math.floor((sec - h * 3600) / 60 + 0.5) .. " min"
end

function ns.FormatDist(yards)
    if yards >= 1000 then
        return string.format("%.1fk yd", yards / 1000)
    end
    return math.floor(yards + 0.5) .. " yd"
end

function ns:InitDB()
    WowGPSDB = applyDefaults(WowGPSDB or {}, globalDefaults)
    WowGPSCharDB = applyDefaults(WowGPSCharDB or {}, charDefaults)
    self.db = WowGPSDB
    -- 0.1.0 stored 60 as the untouched default.
    if not self.db.speedMigrated then
        self.db.speedMigrated = true
        if self.db.mountSpeed == 60 then self.db.mountSpeed = "auto" end
    end
    self.chardb = WowGPSCharDB
end

local frame = CreateFrame("Frame")
-- RegisterEvent throws on an event the client does not know.
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "TAXIMAP_OPENED", "PLAYER_ENTERING_WORLD",
                         "PLAYER_MOUNT_DISPLAY_CHANGED", "HEARTHSTONE_BOUND", "ZONE_CHANGED_NEW_AREA" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            ns:InitDB()
            if ns.ApplyLocale then ns:ApplyLocale() end
        end
    elseif event == "PLAYER_LOGIN" then
        ns.faction = UnitFactionGroup("player")
    elseif event == "TAXIMAP_OPENED" then
        if ns.Taxi then ns.Taxi:OnTaxiMapOpened() end
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        -- The speed changes a moment after the mount appears.
        C_Timer.After(1, function() ns:SampleSpeed() end)
    elseif event == "HEARTHSTONE_BOUND" then
        ns.Hearth:OnBound()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        ns:SampleSpeed()
        ns.PvP:OnZoneChanged()
    end
end)
