# WowGPS

*[Read me in English](README.md)*

Navigatore in stile Google Maps per **World of Warcraft: Forever** (Interface 16001).
Scegli una partenza e una destinazione e WowGPS ti propone fino a cinque modi di arrivarci, con tempo stimato e indicazioni tappa per tappa:

| Opzione | Cosa usa |
| --- | --- |
| A piedi | solo terra, alla velocità di corsa reale del tuo personaggio (navi/zeppelin solo se non esiste un percorso via terra) |
| Cavalcatura | solo terra, alla velocità reale della tua cavalcatura |
| Navi / zeppelin / tram | terra più trasporti pubblici e portale di Darnassus |
| Voli | tutto quanto sopra più i punti di volo |
| Pietra del ritorno | tutto quanto sopra, partendo con la pietra del ritorno quando è pronta e accorcia davvero il viaggio |

## Anteprima

Illustrazioni del layout con valori d'esempio: non sono screenshot presi in gioco, dove la finestra usa la grafica standard di WoW.

| Percorso calcolato | Suggerimenti mentre scrivi |
| --- | --- |
| ![Finestra con le quattro opzioni di viaggio e le tappe](docs/it-percorso.png) | ![Elenco dei suggerimenti sotto il campo Destinazione](docs/it-suggerimenti.png) |

## Installazione

Copia la cartella `WowGPS` in `World of Warcraft\_forever_\Interface\AddOns\`.
Addon opzionali: **Routes** e **TomTom**.

## Uso

`/gps` apre la finestra. Nei campi Partenza e Destinazione puoi scrivere:

- niente (o `qui`): la tua posizione
- una zona, una città, un villaggio, un dungeon, un punto di volo, un molo: `Forgiardente`, `Borgodoro`, `Baia del Bottino`
- `casa`: dove è fissata la tua pietra del ritorno
- un luogo salvato con `/gps save <nome>`
- una zona con coordinate: `Paludi Grigie 10 60`
- solo coordinate nella zona in cui sei: `42 65`
- `pin`: il pin che hai messo sulla mappa del mondo
- `Routes: <nome>`: il primo nodo di un percorso salvato in Routes

Mentre scrivi compaiono i suggerimenti. Scegli un'opzione, poi **Avvia navigazione**.

Comandi rapidi:

```
/gps <luogo>              percorso dalla tua posizione
/gps da <A> a <B>         percorso tra due luoghi (anche: from <A> to <B>)
/gps go [1-4]             avvia la navigazione (numero dell'opzione)
/gps stop | next          ferma / salta una tappa
/gps routes               invia il percorso a Routes
/gps routes clear         rimuove da Routes i percorsi creati da WowGPS
/gps mount auto|0|60|100  velocità della cavalcatura (auto = misurata)
/gps avoid                attiva/disattiva l'evitare le zone contese
/gps save <nome>          salva la tua posizione come luogo (forget <nome> la rimuove)
/gps home                 ricorda questo punto come posizione della pietra del ritorno
/gps record               avvia/ferma la registrazione della strada che percorri
/gps record clear         dimentica le strade registrate nella zona attuale
/gps lang it|en           lingua dell'addon
/gps mark                 stampa la tua posizione (per correggere i dati)
```

## Luoghi

Oltre a zone e città puoi andare verso villaggi, accampamenti e ingressi dei dungeon. WowGPS legge i punti di riferimento che il gioco mostra sulle mappe (quindi i nomi sono nella lingua del client e i luoghi nuovi di Forever sono inclusi) e ne aggiunge circa 120 del mondo classico. Con `/gps save <nome>` aggiungi i tuoi.

## Strade

I tratti via terra seguono le strade principali di ogni zona invece di una linea retta, e la navigazione sposta il waypoint da una curva alla successiva. Il gioco non fornisce agli addon i dati delle strade, quindi quelle in `WowGPS/World.lua` sono disegnate a mano e approssimative. Per rendere esatta una strada scrivi `/gps record`, percorrila una volta e scrivi di nuovo `/gps record`: le strade registrate vengono salvate e usate da lì in poi.

## La tua velocità

I tempi si basano sulla velocità reale del personaggio. La velocità di corsa viene misurata quando sei a piedi, quella della cavalcatura quando sei in sella, quindi i bonus di velocità sono compresi. Finché non sei salito in sella almeno una volta si assume una cavalcatura +60%. Il pulsante **Cavalcatura** (o `/gps mount`) passa tra misurata, nessuna, +60% e +100%.

## Pietra del ritorno

L'opzione Pietra del ritorno compare quando la pietra è nelle borse, è pronta e accorcia il viaggio; altrimenti la finestra spiega perché no. Il gioco comunica agli addon solo il *nome* della locanda: WowGPS registra il punto esatto quando la imposti, oppure cerca il nome tra i luoghi conosciuti. Se non ci riesce, vai alla tua locanda e scrivi `/gps home`.

## Zone contese

Ogni percorso elenca le zone contese e il territorio nemico che attraversa via terra (sorvolarli in volo non conta). Spunta **Evita le zone contese** per far girare intorno i tratti via terra quando esiste una deviazione ragionevole. L'appartenenza delle zone parte dalla tabella del mondo classico e viene corretta con quello che il gioco riporta ogni volta che entri in una zona.

## Lingua

L'addon è in inglese. Con il client di gioco in italiano passa da solo all'italiano; `/gps lang en` o `/gps lang it` forza una delle due. I nomi dei luoghi seguono sempre la lingua del client.

## Navigazione a waypoint

Durante la navigazione c'è un waypoint alla volta, che avanza da solo quando arrivi alla tappa.
Con TomTom installato viene usata la sua freccia; altrimenti il pin nativo della mappa.

## Integrazione con Routes

- **Invia a Routes**: i tratti via terra del percorso diventano percorsi di Routes (uno per zona, chiamati `WowGPS: <destinazione>`). Routes li disegna su mappa e minimappa e la sua funzione waypoint (con TomTom) può seguirli nodo per nodo. Compaiono nella lista di `/routes` dopo un `/reload`.
- **Percorsi di Routes come luoghi**: ogni percorso salvato in Routes si può usare come partenza o destinazione, ad esempio per raggiungere il tuo giro di raccolta.

## Come funziona e limiti

- I **punti di volo** sono letti dal client, quindi include anche quelli nuovi di Forever. Quali conosci viene imparato la prima volta che apri un maestro di volo su ogni continente; fino ad allora WowGPS li considera tutti disponibili e te lo segnala.
- I **confini tra zone, moli, torri e tram** sono in `WowGPS/Data.lua`. Le coordinate sono quelle del mondo classico e sono **approssimative**: vai sul punto giusto, scrivi `/gps mark` e correggi la riga.
- Anche **strade e luoghi** in `WowGPS/World.lua` sono disegnati a mano e approssimativi. Fuori strada, e nelle zone senza dati stradali, il percorso è una linea retta con un margine di sicurezza: non conosce montagne o fiumi.
- Le zone nuove di Forever non hanno ancora confini né strade nei dati: lì il percorso via terra è una linea retta, segnalata come stima, finché non registri le strade.
- Tempi di attesa di navi, zeppelin e tram sono medie stimate.

## Sviluppo

I test girano fuori dal gioco su Lua 5.1 con un'API di WoW simulata:

```
pip install lupa
python3 tests/run.py
```
