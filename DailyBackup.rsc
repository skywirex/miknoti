# Script: DailyBackup
# Description: Creates daily backup (.backup) and export (.rsc) files on usb1-part1
# Notes: 
#   - Ensure 'usb1-part1' disk is mounted and accessible.
#   - Handles both RouterOS v6 (dont-encrypt=yes) and v7 (default unencrypted).

:local sysname [/system identity get name]
:local serialNumber [/system routerboard get serial-number]
:local date [/system clock get date]
:local time [/system clock get time]

# ===== GLOBAL VARIABLES =====
:global TelegramSendMessage
:global DiscordSendMessage
/system script run MikNotiMessage

# ===== Local Backup Configuration =====
:local backupPath "usb1-part1"

# ===== SSH / SFTP Configuration =====
:local sshEnabled false
:local sshAddress "192.168.1.100"
:local sshUser "backup_user"
:local sshPassword "backup_password"
:local sshPort 22
:local sshDstPath "/backups/"

# Parse Date (format: mmm/dd/yyyy)
:local year
:local monthStr
:local day
:local monthNum

# Handle different date formats (MMM/DD/YYYY or YYYY-MM-DD)
:if ([:pick $date 4 5] = "-") do={
    :set year [:pick $date 0 4]
    :set monthStr [:pick $date 5 7]
    :set day [:pick $date 8 10]
    :set monthNum [:tonum $monthStr]
} else={
    :set monthStr [:pick $date 0 3]
    :set day [:pick $date 4 6]
    :set year [:pick $date 7 11]
    :local months ("jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")
    :set monthNum (([:find $months $monthStr] % 12) + 1)
    :if ($monthNum < 10) do={ :set monthStr ("0" . $monthNum) } else={ :set monthStr [:tostr $monthNum] }
}
# Ensure day is 2 digits
:if ([:tonum $day] < 10) do={ :set day ("0" . [:tonum $day]) }

# Construct Filename: YYYYMMDD-Identity-SerialNumber
:local filename "$year$monthStr$day-$sysname-$serialNumber"
:if ([:pick $backupPath ([:len $backupPath]-1) [:len $backupPath]] = "/") do={ :set backupPath [:pick $backupPath 0 ([:len $backupPath]-1)] }
:local filepath "$backupPath/$filename"

# Status tracking
:local processError false
:local logMessage ""

# 1. Binary Backup (.backup)
:do {
    /system backup save name=$filepath dont-encrypt=yes
} on-error={
    :do {
        /system backup save name=$filepath
    } on-error={
        :set processError true
        :set logMessage ($logMessage . "\nBinary backup failed.")
    }
}

# 2. Configuration Export (.rsc)
:do {
    /export file=$filepath
} on-error={
    :set processError true
    :set logMessage ($logMessage . "\nConfig export failed.")
}

# 3. Upload via SSH (SFTP)
:if ($sshEnabled) do={
    :log info "Uploading backups via SFTP..."
    :do {
        /tool fetch mode=sftp address=$sshAddress port=$sshPort user=$sshUser password=$sshPassword src-path=("$filepath" . ".backup") upload=yes dst-path=($sshDstPath . $filename . ".backup")
        /tool fetch mode=sftp address=$sshAddress port=$sshPort user=$sshUser password=$sshPassword src-path=("$filepath" . ".rsc") upload=yes dst-path=($sshDstPath . $filename . ".rsc")
        :log info "Backup upload successful."
    } on-error={
        :log error "Backup upload failed."
        :set processError true
        :set logMessage ($logMessage . "\nSFTP upload failed.")
    }
}

# 4. Retention Policy: Delete files older than 5 days
:if ([:len [/file find name=($filepath . ".backup")]] > 0) do={
    # Calculate cutoff date
    :local cutDay ([:tonum $day] - 5)
    :local cutMonth $monthNum
    :local cutYear [:tonum $year]

    :if ($cutDay <= 0) do={
        :set cutMonth ($cutMonth - 1)
        :if ($cutMonth = 0) do={ :set cutMonth 12; :set cutYear ($cutYear - 1) }
        :local dim 31
        :if ($cutMonth = 4 || $cutMonth = 6 || $cutMonth = 9 || $cutMonth = 11) do={ :set dim 30 }
        :if ($cutMonth = 2) do={ :set dim 28; :if ($cutYear % 4 = 0) do={ :set dim 29 } }
        :set cutDay ($dim + $cutDay)
    }

    # Format cutoff YYYYMMDD
    :local cutMonthStr [:tostr $cutMonth]
    :if ([:len $cutMonthStr] = 1) do={ :set cutMonthStr ("0" . $cutMonthStr) }
    :local cutDayStr [:tostr $cutDay]
    :if ([:len $cutDayStr] = 1) do={ :set cutDayStr ("0" . $cutDayStr) }
    :local cutoffDateStr "$cutYear$cutMonthStr$cutDayStr"

    :log info "Cleaning up backups older than $cutoffDateStr on $backupPath/..."
    :foreach i in=[/file find where name~("^" . $backupPath . "/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-.*") and (name~"\\.backup\$" or name~"\\.rsc\$")] do={
        :local fname [/file get $i name]
        :local fileDateStr [:pick $fname ([:len $backupPath] + 1) ([:len $backupPath] + 9)]
        :if ($fileDateStr < $cutoffDateStr) do={
            :log info ("Deleting old backup: " . [:pick $fname ([:len $backupPath] + 1) [:len $fname]])
            /file remove $i
        }
    }
} else={
    :log warning "Backup file not found. Skipping retention cleanup."
}

# 5. Send Notification
:local tgMsg ""
:local discordMsg ""

:if ($processError) do={
    :set tgMsg ("Backup <b>FAILED</b>\nDevice: " . $sysname . "\nError: " . $logMessage . "\nTime: " . $date . " " . $time)
    :set discordMsg ("{\"embeds\":[{\"color\":16711680,\"fields\":[{\"name\":\"Backup FAILED\",\"value\":\"Device: " . $sysname . "\\nError: " . $logMessage . "\\nTime: " . $date . " " . $time . "\"}]}]}")
} else={
    :set tgMsg ("Backup <b>SUCCESS</b>\nDevice: " . $sysname . "\nFile: " . $filename . "\nTime: " . $date . " " . $time)
    :set discordMsg ("{\"embeds\":[{\"color\":65280,\"fields\":[{\"name\":\"Backup SUCCESS\",\"value\":\"Device: " . $sysname . "\\nFile: " . $filename . "\\nTime: " . $date . " " . $time . "\"}]}]}")
}

$TelegramSendMessage message=$tgMsg
#$DiscordSendMessage message=$discordMsg