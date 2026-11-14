-- WowGPS: flight points. Read live from the client (no hardcoded list), so
-- new Forever flight masters are picked up automatically. Which ones the
-- character knows is learned whenever a flight master window is opened.
local _, ns = ...

local Taxi = {}
ns.Taxi = Taxi

local FF = (Enum and Enum.FlightPathFaction) or {}
local F_HORDE, F_ALLIANCE = FF.Horde or 1, FF.Alliance or 2
local FS = (Enum and Enum.FlightPathState) or {}
local S_UNREACHABLE = FS.Unreachable or 2

local function factionName(f)
    if f == F_HORDE then return "Horde" end
    if f == F_ALLIANCE then return "Alliance" end
    return nil
end

-- Returns a list of { id, name, cont, x, y, faction } (x, y 0-1 on the continent map).
function Taxi:GetNodes()
    local out, seen = {}, {}
    if C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
        for cont in pairs(ns.Maps.continents) do
            local nodes = C_TaxiMap.GetTaxiNodesForMap(cont)
            if nodes then
                for i = 1, #nodes do
                    local n = nodes[i]
                    if n.nodeID and n.position and not seen[n.nodeID] then
                        seen[n.nodeID] = true
                        out[#out + 1] = {
                            id = n.nodeID, name = n.name, cont = cont,
                            x = n.position.x, y = n.position.y,
                            faction = factionName(n.faction),
                        }
                    end
                end
            end
        end
    end
    -- Anything seen on a taxi map that the query above did not return.
    for id, c in pairs(ns.db.taxiNodes) do
        if not seen[id] and ns.Maps.continents[c.cont] then
            -- The cache cannot tell neutral from faction nodes: restrict to the
            -- faction that saw it.
            out[#out + 1] = { id = id, name = c.name, cont = c.cont, x = c.x, y = c.y, faction = c.seenBy }
        end
    end
    return out
end

function Taxi:IsKnown(id)
    return ns.chardb.knownTaxi[id] == true
end

function Taxi:OnTaxiMapOpened()
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and GetTaxiMapID) then return end
    local mapID = GetTaxiMapID()
    if not mapID then return end
    local nodes = C_TaxiMap.GetAllTaxiNodes(mapID)
    if not nodes then return end
    local myFaction = UnitFactionGroup("player")
    local inst
    for i = 1, #nodes do
        local n = nodes[i]
        if n.nodeID and n.position then
            if n.state ~= S_UNREACHABLE then
                ns.chardb.knownTaxi[n.nodeID] = true
            end
            -- Nodes shown on our own taxi map are usable by our faction.
            ns.db.taxiNodes[n.nodeID] = {
                name = n.name, cont = mapID, x = n.position.x, y = n.position.y,
                seenBy = myFaction,
            }
            if not inst then
                inst = ns.Maps:ToWorld(mapID, n.position.x, n.position.y)
            end
        end
    end
    if inst then ns.chardb.taxiSeen[inst] = true end
    if ns.Router then ns.Router:Invalidate() end
end
