# =====Script Name: MikNotiMessage=====

# ===== INTERNET CHECK =====
:global MikNotiCheckConn do={
    :if ([/ping 8.8.8.8 count=1] = 0) do={
        :log warning ("$service: No internet connection. Message skipped.")
        :return false
    }
    :return true
}

# ===== TELEGRAM =====
:global TelegramSendMessage do={
    # ===== CONFIG =====
    :local tgBotToken "1234567890:XXXXXXXXXX"
    :local tgChatID "123456789"
    :local tgMsg $message

    :global MikNotiCheckConn
    :if ([$MikNotiCheckConn service="TelegramSendMessage"] = false) do={
        :return nil
    }

    :if ([:len $tgMsg] > 0) do={
        :local url ("https://api.telegram.org/bot" . $tgBotToken . "/sendMessage")
        :local payload ("{\"chat_id\":\"" . $tgChatID . "\",\"text\":\"" . $tgMsg . "\",\"parse_mode\":\"HTML\"}")

        :local result [/tool fetch url=$url http-method=post http-data=$payload http-header-field="Content-Type: application/json" mode=https keep-result=no as-value]
        :if ($result->"status" = "finished") do={
            :log info ("Telegram sent: " . $tgMsg)
        } else={
            :log warning ("Telegram send failed: " . ($result->"status"))
        }
    } else={
        :log warning "TelegramSendMessage: No message provided"
    }
}

# ===== DISCORD =====
:global DiscordSendMessage do={
    # ===== CONFIG =====
    :local discordWebhookUrl "https://discordapp.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
    :local discordMsg $message

    :global MikNotiCheckConn
    :if ([$MikNotiCheckConn service="DiscordSendMessage"] = false) do={
        :return nil
    }

    :if ([:len $discordMsg] > 0) do={
        :local result [/tool fetch url=$discordWebhookUrl http-method=post http-data=$discordMsg http-header-field="Content-Type: application/json" mode=https keep-result=no as-value]
        :if ($result->"status" = "finished") do={
            :log info ("Discord sent successfully")
        } else={
            :log warning ("Discord send failed: " . ($result->"status"))
        }
    } else={
        :log warning "DiscordSendMessage: No message provided"
    }
}