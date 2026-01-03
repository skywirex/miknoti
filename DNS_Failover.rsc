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
:local tertiaryDns "8.8.4.4"
:local testDomain "google.com"
:local checkInterval 1

# ===== GLOBAL VARIABLES =====
:global dnsFailoverStatus
:global dnsLastStatus
:global dnsFailoverTime

# Initialize status if not exists
:if (([:typeof $dnsFailoverStatus] = "nothing")) do={
    :set dnsFailoverStatus "private"
    :set dnsLastStatus "init"
    :set dnsFailoverTime [/system clock get time]
}

# ===== FUNCTIONS =====
:local function testDns do={
    :local dnsServer $1
    :local domain $2
    :local testResult false
    
    # Perform DNS resolution test
    :do {
        :if ([/ip dns cache print count-only where name=$domain] > 0) do={
            :set testResult true
        }
    } on-error={
        :set testResult false
    }
    
    :return $testResult
}

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
        :set msg ("DNS switched to <b>GOOGLE</b> (" . $secondaryDns . ", " . $tertiaryDns . ")")
        :log info "DNS switched to GOOGLE: $secondaryDns, $tertiaryDns"
    }
    
    :return $msg
}

# ===== MAIN LOGIC =====

:local privateDnsStatus "offline"
:local currentDnsStatus $dnsFailoverStatus

# Test private DNS connectivity
:if ([/ping $privateDnsIp count=1] > 0) do={
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
        # Private DNS is back online, switch back
        :set msg [$setDnsServers "private"]
        :set dnsFailoverStatus "private"
        :log info "DNS Failover: Switched back to PRIVATE DNS"
    } else={
        # Private DNS is down, switch to Google DNS
        :set msg [$setDnsServers "google"]
        :set dnsFailoverStatus "google"
        :log info "DNS Failover: Switched to GOOGLE DNS"
    }
    
    # Send notification
    :local currentDnsDisplay ""
    :if ($dnsFailoverStatus = "private") do={
        :set currentDnsDisplay ("Currently using: <b>PRIVATE DNS</b> (" . $primaryDns . ")")
    } else={
        :set currentDnsDisplay ("Currently using: <b>GOOGLE DNS</b> (" . $secondaryDns . ", " . $tertiaryDns . ")")
    }
    :local tgMsg ($msg . "\nPrivate DNS IP: " . $privateDnsIp . "\n" . $currentDnsDisplay . "\nTime: " . $curTime . "\nDate: " . $curDate . "\nStatus: " . $privateDnsStatus)
    
    # Discord message using Embed format (UNCOMMENT to enable)
    #:local embedPayload ("{\"embeds\":[{\"fields\":[{\"name\":\"" . $msg . "\",\"value\":\"Private DNS IP: " . $privateDnsIp . "\\n" . $currentDnsDisplay . "\\nTime: " . $curTime . "\\nDate: " . $curDate . "\\nStatus: " . $privateDnsStatus . "\"}]}]}")
    #:local discordMsg $embedPayload
    
    # Send notifications
    $TelegramSendMessage message=$tgMsg
    #$DiscordSendMessage message=$discordMsg
    
    :set dnsLastStatus $privateDnsStatus
    :set dnsFailoverTime $curTime
} else={
    :log debug "DNS Failover: Status unchanged - $privateDnsStatus"
}