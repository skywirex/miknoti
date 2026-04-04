# =====Script Name: WANIP_Monitor=====
# =====Monitoring WAN IP Status of Internet Line=====
# =====Supports reboot: persists last-known IPs via /system script source=====
:global TelegramSendMessage
:global DiscordSendMessage
/system script run MikNotiMessage

# ===== CONFIG ==============================================================================================
:global wanInterface     "pppoe-out1"
:global ipv6PoolName     "ipv6-pool-vnpt"
:global ipv6RouteGateway "fe80::e3ff:feea:7e29%pppoe-out1"
# ===== END CONFIG ===========================================================================================

# =====  PERSIST HELPERS  ===========================================================================================
# Last-known IPs are stored inside two tiny scripts:
#   "WANIP_Store_IPv4"  →  source contains exactly one line:  :global wanIpv4Last "x.x.x.x"
#   "WANIP_Store_IPv6"  →  source contains exactly one line:  :global wanIpv6Last "xxxx::/60"
# These scripts survive reboot; running them restores the globals.
# ===================================================================================================================

:global wanIpv4Last
:global wanIpv6Last

# ---- Restore persisted values (no-op on first-ever run) ----
:if ([:len [/system script find name="WANIP_Store_IPv4"]] > 0) do={
    /system script run WANIP_Store_IPv4
}
:if ([:len [/system script find name="WANIP_Store_IPv6"]] > 0) do={
    /system script run WANIP_Store_IPv6
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
    :if ([:typeof $wanIpv4Last] = "nothing" || $wanIpv4Last = "") do={
        # First run ever (no store script yet) — just persist current IP, no alert
        :set wanIpv4Last $curIpv4
        :log info "WANIP_Monitor [IPv4] Initialized (first run): $curIpv4"
    } else={
        :if ($curIpv4 != $wanIpv4Last) do={
            :log info "WANIP_Monitor [IPv4] Changed: $wanIpv4Last -> $curIpv4"
            $TelegramSendMessage message=("WAN IPv4 Changed\nOld IP: <b>" . $wanIpv4Last . "</b>\nNew IP: <b>" . $curIpv4 . "</b>\nTime: " . $now)
            $DiscordSendMessage  message=("{\"embeds\":[{\"fields\":[{\"name\":\"WAN IPv4 Changed\",\"value\":\"Old: " . $wanIpv4Last . "\\nNew: " . $curIpv4 . "\\nTime: " . $now . "\"}]}]}")
            :set wanIpv4Last $curIpv4
        }
    }

    # ---- Persist current IPv4 ----
    :local src4 (":global wanIpv4Last \"" . $wanIpv4Last . "\"")
    :if ([:len [/system script find name="WANIP_Store_IPv4"]] = 0) do={
        /system script add name="WANIP_Store_IPv4" source=$src4
    } else={
        /system script set [/system script find name="WANIP_Store_IPv4"] source=$src4
    }

} else={
    :log debug "WANIP_Monitor [IPv4] No address on $wanInterface — skipping."
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
    :if ([:typeof $wanIpv6Last] = "nothing" || $wanIpv6Last = "") do={
        # First run ever — just persist, no alert
        :set wanIpv6Last $curIpv6
        :log info "WANIP_Monitor [IPv6] Initialized (first run): $curIpv6"
    } else={
        :if ($curIpv6 != $wanIpv6Last) do={
            :log info "WANIP_Monitor [IPv6] Changed: $wanIpv6Last -> $curIpv6"
            $TelegramSendMessage message=("WAN IPv6 Prefix Changed\nOld Prefix: <b>" . $wanIpv6Last . "</b>\nNew Prefix: <b>" . $curIpv6 . "</b>\nTime: " . $now)
            $DiscordSendMessage  message=("{\"embeds\":[{\"fields\":[{\"name\":\"WAN IPv6 Prefix Changed\",\"value\":\"Old: " . $wanIpv6Last . "\\nNew: " . $curIpv6 . "\\nTime: " . $now . "\"}]}]}")

            # --- Update static IPv6 route ---
            :local slashPos       [:find $curIpv6 "/"]
            :local prefixAddr     [:pick $curIpv6 0 $slashPos]
            :local coloncolonPos  [:find $prefixAddr "::"]
            :local prefixBase     [:pick $prefixAddr 0 $coloncolonPos]
            :local newIpv6RouteDst ($prefixBase . ":" . $ipv6RouteSuffix)

            :foreach rid in=[/ipv6 route find comment=$ipv6RouteComment] do={
                /ipv6 route remove $rid
            }
            /ipv6 route add dst-address=$newIpv6RouteDst gateway=$ipv6RouteGateway comment=$ipv6RouteComment
            :log info "WANIP_Monitor [IPv6] Route updated -> $newIpv6RouteDst"

            :set wanIpv6Last $curIpv6
        }
    }

    # ---- Persist current IPv6 ----
    :local src6 (":global wanIpv6Last \"" . $wanIpv6Last . "\"")
    :if ([:len [/system script find name="WANIP_Store_IPv6"]] = 0) do={
        /system script add name="WANIP_Store_IPv6" source=$src6
    } else={
        /system script set [/system script find name="WANIP_Store_IPv6"] source=$src6
    }

} else={
    :log warning "WANIP_Monitor [IPv6] Pool '$ipv6PoolName' not found or empty — skipping."
}
