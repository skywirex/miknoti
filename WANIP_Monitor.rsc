# =====Script Name: WANIP_Monitor=====
# =====Monitoring WAN IP Status of Internet Line=====
:global TelegramSendMessage
:global DiscordSendMessage
/system script run MikNotiMessage

# ===== CONFIG ==============================================================================================
:global wanInterface     "pppoe-out1"
:global ipv6PoolName     "ipv6-pool-vnpt"
:global ipv6RouteGateway "fe80::f3d1:71a:a23f:8f1c%bridgeLAN"
# ===== END CONFIG ===========================================================================================

:global wanIpv4Last
:global wanIpv6Last

:local now ([/system clock get date] . " " . [/system clock get time])

# =============================================================
# IPv4 CHECK
# =============================================================
:local curIpv4 ""
:local ids4 [/ip address find interface=$wanInterface disabled=no]
:if ([:len $ids4] > 0) do={
    :local raw [/ip address get ($ids4->0) address]
    :set curIpv4 [:pick $raw 0 [:find $raw "/"]]
}

:if ($curIpv4 != "") do={
    :if ([:typeof $wanIpv4Last] = "nothing" || $wanIpv4Last = "") do={
        :set wanIpv4Last $curIpv4
        :log info "WANIP_Monitor [IPv4] Initialized: $curIpv4"
    } else={
        :if ($curIpv4 != $wanIpv4Last) do={
            :log info "WANIP_Monitor [IPv4] Changed: $wanIpv4Last -> $curIpv4"
            $TelegramSendMessage message=("WAN IPv4 Changed\nNew IP: <b>" . $curIpv4 . "</b>\nTime: " . $now)
            $DiscordSendMessage  message=("{\"embeds\":[{\"fields\":[{\"name\":\"WAN IPv4 Changed\",\"value\":\"New IP: " . $curIpv4 . "\\nTime: " . $now . "\"}]}]}")
            :set wanIpv4Last $curIpv4
        }
    }
} else={
    :log debug "WANIP_Monitor [IPv4] No address on $wanInterface — skipping."
}

# =============================================================
# IPv6 CHECK
# Get prefix from /ipv6 pool — the most accurate source, can be
# assigned to a local variable, independent of RouterOS version.
# =============================================================
:local curIpv6 ""
:local  ipv6RouteSuffix  "1111::/80"
:local  ipv6RouteComment "IP6_ROUTE"

:local poolIds [/ipv6 pool find name=$ipv6PoolName]
:if ([:len $poolIds] > 0) do={
    :local raw [/ipv6 pool get ($poolIds->0) prefix]
    :if ([:typeof $raw] != "nothing" && $raw != "") do={
        :set curIpv6 $raw
    }
}

:if ($curIpv6 != "") do={
    :if ([:typeof $wanIpv6Last] = "nothing" || $wanIpv6Last = "") do={
        :set wanIpv6Last $curIpv6
        :log info "WANIP_Monitor [IPv6] Initialized: $curIpv6"
    } else={
        :if ($curIpv6 != $wanIpv6Last) do={
            :log info "WANIP_Monitor [IPv6] Changed: $wanIpv6Last -> $curIpv6"
            $TelegramSendMessage message=("WAN IPv6 Prefix Changed\nNew Prefix: <b>" . $curIpv6 . "</b>\nTime: " . $now)
            $DiscordSendMessage  message=("{\"embeds\":[{\"fields\":[{\"name\":\"WAN IPv6 Prefix Changed\",\"value\":\"New Prefix: " . $curIpv6 . "\\nTime: " . $now . "\"}]}]}")

            # --- Update static IPv6 route ---
            # curIpv6 = "2001:ee0:d788:26c0::/60"
            # Split the part before "/", then before "::" to get the base
            # prefixBase = "2001:ee0:d788:26c0"
            # newRouteDst = "2001:ee0:d788:26c0:1111::/80"  (1 colon)
            :local slashPos       [:find $curIpv6 "/"]
            :local prefixAddr     [:pick $curIpv6 0 $slashPos]
            :local coloncolonPos  [:find $prefixAddr "::"]
            :local prefixBase     [:pick $prefixAddr 0 $coloncolonPos]
            :local newIpv6RouteDst ($prefixBase . ":" . $ipv6RouteSuffix)

            # Delete old route with the same comment
            :foreach rid in=[/ipv6 route find comment=$ipv6RouteComment] do={
                /ipv6 route remove $rid
            }

            # Add new route
            /ipv6 route add dst-address=$newIpv6RouteDst gateway=$ipv6RouteGateway comment=$ipv6RouteComment
            :log info "WANIP_Monitor [IPv6] Route updated -> $newIpv6RouteDst"

            :set wanIpv6Last $curIpv6
        }
    }
} else={
    :log warning "WANIP_Monitor [IPv6] Pool '$ipv6PoolName' not found or empty — skipping."
}
