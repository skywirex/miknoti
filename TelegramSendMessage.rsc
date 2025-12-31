:global TelegramSendMessage do={
    # ===== TELEGRAM CONFIG =====
    :local tgBotToken "1234567890:XXXXXXXXXX"
    :local tgChatID "123456789"
    :local tgMsg $message

    :if ([:len $tgMsg] > 0) do={
        :local url ("https://api.telegram.org/bot" . $tgBotToken . "/sendMessage?chat_id=" . $tgChatID . "&text=" . $tgMsg . "&parse_mode=HTML")

        :local result [/tool fetch url=$url mode=https keep-result=no as-value]
        :if ($result->"status" = "finished") do={
            :log info ("Telegram sent: " . $tgMsg)
        } else={
            :log warning ("Telegram send failed: " . ($result->"status"))
        }
    } else={
        :log warning "TelegramSendMessage: No message provided"
    }
}