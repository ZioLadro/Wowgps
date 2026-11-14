-- WowGPS: core, saved variables, events.
local ADDON, ns = ...
_G.WowGPS = ns

ns.name = ADDON
ns.version = "0.1.0"

-- Ground speeds in yards per second.
ns.WALK_SPEED = 7.0
ns.MOUNT_SPEEDS = { [0] = 7.0, [60] = 11.2, [100] = 14.0 }

local globalDefaults = {
    mountSpeed = 60,     -- 0 (no mount), 60 or 100 (% bonus)
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

function ns:GroundSpeed()
    return ns.MOUNT_SPEEDS[self.db.mountSpeed] or ns.WALK_SPEED
end

function ns:InitDB()
    WowGPSDB = applyDefaults(WowGPSDB or {}, globalDefaults)
    WowGPSCharDB = applyDefaults(WowGPSCharDB or {}, charDefaults)
    self.db = WowGPSDB
    self.chardb = WowGPSCharDB
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("TAXIMAP_OPENED")
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
    end
end)
