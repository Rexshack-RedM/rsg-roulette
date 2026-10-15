# rsg-roulette

Multiplayer European roulette tables for **RSG Framework** (RedM). Players share a table, place chips on a full betting layout during a timed round, and winnings are paid in cash server side.

## Features
- Shared, server-authoritative rounds (betting → spin → result) per table
- Straight, split, corner, red/black, odd/even, 1-18/19-36, dozens and columns
- All bets validated server side (type, numbers, adjacency, amount, cash, distance, rate limit)
- Last 12 results per table and "hottest numbers", saved to `data.json`
- Idle tables stop ticking; updates only go to players who have the table open
- Table props spawn locally within range (no networked duplicates)
- Optional Discord logging of big wins, jackpots and spins
- Admins place tables in-game with a live preview; tables are saved to the database
- ox_target interaction, map blips and ox_lib locales

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

## Installation
1. Drop `rsg-roulette` into your resources folder.
2. Add `ensure rsg-roulette` to your `server.cfg` after its dependencies.
3. Edit `config.lua` to set bet limits, placement settings and the Discord webhook.
4. Start the server. The `rsg_roulette_tables` table is created automatically (`installation.sql` is included for manual installs).
5. In-game, place tables with `/placeroulette`.

No items are required.

## Placing tables (admin)
| Command | Description |
|---|---|
| `/placeroulette` | Start placement with a preview of the table where you aim |
| `/removeroulette` | Remove the nearest table within 3m (open bets are refunded) |

While placing, a panel in the top left shows the keys, heading, height and whether the spot is valid:

| Key | Action |
|---|---|
| Mouse | Aim to move the table |
| ← / → | Rotate |
| ↑ / ↓ | Raise / lower |
| Enter | Place the table |
| Backspace | Cancel |

The preview fades when the spot is invalid (too close to another table, too far away or not aimed at a surface). Tables appear for every player straight away and persist across script and server restarts. Both commands are restricted to `group.admin`.

## Configuration
| Option | Description |
|---|---|
| `MinBet` / `MaxBet` | Smallest chip accepted / max **total** stake per player per spin |
| `BettingTime`, `SpinTime`, `ResultDisplayTime` | Round timings in seconds |
| `InteractDistance` | How close a player must be to bet (checked on the server) |
| `SpawnDistance` | Range at which the table prop is spawned for a player |
| `Blip` | Toggle, sprite and scale of the map blip |
| `Placement` | Aim range, rotate and height speed, max height offset, minimum spacing between tables |
| `DiscordWebhook` | Webhook URL and what to log |

## Payouts
| Bet | Pays |
|---|---|
| Straight / Green 0 | 35:1 |
| Split | 17:1 |
| Corner | 8:1 |
| Red/Black, Odd/Even, 1-18/19-36 | 1:1 |
| Dozens, Columns | 2:1 |

Zero loses all outside bets.

## Exports (client)
```lua
exports['rsg-roulette']:openRoulette('table_1') -- player must still be in range
```

## Locales
Every player-facing string (notifications, commands, Discord logs and the whole UI) lives in `locales/*.json` via ox_lib.

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`

Set the server language in `server.cfg`:
```cfg
setr ox:locale "de"
```
To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values (keep the `%s` placeholders).

## Building the UI
The compiled UI is included in `web/build`. To change it:
```bash
cd web
npm ci
npm run build   # type-checks, then builds into web/build
```

## Support
☕ https://buymeacoffee.com/rexshack
