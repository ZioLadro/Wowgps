-- WowGPS: static travel data for the classic-era world.
--
-- Zones are identified by AreaTable ID (stable on every client); the uiMapID
-- is resolved at runtime by name, with the Classic uiMapID as a fallback.
-- All coordinates are map percentages (0-100) on the map of the zone named in
-- "map" (an areaID).
--
-- IMPORTANT: border and station coordinates were written from memory of the
-- classic world and are APPROXIMATE. Stand on the right spot in game and type
-- "/gps mark" to get the exact numbers, then fix the line here.
local _, ns = ...

local D = {}
ns.Data = D

-- { areaID, classic uiMapID }
D.zones = {
    -- Eastern Kingdoms
    { 1, 1426 },    -- Dun Morogh
    { 3, 1418 },    -- Badlands
    { 4, 1419 },    -- Blasted Lands
    { 8, 1435 },    -- Swamp of Sorrows
    { 10, 1431 },   -- Duskwood
    { 11, 1437 },   -- Wetlands
    { 12, 1429 },   -- Elwynn Forest
    { 28, 1422 },   -- Western Plaguelands
    { 33, 1434 },   -- Stranglethorn Vale
    { 36, 1416 },   -- Alterac Mountains
    { 38, 1432 },   -- Loch Modan
    { 40, 1436 },   -- Westfall
    { 41, 1430 },   -- Deadwind Pass
    { 44, 1433 },   -- Redridge Mountains
    { 45, 1417 },   -- Arathi Highlands
    { 46, 1428 },   -- Burning Steppes
    { 47, 1425 },   -- The Hinterlands
    { 51, 1427 },   -- Searing Gorge
    { 85, 1420 },   -- Tirisfal Glades
    { 130, 1421 },  -- Silverpine Forest
    { 139, 1423 },  -- Eastern Plaguelands
    { 267, 1424 },  -- Hillsbrad Foothills
    { 1497, 1458 }, -- Undercity
    { 1519, 1453 }, -- Stormwind City
    { 1537, 1455 }, -- Ironforge
    -- Kalimdor
    { 14, 1411 },   -- Durotar
    { 15, 1445 },   -- Dustwallow Marsh
    { 16, 1447 },   -- Azshara
    { 17, 1413 },   -- The Barrens
    { 141, 1438 },  -- Teldrassil
    { 148, 1439 },  -- Darkshore
    { 215, 1412 },  -- Mulgore
    { 331, 1440 },  -- Ashenvale
    { 357, 1444 },  -- Feralas
    { 361, 1448 },  -- Felwood
    { 400, 1441 },  -- Thousand Needles
    { 405, 1443 },  -- Desolace
    { 406, 1442 },  -- Stonetalon Mountains
    { 440, 1446 },  -- Tanaris
    { 490, 1449 },  -- Un'Goro Crater
    { 493, 1450 },  -- Moonglade
    { 618, 1452 },  -- Winterspring
    { 1377, 1451 }, -- Silithus
    { 1637, 1454 }, -- Orgrimmar
    { 1638, 1456 }, -- Thunder Bluff
    { 1657, 1457 }, -- Darnassus
}

