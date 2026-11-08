# rsg-roulette — Developer Docs

## Dependencies
`rsg-core`, `oxmysql`, `rsg-target`. **No ox_lib** — locales, notify, callbacks, model loading and commands all come from rsg-core.

## Locales
- fxmanifest loads `@rsg-core/shared/locale.lua`; Lua uses `locale('key', ...)`.
- Language: `setr rsg:locale "de"` (falls back to `ox:locale`, then `en`).
- The NUI receives a flat locale table from `GetLocaleTable()` (client/nui.lua): English merged with the selected language, so missing keys fall back to English.
- Supported: en, de, el, es, fr, ja, nl, pl, pt-br, ro.

## Commands (admin)
| Command | Description |
|---|---|
| `/placeroulette` | Start placement mode (arrows rotate/height, Enter confirm, Backspace cancel) |
| `/removeroulette` | Remove the nearest table within 3 m (refunds open bets) |

Registered via `RSGCore.Commands.Add(..., 'admin')`. Placement is re-validated server-side (`RSGCore.Functions.HasPermission(src, 'admin')`).

## Callbacks
| Name | Side | Returns |
|---|---|---|
| `rsg-roulette:server:getTables` | server (`RSGCore.Functions.CreateCallback`) | list of `{ id, coords, heading, room }` |

## Events
| Event | Direction | Purpose |
|---|---|---|
| `rsg-roulette:server:join` / `:leave` | C→S | open/close a table view |
| `rsg-roulette:server:placeTable` | C→S | admin places a table (validated) |
| `rsg-roulette:client:addTable` / `:removeTable` | S→C | sync tables |
| `rsg-roulette:client:startPlacement` | S→C | begin placement mode |
| `rsg-roulette:client:forceClose` | S→C | close UI (too far, table removed) |

Notifications: client `RSGCore.Functions.Notify`, server `RSGCore:Client:Notify`.

## Props
Table props are local (non-networked) and spawned by a 1 s proximity thread within `Config.SpawnDistance` (replaces `lib.points`). Interaction is an `exports['rsg-target']:addSphereZone`.

## Database
`rsg_roulette_tables` (see `installation/installation.sql`).
