# =====Script Name: DNS_Failover=====
# =====Automatic DNS Failover Monitor=====
# Switches between Private DNS and Google DNS based on connectivity status

:global TelegramSendMessage
:global DiscordSendMessage
/system script run MikNotiMessage

# ===== CONFIG =====
:local privateDnsIp "172.16.0.25"
:local primaryDns $privateDnsIp
:local secondaryDns "8.8.8.8"
:local testDomain "google.com"
:local checkInterval 1

# ===== GLOBAL VARIABLES =====
:global dnsFailoverStatus
:global dnsLastStatus

# Initialize status if not exists
:if (([:typeof $dnsFailoverStatus] = "nothing")) do={
    :set dnsFailoverStatus "private"
    :set dnsLastStatus "init"
}

# ===== FUNCTIONS =====

:local function getDnsServers do={
    :local dnsServers ""
    :foreach entry in=[/ip dns static find] do={
        :local addr [/ip dns static get $entry address]
        :set dnsServers ($dnsServers . $addr . ",")
    }
    :return $dnsServers
}

:local function setDnsServers do={
    :local mode $1
    :local msg ""
    
    :if ($mode = "private") do={
        # Set to private DNS
        /ip dns set servers=$primaryDns allow-remote-requests=yes
        :set msg ("DNS switched to <b>PRIVATE</b> (" . $primaryDns . ")")
        :log info "DNS switched to PRIVATE: $primaryDns"
    } else {
        # Set to Google DNS
        /ip dns set servers=$secondaryDns allow-remote-requests=yes
        :set msg ("DNS switched to <b>GOOGLE</b> (" . $secondaryDns . ")")
        :log info "DNS switched to GOOGLE: $secondaryDns"
    }
    
    :return $msg
}

# ===== MAIN LOGIC =====

:local privateDnsStatus "offline"
:local currentDnsStatus $dnsFailoverStatus
:local resolveResult ""

# Test private DNS connectivity
:do {
    :set resolveResult [/resolve $testDomain server=$privateDnsIp]
    :if ([:len $resolveResult] > 0) do={
        :set privateDnsStatus "online"
    } else={
        :set privateDnsStatus "offline"
    }
} on-error={
    # If /resolve fails with an error, consider private DNS offline
    :set privateDnsStatus "offline"
    :log warning "DNS Failover: Error resolving $testDomain via $privateDnsIp."
}


# Check if status changed
:if ($privateDnsStatus != $dnsLastStatus) do={
    :local msg ""
    :local curTime [/system clock get time]
    :local curDate [/system clock get date]
    
    :if ($privateDnsStatus = "online") do={
        # Private DNS is back online, switch back
        /ip dns set servers=$primaryDns allow-remote-requests=yes
        :set msg [$setDnsServers "private"]
        :set dnsFailoverStatus "private"
        :log info "DNS Failover: Switched back to PRIVATE DNS"
    } else={
        # Private DNS is down, switch to Google DNS
        /ip dns set servers=$secondaryDns allow-remote-requests=yes
        :set msg [$setDnsServers "google"]
        :set dnsFailoverStatus "google"
        :log info "DNS Failover: Switched to GOOGLE DNS"
    }
    
    # Send notification
    :local currentDnsDisplay ""
    :if ($dnsFailoverStatus = "private") do={
        :set currentDnsDisplay ("Currently using: <b>PRIVATE DNS</b> (" . $primaryDns . ")")
    } else={
        :set currentDnsDisplay ("Currently using: <b>GOOGLE DNS</b> (" . $secondaryDns . ")")
    }
    :local tgMsg ($msg . "\nPrivate DNS IP: " . $privateDnsIp . "\n" . $currentDnsDisplay . "\nTime: " . $curTime . "\nDate: " . $curDate . "\nStatus: " . $privateDnsStatus)
    
    # Discord message using Embed format (UNCOMMENT to enable)
    #:local embedPayload ("{\"embeds\":[{\"fields\":[{\"name\":\"" . $msg . "\",\"value\":\"Private DNS IP: " . $privateDnsIp . "\\n" . $currentDnsDisplay . "\\nTime: " . $curTime . "\\nDate: " . $curDate . "\\nStatus: " . $privateDnsStatus . "\"}]}]}")
    #:local discordMsg $embedPayload
    
    # Send notifications
    $TelegramSendMessage message=$tgMsg
    #$DiscordSendMessage message=$discordMsg
    
    :set dnsLastStatus $privateDnsStatus
} else={
    :log debug "DNS Failover: Status unchanged - $privateDnsStatus"
}