-- Ground passages between two zones: { a, b, map, x, y }
-- a, b = areaIDs of the two zones; map = which of them x/y refer to.
D.borders = {
    -- Eastern Kingdoms
    { 12, 1519, 12, 32.0, 49.5 },   -- Elwynn / Stormwind gates
    { 12, 40, 12, 21.0, 79.5 },     -- Elwynn / Westfall bridge
    { 12, 44, 12, 92.5, 72.0 },     -- Elwynn / Redridge (Three Corners)
    { 40, 10, 10, 8.0, 33.5 },      -- Westfall / Duskwood bridge
    { 44, 10, 10, 94.0, 10.5 },     -- Redridge / Duskwood
    { 10, 41, 10, 91.0, 41.0 },     -- Duskwood / Deadwind Pass
    { 41, 8, 41, 60.0, 41.0 },      -- Deadwind Pass / Swamp of Sorrows
    { 8, 4, 4, 51.0, 7.5 },         -- Swamp of Sorrows / Blasted Lands
    { 10, 33, 10, 44.0, 88.0 },     -- Duskwood / Stranglethorn
    { 44, 46, 46, 78.0, 78.0 },     -- Redridge / Burning Steppes
    { 46, 51, 46, 30.0, 36.0 },     -- Burning Steppes / Searing Gorge (Blackrock Mountain)
    { 46, 3, 3, 4.5, 61.0 },        -- Burning Steppes / Badlands
    { 51, 3, 3, 5.5, 47.0 },        -- Searing Gorge / Badlands (Kargath pass)
    { 3, 38, 38, 46.5, 78.5 },      -- Badlands / Loch Modan
    { 38, 1, 38, 19.5, 62.5 },      -- Loch Modan / Dun Morogh (South Gate Pass)
    { 38, 11, 38, 25.5, 10.5 },     -- Loch Modan / Wetlands (Dun Algaz)
    { 1, 1537, 1, 53.5, 35.0 },     -- Dun Morogh / Ironforge gates
    { 11, 45, 11, 51.0, 9.0 },      -- Wetlands / Arathi (Thandol Span)
    { 45, 267, 45, 20.0, 29.5 },    -- Arathi / Hillsbrad
    { 267, 47, 267, 85.5, 31.0 },   -- Hillsbrad / Hinterlands
    { 267, 36, 267, 54.0, 10.0 },   -- Hillsbrad / Alterac
    { 267, 130, 267, 13.0, 46.5 },  -- Hillsbrad / Silverpine
    { 36, 28, 28, 44.0, 87.0 },     -- Alterac / Western Plaguelands
    { 130, 85, 130, 67.0, 5.0 },    -- Silverpine / Tirisfal
    { 85, 1497, 85, 61.9, 65.0 },   -- Tirisfal / Undercity (Ruins of Lordaeron)
    { 85, 28, 85, 84.0, 69.5 },     -- Tirisfal / Western Plaguelands (The Bulwark)
    { 28, 139, 28, 69.5, 50.5 },    -- Western / Eastern Plaguelands bridge
    -- Kalimdor
    { 14, 1637, 14, 45.5, 12.0 },   -- Durotar / Orgrimmar gates
    { 14, 17, 14, 34.5, 42.5 },     -- Durotar / Barrens bridge
    { 17, 215, 215, 69.0, 60.5 },   -- Barrens / Mulgore
    { 215, 1638, 215, 39.0, 31.5 }, -- Mulgore / Thunder Bluff lifts
    { 17, 331, 331, 68.5, 86.5 },   -- Barrens / Ashenvale
    { 17, 406, 17, 35.0, 27.5 },    -- Barrens / Stonetalon
    { 17, 15, 15, 29.5, 47.5 },     -- Barrens / Dustwallow Marsh
    { 17, 400, 400, 31.5, 22.0 },   -- Barrens / Thousand Needles (Great Lift)
    { 400, 357, 357, 89.0, 45.0 },  -- Thousand Needles / Feralas
    { 400, 440, 440, 51.5, 21.5 },  -- Thousand Needles / Tanaris
    { 440, 490, 440, 27.0, 54.0 },  -- Tanaris / Un'Goro
    { 490, 1377, 490, 28.5, 22.0 }, -- Un'Goro / Silithus
    { 331, 148, 148, 43.5, 94.0 },  -- Ashenvale / Darkshore
    { 331, 361, 361, 54.5, 90.0 },  -- Ashenvale / Felwood
    { 331, 16, 331, 94.5, 47.5 },   -- Ashenvale / Azshara
    { 331, 406, 331, 42.0, 71.0 },  -- Ashenvale / Stonetalon (Talondeep Path)
    { 406, 405, 405, 53.0, 4.0 },   -- Stonetalon / Desolace
    { 405, 357, 357, 44.5, 8.5 },   -- Desolace / Feralas
    { 361, 618, 361, 65.0, 8.5 },   -- Felwood / Winterspring (Timbermaw Hold)
    { 361, 493, 361, 65.0, 8.5 },   -- Felwood / Moonglade (Timbermaw Hold)
    { 141, 1657, 141, 36.0, 54.0 }, -- Teldrassil / Darnassus
}

-- Scheduled transports and portals.
-- kind: "boat" | "zeppelin" | "tram" | "portal"
-- time: average seconds including the wait (estimates).
-- faction: "Alliance" | "Horde" | nil (anyone)
-- a / b: { map = areaID, x, y, name = English fallback, area = areaID for the localized name }
D.transports = {
    { kind = "boat", time = 210,
      a = { map = 17, x = 63.7, y = 38.6, name = "Ratchet", area = 392 },
      b = { map = 33, x = 25.9, y = 73.1, name = "Booty Bay", area = 35 } },
    { kind = "boat", time = 210, faction = "Alliance",
      a = { map = 11, x = 5.0, y = 63.5, name = "Menethil Harbor", area = 150 },
      b = { map = 15, x = 71.6, y = 56.4, name = "Theramore Isle", area = 513 } },
    { kind = "boat", time = 210, faction = "Alliance",
      a = { map = 11, x = 4.6, y = 57.1, name = "Menethil Harbor", area = 150 },
      b = { map = 148, x = 32.4, y = 43.8, name = "Auberdine", area = 442 } },
    { kind = "boat", time = 180, faction = "Alliance",
      a = { map = 148, x = 33.2, y = 40.1, name = "Auberdine", area = 442 },
      b = { map = 141, x = 54.9, y = 96.8, name = "Rut'theran Village", area = 702 } },
    { kind = "zeppelin", time = 240, faction = "Horde",
      a = { map = 14, x = 50.9, y = 13.8, name = "Orgrimmar", area = 1637 },
      b = { map = 85, x = 60.7, y = 58.8, name = "Undercity", area = 1497 } },
    { kind = "zeppelin", time = 240, faction = "Horde",
      a = { map = 14, x = 50.6, y = 12.6, name = "Orgrimmar", area = 1637 },
      b = { map = 33, x = 31.6, y = 29.1, name = "Grom'gol Base Camp", area = 117 } },
    { kind = "zeppelin", time = 240, faction = "Horde",
      a = { map = 85, x = 61.9, y = 59.1, name = "Undercity", area = 1497 },
      b = { map = 33, x = 31.4, y = 30.2, name = "Grom'gol Base Camp", area = 117 } },
    { kind = "tram", time = 120, faction = "Alliance",
      a = { map = 1519, x = 63.9, y = 8.3, name = "Stormwind City", area = 1519 },
      b = { map = 1537, x = 76.5, y = 51.2, name = "Ironforge", area = 1537 } },
    { kind = "portal", time = 10, faction = "Alliance",
      a = { map = 1657, x = 30.0, y = 41.5, name = "Darnassus", area = 1657 },
      b = { map = 141, x = 56.0, y = 90.0, name = "Rut'theran Village", area = 702 } },
}
