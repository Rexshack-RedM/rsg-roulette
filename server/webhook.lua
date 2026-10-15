local WebhookUrl = Config.DiscordWebhook.Url
local BotName = Config.DiscordWebhook.BotName or 'Roulette Table'
local AvatarUrl = Config.DiscordWebhook.AvatarUrl or ''

local function sendWebhook(data)
    if not Config.DiscordWebhook.Enabled or not WebhookUrl or WebhookUrl == '' then return end

    local embed = {
        {
            title = data.title,
            description = data.description,
            color = data.color or 16711680,
            fields = data.fields or {},
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
            author = { name = BotName, icon_url = AvatarUrl ~= '' and AvatarUrl or nil }
        }
    }

    PerformHttpRequest(WebhookUrl, function(status)
        if status < 200 or status >= 300 then
            print(('[rsg-roulette] Discord webhook failed (HTTP %s)'):format(status))
        end
    end, 'POST', json.encode({ username = BotName, avatar_url = AvatarUrl ~= '' and AvatarUrl or nil, embeds = embed }), { ['Content-Type'] = 'application/json' })
end

function WebhookLogWin(playerName, amount, betType, result, resultColor, tableId)
    if amount < (Config.DiscordWebhook.MinWinAmount or 100) then return end

    sendWebhook({
        title = locale('webhook_win_title'),
        description = locale('webhook_win_desc', playerName, amount),
        color = 65280,
        fields = {
            { name = locale('webhook_field_bet_type'), value = betType, inline = true },
            { name = locale('webhook_field_result'), value = ('%d (%s)'):format(result, locale('color_' .. resultColor)), inline = true },
            { name = locale('webhook_field_table'), value = tableId or '-', inline = true }
        }
    })
end

function WebhookLogJackpot(playerName, amount, tableId)
    if not Config.DiscordWebhook.LogJackpot then return end

    sendWebhook({
        title = locale('webhook_jackpot_title'),
        description = locale('webhook_jackpot_desc', playerName, amount),
        color = 16776960,
        fields = {
            { name = locale('webhook_field_table'), value = tableId or '-', inline = true }
        }
    })
end

function WebhookLogSpin(result, resultColor, playerCount, totalBets, totalPayout, tableId)
    if not Config.DiscordWebhook.LogAllSpins then return end

    local colorMap = { green = 65280, red = 16711680, black = 0 }

    sendWebhook({
        title = locale('webhook_spin_title'),
        description = locale('webhook_spin_desc', result, locale('color_' .. resultColor)),
        color = colorMap[resultColor] or 16711680,
        fields = {
            { name = locale('webhook_field_players'), value = tostring(playerCount), inline = true },
            { name = locale('webhook_field_total_bets'), value = string.format('$%d', totalBets), inline = true },
            { name = locale('webhook_field_total_payout'), value = string.format('$%d', totalPayout), inline = true },
            { name = locale('webhook_field_table'), value = tableId or '-', inline = true }
        }
    })
end
