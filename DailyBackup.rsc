# Script: DailyBackup
# Description: Creates daily backup (.backup) and export (.rsc) files on usb1-part1
# Notes: 
#   - Ensure 'usb1-part1' disk is mounted and accessible.
#   - Handles both RouterOS v6 (dont-encrypt=yes) and v7 (default unencrypted).

:local sysname [/system identity get name]
:local date [/system clock get date]
:local time [/system clock get time]

# Load Notification Functions
:if ([:len [/system script find name=MikNotiMessage]] > 0) do={ /system script run MikNotiMessage }

# SSH / SFTP Configuration
:local sshEnabled false
:local sshAddress "192.168.1.100"
:local sshUser "backup_user"
:local sshPassword "backup_password"
:local sshPort 22
:local sshDstPath "/backups/"

# Parse Date (format: mmm/dd/yyyy)
:local months ("jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec")
:local monthStr [:pick $date 0 3]
:local day [:pick $date 4 6]
:local year [:pick $date 7 11]

# Convert month name to number
:local monthNum ([:find $months $monthStr] + 1)
:if ($monthNum < 10) do={ :set monthStr ("0" . $monthNum) } else={ :set monthStr [:tostr $monthNum] }

# Construct Filename: YYYYMMDD-Identity
:local filename "$year$monthStr$day-$sysname"
:local filepath "usb1-part1/$filename"

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
# Calculate cutoff date
:local cutDay ([:tonum $day] - 5)
:local cutMonth $monthNum
:local cutYear [:tonum $year]

:if ($cutDay <= 0) do={
    :set cutMonth ($cutMonth - 1)
    :if ($cutMonth = 0) do={
        :set cutMonth 12
        :set cutYear ($cutYear - 1)
    }
    :local daysInMonth 31
    :if ($cutMonth = 4 || $cutMonth = 6 || $cutMonth = 9 || $cutMonth = 11) do={ :set daysInMonth 30 }
    :if ($cutMonth = 2) do={
        :set daysInMonth 28
        :if (($cutYear % 4 = 0) && (($cutYear % 100 != 0) || ($cutYear % 400 = 0))) do={ :set daysInMonth 29 }
    }
    :set cutDay ($daysInMonth + $cutDay)
}

# Format cutoff YYYYMMDD
:local cutMonthStr [:tostr $cutMonth]
:if ([:len $cutMonthStr] = 1) do={ :set cutMonthStr ("0" . $cutMonthStr) }
:local cutDayStr [:tostr $cutDay]
:if ([:len $cutDayStr] = 1) do={ :set cutDayStr ("0" . $cutDayStr) }
:local cutoffDateStr "$cutYear$cutMonthStr$cutDayStr"

:log info "Cleaning up backups older than $cutoffDateStr on usb1-part1..."
:foreach i in=[/file find where name~"^usb1-part1/"] do={
    :local fname [/file get $i name]
    :local shortName [:pick $fname ([:len "usb1-part1/"]) [:len $fname]]
    # Check if filename starts with 8 digits (YYYYMMDD)
    :if ([:pick $shortName 0 8] ~ "^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]") do={
        :local fileDateStr [:pick $shortName 0 8]
        :if ($fileDateStr < $cutoffDateStr) do={
            :log info "Deleting old backup: $fname"
            /file remove $i
        }
    }
}

# 5. Send Notification
:global TelegramSendMessage
:global DiscordSendMessage
:local tgMsg ""
:local discordMsg ""

:if ($processError) do={
    :set tgMsg ("Backup <b>FAILED</b>\nDevice: " . $sysname . "\nError: " . $logMessage . "\nTime: " . $date . " " . $time)
    :set discordMsg ("{\"embeds\":[{\"color\":16711680,\"fields\":[{\"name\":\"Backup FAILED\",\"value\":\"Device: " . $sysname . "\\nError: " . $logMessage . "\\nTime: " . $date . " " . $time . "\"}]}]}")
} else={
    :set tgMsg ("Backup <b>SUCCESS</b>\nDevice: " . $sysname . "\nFile: " . $filename . "\nTime: " . $date . " " . $time)
    :set discordMsg ("{\"embeds\":[{\"color\":65280,\"fields\":[{\"name\":\"Backup SUCCESS\",\"value\":\"Device: " . $sysname . "\\nFile: " . $filename . "\\nTime: " . $date . " " . $time . "\"}]}]}")
}

:if ([:typeof $TelegramSendMessage] = "code") do={ $TelegramSendMessage message=$tgMsg }
:if ([:typeof $DiscordSendMessage] = "code") do={ $DiscordSendMessage message=$discordMsg }