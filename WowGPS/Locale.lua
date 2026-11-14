-- WowGPS: strings. Keys are the English text; itIT overrides below.
local _, ns = ...

local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

local itIT = {
    ["Start"] = "Partenza",
    ["Destination"] = "Destinazione",
    ["My position"] = "La mia posizione",
    ["Map pin"] = "Pin sulla mappa",
    ["Here"] = "Qui",
    ["Pin"] = "Pin",
    ["Swap"] = "Inverti",
    ["Get directions"] = "Calcola percorso",
    ["Navigate"] = "Avvia navigazione",
    ["Stop"] = "Ferma",
    ["Send to Routes"] = "Invia a Routes",
    ["Mount: %s"] = "Cavalcatura: %s",
    ["none"] = "nessuna",
    ["Known flight points only"] = "Solo punti di volo conosciuti",
    ["On foot"] = "A piedi",
    ["Mount"] = "Cavalcatura",
    ["Boats / zeppelins / tram"] = "Navi / zeppelin / tram",
    ["Flight paths"] = "Voli",
    ["no route"] = "nessun percorso",
    ["fastest"] = "più veloce",
    ["Leave empty to start from where you are. Type a zone, a flight point, \"zone 42 65\" or \"pin\"."] =
        "Lascia vuoto per partire da dove sei. Scrivi una zona, un punto di volo, \"zona 42 65\" o \"pin\".",
    ["Unknown place: %s"] = "Luogo sconosciuto: %s",
    ["No map pin set."] = "Nessun pin impostato sulla mappa.",
    ["Cannot read your position here."] = "Impossibile leggere la tua posizione qui.",
    ["Map data is not ready yet, try again in a moment."] = "I dati della mappa non sono ancora pronti, riprova tra un attimo.",
    ["Enter a destination."] = "Inserisci una destinazione.",
    ["Walk to %s"] = "Vai a piedi fino a %s",
    ["Ride to %s"] = "Cavalca fino a %s",
    ["Fly from %s to %s"] = "Prendi il volo da %s a %s",
    ["Take the boat from %s to %s"] = "Prendi la nave da %s a %s",
    ["Take the zeppelin from %s to %s"] = "Prendi lo zeppelin da %s a %s",
    ["Take the Deeprun Tram from %s to %s"] = "Prendi il tram degli abissi da %s a %s",
    ["Take the portal from %s to %s"] = "Prendi il portale da %s a %s",
    ["the %s / %s border"] = "il confine %s / %s",
    ["the flight master at %s"] = "il maestro di volo di %s",
    ["the dock at %s"] = "il molo di %s",
    ["the zeppelin tower at %s"] = "la torre degli zeppelin di %s",
    ["the tram station in %s"] = "la stazione del tram di %s",
    ["the portal at %s"] = "il portale di %s",
    ["your destination"] = "la tua destinazione",
    ["Straight line, no road data for this area (rough estimate)."] =
        "Linea retta, nessun dato stradale per quest'area (stima approssimativa).",
    ["Needs a boat/zeppelin/tram: there is no land route."] =
        "Serve una nave/zeppelin/tram: non esiste un percorso via terra.",
    ["Flight points not scanned yet on this continent: open a flight master once for exact results."] =
        "Punti di volo non ancora rilevati su questo continente: apri un maestro di volo una volta per risultati esatti.",
    ["Total: %s, %s"] = "Totale: %s, %s",
    ["Step %d/%d: %s"] = "Tappa %d/%d: %s",
    ["You have arrived."] = "Sei arrivato a destinazione.",
    ["Navigation stopped."] = "Navigazione fermata.",
    ["Nothing to navigate: compute a route first."] = "Niente da navigare: calcola prima un percorso.",
    ["Routes addon not found."] = "Addon Routes non trovato.",
    ["Sent to Routes: %d route(s). They are drawn on the map now; /reload to see them in the /routes list."] =
        "Inviato a Routes: %d percorso/i. Sono già disegnati sulla mappa; fai /reload per vederli nella lista di /routes.",
    ["Nothing to send: the route has no ground segments."] = "Niente da inviare: il percorso non ha tratti via terra.",
    ["Removed %d WowGPS route(s) from Routes."] = "Rimossi %d percorsi WowGPS da Routes.",
    ["Mount speed set to %s."] = "Velocità cavalcatura impostata a %s.",
    ["Position: %s %.1f %.1f (areaID data line: map = %d, x = %.1f, y = %.1f)"] =
        "Posizione: %s %.1f %.1f (riga dati: map = %d, x = %.1f, y = %.1f)",
    ["Commands:"] = "Comandi:",
    ["  /gps  - open the window"] = "  /gps  - apre la finestra",
    ["  /gps <place>  - directions from your position"] = "  /gps <luogo>  - percorso dalla tua posizione",
    ["  /gps from <A> to <B>  - directions between two places"] = "  /gps da <A> a <B>  - percorso tra due luoghi",
    ["  /gps go [1-4]  - start navigation (option number)"] = "  /gps go [1-4]  - avvia la navigazione (numero opzione)",
    ["  /gps stop | next  - stop / skip a step"] = "  /gps stop | next  - ferma / salta una tappa",
    ["  /gps routes | routes clear  - export to Routes / remove"] = "  /gps routes | routes clear  - esporta in Routes / rimuovi",
    ["  /gps mount 0|60|100  - mount speed"] = "  /gps mount 0|60|100  - velocità cavalcatura",
    ["  /gps mark  - print your position (to fix data)"] = "  /gps mark  - stampa la tua posizione (per correggere i dati)",
    ["Routes: %s"] = "Routes: %s",
}

function ns:ApplyLocale()
    local lang = self.db and self.db.lang
    local useIt = lang == "it" or (lang == nil and GetLocale and GetLocale() == "itIT")
    for k in pairs(itIT) do
        rawset(L, k, useIt and itIT[k] or nil)
    end
end
