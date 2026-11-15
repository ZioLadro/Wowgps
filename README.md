# WowGPS

*[Leggimi in italiano](README.it.md)*

A Google Maps style navigator for **World of Warcraft: Forever** (Interface 16001).
Pick a start and a destination and WowGPS offers up to five ways to get there, each with an estimated time and step-by-step directions:

| Option | What it uses |
| --- | --- |
| On foot | ground only, at your character's real running speed (boats/zeppelins only when there is no land route) |
| Mount | ground only, at your real mount speed |
| Boats / zeppelins / tram | ground plus public transport and the Darnassus portal |
| Flight paths | all of the above plus flight points |
| Hearthstone | all of the above, starting with your Hearthstone when it is ready and actually shortens the trip |

## Preview

Layout illustrations with example values: these are not in-game screenshots, where the window uses the standard WoW artwork.

| Computed route | Suggestions as you type |
| --- | --- |
| ![Window with the four travel options and the steps](docs/preview-route.png) | ![Suggestion list under the Destination field](docs/preview-suggestions.png) |

## Installation

Copy the `WowGPS` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
Optional addons: **Routes** and **TomTom**.

## Usage

`/gps` opens the window. In the Start and Destination fields you can type:

- nothing (or `here`): your position
- a zone, a city, a town, a dungeon, a flight point, a dock: `Ironforge`, `Goldshire`, `Booty Bay`
- `home`: where your Hearthstone is bound
- a place you saved with `/gps save <name>`
- a zone with coordinates: `Wetlands 10 60`
- coordinates only, in the zone you are in: `42 65`
- `pin`: the pin you placed on the world map
- `Routes: <name>`: the first node of a route saved in Routes

Suggestions appear as you type. Pick an option, then press **Navigate**.

Quick commands:

```
/gps <place>              directions from your position
/gps from <A> to <B>      directions between two places
/gps go [1-4]             start navigation (option number)
/gps stop | next          stop / skip a step
/gps routes               send the route to Routes
/gps routes clear         remove the routes WowGPS created in Routes
/gps mount auto|0|60|100  mount speed (auto = measured)
/gps avoid                toggle avoiding contested zones
/gps save <name>          save your position as a place (forget <name> removes it)
/gps home                 remember this spot as your Hearthstone location
/gps record               start/stop recording the road you travel
/gps record clear         forget the recorded roads of the current zone
/gps lang en|it           addon language
/gps mark                 print your position (to fix the data)
```

## Places

Besides zones and cities you can route to towns, camps and dungeon entrances. WowGPS reads the landmarks the game shows on its maps (so names are in your client's language and new Forever places are included) and adds about 120 classic-world places of its own. `/gps save <name>` adds your own.

## Roads

Ground travel follows the main roads of each zone instead of a straight line, and navigation moves the waypoint from bend to bend. The game does not expose road data to addons, so the roads in `WowGPS/World.lua` were drawn by hand and are approximate. To make a road exact, type `/gps record`, ride it once and type `/gps record` again: recorded roads are saved and used from then on.

## Your speed

Times are based on your character's real speed. Running speed is measured whenever you are on foot, mount speed whenever you are mounted, so speed bonuses are included. Until you have mounted once, a +60% mount is assumed. The **Mount** button (or `/gps mount`) switches between measured, none, +60% and +100%.

## Hearthstone

The Hearthstone option appears when the stone is in your bags, off cooldown and makes the trip shorter; otherwise the window says why not. The game only tells addons the *name* of your inn: WowGPS records the exact spot when you bind, or finds the name among known places. If it cannot, stand at your inn and type `/gps home`.

## Contested zones

Every route lists the contested zones and enemy territory it crosses on the ground (flying over does not count). Tick **Avoid contested zones** to make ground travel go around them when a reasonable detour exists. Zone ownership starts from the classic-world table and is corrected with what the game reports each time you enter a zone.

## Language

The addon is in English. On an Italian game client it switches to Italian automatically; `/gps lang en` or `/gps lang it` forces one or the other. Place names always follow the language of your game client.

## Waypoint navigation

While navigating there is one waypoint at a time, and it advances by itself when you reach the step.
With TomTom installed its arrow is used; otherwise the built-in map pin.

## Routes integration

- **Send to Routes**: the ground segments of the route become Routes routes (one per zone, named `WowGPS: <destination>`). Routes draws them on the map and minimap, and its waypoint feature (with TomTom) can follow them node by node. They show up in the `/routes` list after a `/reload`.
- **Routes routes as places**: every route saved in Routes can be used as a start or a destination, for example to travel to your gathering loop.

## How it works and limits

- **Flight points** are read from the game client, so new Forever ones are included. Which ones you know is learned the first time you open a flight master on each continent; until then WowGPS treats them all as available and tells you so.
- **Zone borders, docks, towers and the tram** live in `WowGPS/Data.lua`. The coordinates come from the classic world and are **approximate**: stand on the right spot, type `/gps mark` and fix the line.
- **Roads and places** in `WowGPS/World.lua` are hand-drawn and approximate too. Off the road, and in zones without road data, the route is a straight line with a safety margin: it does not know mountains or rivers.
- New Forever zones have no borders or roads in the data yet: there the ground route is a straight line, flagged as an estimate, until you record roads.
- Waiting times for boats, zeppelins and the tram are estimated averages.
- Not tested in game yet: the logic is covered by the out-of-game tests below.

## Development

The tests run outside the game on Lua 5.1 against a simulated WoW API:

```
pip install lupa
python3 tests/run.py
```
