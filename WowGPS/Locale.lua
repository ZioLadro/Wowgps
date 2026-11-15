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
    ["Walk to %s"] = "Raggiungi a piedi %s",
    ["Ride to %s"] = "Raggiungi in sella %s",
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
    ["  /gps mark  - print your position (to fix data)"] = "  /gps mark  - stampa la tua posizione (per correggere i dati)",
    ["Routes: %s"] = "Routes: %s",
    ["Hearthstone"] = "Pietra del ritorno",
    ["auto"] = "auto",
    ["not useful"] = "non conviene",
    ["Avoid contested zones"] = "Evita le zone contese",
    ["Follow the road to %s"] = "Segui la strada fino a: %s",
    ["Use your Hearthstone to %s"] = "Usa la pietra del ritorno per %s",
    ["No Hearthstone in your bags."] = "Nessuna pietra del ritorno nelle borse.",
    ["Hearthstone (%s) ready in %s."] = "Pietra del ritorno (%s) pronta tra %s.",
    ["Hearthstone (%s) does not shorten this trip."] = "La pietra del ritorno (%s) non accorcia questo viaggio.",
    ["I do not know where your Hearthstone is bound: set it at an innkeeper again, or record the spot with /gps home."] =
        "Non so dove è fissata la tua pietra del ritorno: impostala di nuovo da un locandiere, oppure registra il punto con /gps home.",
    ["Crosses contested zones: %s"] = "Attraversa zone contese: %s",
    ["Crosses enemy territory: %s"] = "Attraversa territorio nemico: %s",
    ["Recording the road you travel. Type /gps record again to stop."] =
        "Registro la strada che percorri. Scrivi di nuovo /gps record per fermare.",
    ["Recording stopped: %d road segment(s) saved."] = "Registrazione fermata: %d tratto/i di strada salvati.",
    ["Recorded roads removed for %s."] = "Strade registrate rimosse per %s.",
    ["Avoiding contested zones: on."] = "Evita zone contese: attivo.",
    ["Avoiding contested zones: off."] = "Evita zone contese: disattivo.",
    ["Saved place: %s"] = "Luogo salvato: %s",
    ["Removed place: %s"] = "Luogo rimosso: %s",
    ["Hearthstone location recorded: %s"] = "Posizione della pietra del ritorno registrata: %s",
    ["  /gps mount auto|0|60|100  - mount speed"] = "  /gps mount auto|0|60|100  - velocità cavalcatura",
    ["  /gps avoid  - toggle avoiding contested zones"] = "  /gps avoid  - attiva/disattiva l'evitare le zone contese",
    ["  /gps save <name> | forget <name>  - save / remove your position as a place"] =
        "  /gps save <nome> | forget <nome>  - salva / rimuovi la tua posizione come luogo",
    ["  /gps home  - remember this spot as your Hearthstone location"] =
        "  /gps home  - ricorda questo punto come posizione della pietra del ritorno",
    ["  /gps record | record clear  - record the road you travel / forget this zone's"] =
        "  /gps record | record clear  - registra la strada che percorri / dimentica quelle di questa zona",
}

function ns:ApplyLocale()
    local lang = self.db and self.db.lang
    local useIt = lang == "it" or (lang == nil and GetLocale and GetLocale() == "itIT")
    for k in pairs(itIT) do
        rawset(L, k, useIt and itIT[k] or nil)
    end
end
