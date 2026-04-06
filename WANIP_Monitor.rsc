# =====Script Name: WANIP_Monitor=====
# =====Monitoring WAN IP Status of Internet Line=====
# =====Persist: last-known IPs stored in comment of this script=====
# =====Comment format: ipv4=x.x.x.x;ipv6=xxxx::/60             =====
:global TelegramSendMessage
:global DiscordSendMessage
/system script run MikNotiMessage

# ===== CONFIG ==============================================================================================
:global wanInterface     "pppoe-out1"
:global ipv6PoolName     "ipv6-pool-vnpt"
:global ipv6RouteGateway "fe80::e3ff:feea:7e29%bridgeLAN"
# ===== END CONFIG ===========================================================================================

:global wanIpv4Last
:global wanIpv6Last

# Ensure it's always a string, to avoid type errors when concatenating
:if ([:typeof $wanIpv4Last] = "nothing") do={ :set wanIpv4Last "" }
:if ([:typeof $wanIpv6Last] = "nothing") do={ :set wanIpv6Last "" }

# =============================================================
# RESTORE persisted IPs from comment of this script
# Comment format:  ipv4=1.2.3.4;ipv6=2001:ee0:d788::/60
# =============================================================
:local selfId [/system script find name="WANIP_Monitor"]
:local scriptComment [/system script get $selfId comment]

:if ([:typeof $scriptComment] != "nothing" && $scriptComment != "") do={
    # --- parse ipv4=... ---
    :local p4 [:find $scriptComment "ipv4="]
    :if ([:typeof $p4] != "nothing") do={
        :local rest [:pick $scriptComment ($p4 + 5) [:len $scriptComment]]
        :local semi [:find $rest ";"]
        :if ([:typeof $semi] != "nothing") do={
            :set wanIpv4Last [:pick $rest 0 $semi]
        } else={
            :set wanIpv4Last $rest
        }
    }
    # --- parse ipv6=... ---
    :local p6 [:find $scriptComment "ipv6="]
    :if ([:typeof $p6] != "nothing") do={
        :set wanIpv6Last [:pick $scriptComment ($p6 + 5) [:len $scriptComment]]
    }
}

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
    :if ($wanIpv4Last = "") do={
        :set wanIpv4Last $curIpv4
        :log info "WANIP_Monitor [IPv4] Initialized: $curIpv4"
    } else={
        :if ($curIpv4 != $wanIpv4Last) do={
            :log info "WANIP_Monitor [IPv4] Changed: $wanIpv4Last -> $curIpv4"
            $TelegramSendMessage message=("WAN IPv4 Changed\nOld IP: <b>" . $wanIpv4Last . "</b>\nNew IP: <b>" . $curIpv4 . "</b>\nTime: " . $now)
            $DiscordSendMessage  message=("{\"embeds\":[{\"fields\":[{\"name\":\"WAN IPv4 Changed\",\"value\":\"Old: " . $wanIpv4Last . "\\nNew: " . $curIpv4 . "\\nTime: " . $now . "\"}]}]}")
            :set wanIpv4Last $curIpv4
        }
    }
}

# =============================================================
# IPv6 CHECK
# =============================================================
:local curIpv6 ""
:local ipv6RouteSuffix  "1111::/80"
:local ipv6RouteComment "IP6_ROUTE"

:local poolIds [/ipv6 pool find name=$ipv6PoolName]
:if ([:len $poolIds] > 0) do={
    :local raw [/ipv6 pool get ($poolIds->0) prefix]
    :if ([:typeof $raw] != "nothing" && $raw != "") do={
        :set curIpv6 $raw
    }
}

:if ($curIpv6 != "") do={
    :if ($wanIpv6Last = "") do={
        :set wanIpv6Last $curIpv6
        :log info "WANIP_Monitor [IPv6] Initialized: $curIpv6"
    } else={
        :if ($curIpv6 != $wanIpv6Last) do={
            :log info "WANIP_Monitor [IPv6] Changed: $wanIpv6Last -> $curIpv6"
            $TelegramSendMessage message=("WAN IPv6 Prefix Changed\nOld Prefix: <b>" . $wanIpv6Last . "</b>\nNew Prefix: <b>" . $curIpv6 . "</b>\nTime: " . $now)
            $DiscordSendMessage  message=("{\"embeds\":[{\"fields\":[{\"name\":\"WAN IPv6 Prefix Changed\",\"value\":\"Old: " . $wanIpv6Last . "\\nNew: " . $curIpv6 . "\\nTime: " . $now . "\"}]}]}")

            # --- Update static IPv6 route ---
            :local slashPos      [:find $curIpv6 "/"]
            :local prefixAddr    [:pick $curIpv6 0 $slashPos]
            :local coloncolonPos [:find $prefixAddr "::"]
            :local prefixBase    [:pick $prefixAddr 0 $coloncolonPos]
            :local newIpv6RouteDst ($prefixBase . ":" . $ipv6RouteSuffix)

            :foreach rid in=[/ipv6 route find comment=$ipv6RouteComment] do={
                /ipv6 route remove $rid
            }
            /ipv6 route add dst-address=$newIpv6RouteDst gateway=$ipv6RouteGateway comment=$ipv6RouteComment
            :log info "WANIP_Monitor [IPv6] Route updated -> $newIpv6RouteDst"

            :set wanIpv6Last $curIpv6
        }
    }
}

# =============================================================
# PERSIST — only write comment when IP has changed
# =============================================================
:local newComment ("ipv4=" . $wanIpv4Last . ";ipv6=" . $wanIpv6Last)
:if ($newComment != $scriptComment) do={
    /system script set $selfId comment=$newComment
    :log info "WANIP_Monitor [Persist] Saved: ipv4=$wanIpv4Last ipv6=$wanIpv6Last"
}