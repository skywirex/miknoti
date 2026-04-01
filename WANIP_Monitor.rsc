# =====Script Name: WANIP_Monitor=====
# =====Monitoring WAN IP Status of Internet Line=====
:global TelegramSendMessage
:global DiscordSendMessage
/system script run MikNotiMessage

# ===== CONFIG (Please edit these values) =====
# Set the name of your WAN interface (e.g., pppoe-out1, ether1)
:local wanInterface "pppoe-out1"

# Define the suffix for the dynamic IPv6 route. This will be appended to your /64 WAN prefix.
# Example: If WAN prefix is 2001:db8::/64 and suffix is "1111::/80", the route will be for 2001:db8:1111::/80.
:local ipv6RouteSuffix "1111::/80"
:local ipv6RouteGateway "fe80::1111:2222:3333:4444%bridgeLAN"
:local ipv6RouteComment "IP6_ROUTE"
# ===== END CONFIG =====

:global wanIpv4Last
:global wanIpv6Last

# --- Get Current Date and Time ---
:local curDate [/system clock get date]
:local curTime [/system clock get time]

# -------------------- IPv4 CHECK --------------------
:do {
    :local currentIpv4 ""
    # Find the IPv4 address on the specified WAN interface
    :local ipId [/ip address find interface=$wanInterface disabled=no]
    :if ([:len $ipId] > 0) do={
        :set currentIpv4 [:pick [/ip address get $ipId address] 0 [:find [/ip address get $ipId address] "/"]]
    }

    # Check if IPv4 has changed or if it's the first run
    :if (([:typeof $wanIpv4Last] = "nothing") || ($currentIpv4 != $wanIpv4Last)) do={
        # Only send notification if the new IP is not empty
        :if ([:len $currentIpv4] > 0) do={
            :local tgMsg "WAN IPv4 Changed\nNew IP: <b>$currentIpv4</b>\nTime: $curDate $curTime"
            :local discordMsg ("{\"embeds\":[{\"fields\":[{\"name\":\"WAN IPv4 Changed\",\"value\":\"New IP: " . $currentIpv4 . "\\nTime: " . $curDate . " " . $curTime . "\"}]}]}")
            $TelegramSendMessage message=$tgMsg
            $DiscordSendMessage message=$discordMsg
            :log info "WANIP_Monitor: WAN IPv4 changed to $currentIpv4"
        }
        :set wanIpv4Last $currentIpv4
    }
}

# -------------------- IPv6 CHECK --------------------
:do {
    :local currentIpv6 ""
    :local currentIpv6Network ""
    # Find a global, non-temporary IPv6 address on the WAN interface
    :local ipIds [/ipv6 address find interface=$wanInterface global !temporary disabled=no]
    :if ([:len $ipIds] > 0) do={
        # We use the first address found
        :local ipId ($ipIds->0)
        :set currentIpv6 [:pick [/ipv6 address get $ipId address] 0 [:find [/ipv6 address get $ipId address] "/"]]
        :set currentIpv6Network [/ipv6 address get $ipId network]
    }

    # Check if IPv6 has changed or if it's the first run
    :if (([:typeof $wanIpv6Last] = "nothing") || ($currentIpv6 != $wanIpv6Last)) do={
        # Only proceed if the new IP is not empty
        :if ([:len $currentIpv6] > 0) do={
            :local tgMsg "WAN IPv6 Changed\nNew Prefix: <b>$currentIpv6</b>\nTime: $curDate $curTime"
            :local discordMsg ("{\"embeds\":[{\"fields\":[{\"name\":\"WAN IPv6 Changed\",\"value\":\"New Prefix: " . $currentIpv6 . "\\nTime: " . $curDate . " " . $curTime . "\"}]}]}")
            $TelegramSendMessage message=$tgMsg
            $DiscordSendMessage message=$discordMsg
            :log info "WANIP_Monitor: WAN IPv6 changed to $currentIpv6"

            # --- Update IPv6 Route ---
            # Check if we got a valid network prefix (must be a /64, so ends in "::")
            :if ([:len $currentIpv6Network] > 0 && [:pick $currentIpv6Network ([:len $currentIpv6Network] - 2) [:len $currentIpv6Network]] = "::") do={
                :log info "WANIP_Monitor: Updating IPv6 route."
                
                # Remove previous route(s) with the same comment
                :foreach routeId in=[/ipv6 route find comment=$ipv6RouteComment] do={
                    /ipv6 route remove $routeId
                }
                :log info "WANIP_Monitor: Removed old IPv6 route(s)."
                
                # Construct the new route destination from the /64 prefix
                :local networkPrefixBase [:pick $currentIpv6Network 0 ([:len $currentIpv6Network] - 2)]
                :local newIpv6RouteDst ($networkPrefixBase . ":" . $ipv6RouteSuffix)

                # Add the new route
                /ipv6 route add dst-address=$newIpv6RouteDst gateway=$ipv6RouteGateway comment=$ipv6RouteComment
                :log info "WANIP_Monitor: Added new IPv6 route for $newIpv6RouteDst."
            } else={
                :log warning "WANIP_Monitor: Could not determine a valid /64 network prefix from '$currentIpv6Network'. Skipping IPv6 route update."
            }
        }
        :set wanIpv6Last $currentIpv6
    }
}
