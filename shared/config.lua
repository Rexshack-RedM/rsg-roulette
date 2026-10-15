Config = {}

---------------------------------
-- betting
---------------------------------
Config.MinBet            = 1     -- smallest single chip accepted
Config.MaxBet            = 500   -- max TOTAL stake per player per spin
Config.BettingTime       = 30    -- seconds
Config.SpinTime          = 5     -- seconds
Config.ResultDisplayTime = 8     -- seconds

---------------------------------
-- tables
---------------------------------
Config.InteractDistance = 3.0   -- max distance from a table to bet (checked server side)
Config.SpawnDistance    = 80.0  -- table prop spawns / despawns locally within this range

Config.Blip = {
    Enabled = true,
    Sprite  = 'blip_mg_poker',
    Scale   = 0.2,
}

-- tables are placed in-game by admins with /placeroulette and saved to the database
-- remove the nearest one with /removeroulette
Config.Placement = {
    MaxDistance = 10.0, -- how far from the admin a table can be placed (mouse aim range)
    RotateStep  = 1.5,  -- degrees per frame while holding left/right
    HeightStep  = 0.01, -- metres per frame while holding up/down
    MaxHeight   = 2.0,  -- max height offset up or down from the aimed surface
    MinSpacing  = 2.5,  -- minimum gap between two tables
}

---------------------------------
-- discord logging
---------------------------------
Config.DiscordWebhook = {
    Enabled      = true,
    Url          = '',
    MinWinAmount = 100,   -- log wins at or above this amount
    LogJackpot   = true,  -- log wins on green 0
    LogAllSpins  = false, -- log every spin result (spammy)
    BotName      = 'Roulette Table',
    AvatarUrl    = '',
}
