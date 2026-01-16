# =====Script Name: OMV_Monitor=====
# =====Monitoring ON/OFF Status of Server=====
:global TelegramSendMessage
:global DiscordSendMessage
/system script run MikNotiMessage

# ===== CONFIG (Replace with your IP) ===== 
:local omvIp "172.16.0.10"
:global omvLastStatus
:local pingCount 3
:local isUp false

# Perform ping test
:if ([/ping $omvIp count=$pingCount] > 0) do={ :set isUp true }

:if (([:typeof $omvLastStatus] = "nothing") || ($isUp != $omvLastStatus)) do={
    :local state "ONLINE"
    :if (!$isUp) do={ :set state "OFFLINE" }

    # Get current values into variables first
    :local curTime [/system clock get time]
    :local curDate [/system clock get date]
    
    # Telegram message with proper formatting
    :local tgMsg ("OpenMediaVault is <b>" . $state . "</b>\nIP: " . $omvIp . "\nTime: " . $curDate . " " . $curTime)
    
    # Discord message using Embed format, UNCOMMENT to enable Discord
    #:local embedPayload ("{\"embeds\":[{\"fields\":[{\"name\":\"OpenMediaVault is " . $state . "\",\"value\":\"IP: " . $omvIp . "\\nTime: " . $curDate . " " . $curTime . "\"}]}]}")
    #:local discordMsg $embedPayload
    
    # Call functions, UNCOMMENT to enable Discord
    $TelegramSendMessage message=$tgMsg
    #$DiscordSendMessage message=$discordMsg
    
    :log info "OpenMediaVault Monitor: $state detected"
    :set omvLastStatus $isUp
}