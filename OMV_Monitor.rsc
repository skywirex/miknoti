# Monitoring the status of server
:global TelegramSendMessage
/system script run TelegramSendMessage

# Config
:global omvLastStatus
:local omvIp "172.16.0.10"
:local pingCount 3
:local isUp false

# Perform ping test
:if ([/ping $omvIp count=$pingCount] > 0) do={ :set isUp true }

:if (([:typeof $omvLastStatus] = "nothing") || ($isUp != $omvLastStatus)) do={
    :local state "<b>ONLINE</b>"
    :if (!$isUp) do={ :set state "<b>OFFLINE</b>" }

    # Get current values into variables first
    :local curTime [/system clock get time]
    :local curDate [/system clock get date]
    
    # Note: Using `\n` for the new line
    :local msg "OpenMediaVault is $state\nIP: $omvIp\nTime: $curTime\nDate: $curDate"
    
    # Call the global function
    $TelegramSendMessage message=$msg
    
    :log info "OpenMediaVault Monitor: $state detected"
    :set omvLastStatus $isUp
}