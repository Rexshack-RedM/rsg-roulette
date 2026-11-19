# rsg-roulette — Developer Docs

## Dependencies
`rsg-core`, `oxmysql`, `rsg-target`. **No ox_lib** — locales, notify, callbacks, model loading and commands all come from rsg-core.

## Locales
- fxmanifest loads `@rsg-core/shared/locale.lua`; Lua uses `locale('key', ...)`.
- Language: `setr rsg:locale "de"` (falls back to `ox:locale`, then `en`).
- The NUI receives a flat locale table from `GetLocaleTable()` (client/nui.lua): English merged with the selected language, so missing keys fall back to English.
- Supported: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru.

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

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-roulette 3.0.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`, `rsg-target`

### Database

Tables: `rsg_roulette_tables`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/installation.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.MinBet` | `1` | smallest single chip accepted |
| `Config.MaxBet` | `500` | max TOTAL stake per player per spin |
| `Config.BettingTime` | `30` | seconds |
| `Config.SpinTime` | `5` | seconds |
| `Config.ResultDisplayTime` | `8` | seconds |
| `Config.InteractDistance` | `3.0` | max distance from a table to bet (checked server side) |
| `Config.SpawnDistance` | `80.0` | table prop spawns / despawns locally within this range |
| `Config.Blip` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.Sprite` | `'blip_mg_poker'` |  |
| `Config.Scale` | `0.2` |  |
| `Config.Placement` | `table` | remove the nearest one with /removeroulette |
| `Config.MaxDistance` | `10.0` |  |
| `Config.RotateStep` | `1.5` |  |
| `Config.HeightStep` | `0.01` |  |
| `Config.MaxHeight` | `2.0` |  |
| `Config.MinSpacing` | `2.5` |  |
| `Config.DiscordWebhook` | `table` |  |
| `Config.Url` | `''` |  |
| `Config.MinWinAmount` | `100` |  |
| `Config.LogJackpot` | `true` |  |
| `Config.LogAllSpins` | `false` |  |
| `Config.BotName` | `'Roulette Table'` |  |
| `Config.AvatarUrl` | `''` |  |

### Exports

**Client**

| Export | Arguments | File |
|---|---|---|
| `openRoulette` | `` | `client/roulette.lua` |

```lua
-- example
local result = exports['rsg-roulette']:openRoulette()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-roulette:server:getTables` | server | `_, cb` | `server/roulette.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-roulette:server:getTables', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-roulette:client:startPlacement` | client | `` | `client/placement.lua` |
| `rsg-roulette:client:syncState` | client | `data` | `client/roulette.lua` |
| `rsg-roulette:client:forceClose` | client | `` | `client/roulette.lua` |
| `rsg-roulette:client:addTable` | client | `` | `client/tables.lua` |
| `rsg-roulette:client:removeTable` | client | `` | `client/tables.lua` |
| `rsg-roulette:server:join` | server | `tableId` | `server/roulette.lua` |
| `rsg-roulette:server:leave` | server | `tableId` | `server/roulette.lua` |
| `rsg-roulette:server:placeBet` | server | `tableId, bet` | `server/roulette.lua` |
| `rsg-roulette:server:removeBet` | server | `tableId, bet` | `server/roulette.lua` |
| `rsg-roulette:server:clearBets` | server | `tableId` | `server/roulette.lua` |
| `rsg-roulette:server:placeTable` | server | `coords, heading, room` | `server/roulette.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-roulette:server:join', tableId)
-- from a server script
TriggerClientEvent('rsg-roulette:client:startPlacement', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/placeroulette` | locale('cmd_place_help') | `server/roulette.lua` |
| `/removeroulette` | locale('cmd_remove_help') | `server/roulette.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
