# =====Script Name: DNS_Failover=====
# =====Switches between Private DNS and Google DNS=====

# ===== CONFIG =====
:local privateDnsIp "8.8.8.8" # CHANGE TO YOUR DNS
:local primaryDns $privateDnsIp
:local secondaryDns "8.8.8.8"
:local testDomain "google.com"

# ===== GLOBAL VARIABLES =====
:global dnsFailoverStatus
:global dnsLastStatus
:global TelegramSendMessage
:global DiscordSendMessage
/system script run MikNotiMessage

# Initialize status if not exists
:if ([:typeof $dnsFailoverStatus] = "nothing") do={
    :set dnsFailoverStatus "private"
    :set dnsLastStatus "init"
}

# ===== FUNCTIONS =====
:local setDnsServers do={
    :local mode $1
    :local primary $2
    :local secondary $3
    :local msg ""
    
    :if ($mode = "private") do={
        /ip dns set servers=$primary allow-remote-requests=yes
        /ip dns cache flush
        :set msg ("DNS switched: " . $primary . " (PRIVATE)")
        :log info "DNS switched: $primary PRIVATE"
    } else {
        /ip dns set servers=$secondary allow-remote-requests=yes
        /ip dns cache flush
        :set msg ("DNS switched: " . $secondary . " (GOOGLE)")
        :log info "DNS switched: $secondary GOOGLE"
    }
    :return $msg
}

# ===== MAIN =====

:local privateDnsStatus "offline"
:local successCount 0
:local attempts 2

# Test private DNS connectivity with Retries
:for i from=1 to=$attempts do={
    :do {
        :local resolveResult [/resolve $testDomain server=$privateDnsIp]
        :if ([:len $resolveResult] > 0) do={
            :set successCount ($successCount + 1)
            :set i $attempts ; # Success, exit loop early
        }
    } on-error={
        :log debug "DNS Failover: Attempt $i failed for $privateDnsIp"
        :if ($i < $attempts) do={ :delay 1s } ; # Wait before retry
    }
}

:if ($successCount > 0) do={
    :set privateDnsStatus "online"
} else={
    :set privateDnsStatus "offline"
}

# Check if status changed
:if ($privateDnsStatus != $dnsLastStatus) do={
    :local msg ""
    :local curTime [/system clock get time]
    :local curDate [/system clock get date]
    
    :if ($privateDnsStatus = "online") do={
        :set msg [$setDnsServers "private" $primaryDns $secondaryDns]
        :set dnsFailoverStatus "private"
    } else={
        :set msg [$setDnsServers "google" $primaryDns $secondaryDns]
        :set dnsFailoverStatus "google"
    }
    
    # Notification Formatting, UNCOMMENT to enable Discord
    :local tgMsg ("<b>" . $msg . "</b>\nTime: " . $curDate . " " . $curTime . "\nPrivate DNS: " . $privateDnsStatus)
    #:local discordMsg ("{\"embeds\":[{\"fields\":[{\"name\":\"" . $msg . "\",\"value\":\"Time: " . $curDate . " " . $curTime . "\\nPrivate DNS: " . $privateDnsStatus . "\"}]}]}")    
    
    # Send notifications, UNCOMMENT to enable Discord
    $TelegramSendMessage message=$tgMsg
    #$DiscordSendMessage message=$discordMsg
    
    :set dnsLastStatus $privateDnsStatus
} else={
    :log debug "DNS Failover: Status unchanged - $privateDnsStatus"
}