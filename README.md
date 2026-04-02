# miknoti — MikroTik Notification Scripts

Send notifications from a **MikroTik RouterOS** device using scripts, with a real-world example of **monitoring server on/off status** (OpenMediaVault) and sending alerts via **Telegram** or **Discord**.

| Telegram Notification                                                                              | Discord Notification                                                                               |
| -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| ![image](https://pub-b731809282d4443bba205fbf4c8ae4ee.r2.dev/8b9b94b2ade751f2d3839d8520c5e270.png) | ![image](https://pub-b731809282d4443bba205fbf4c8ae4ee.r2.dev/6e9911cec007f9b280019a999511d966.png) |

---

## 🚀 Overview

**miknoti** is a collection of RouterOS scripts that enables your MikroTik router to:

* 📩 Send notifications to Telegram and Discord
* 🔍 Monitor server availability (ping-based)
* 🔄 Automate DNS failover for redundancy
* 💾 Perform daily backups with retention and SFTP upload
* 🌐 Monitor WAN IP changes (IPv4/IPv6) and update routes
* ⏱ Run checks automatically via Scheduler

The included examples cover monitoring server status (e.g., OpenMediaVault), ensuring DNS reliability, securing configuration backups off-site, and tracking WAN IP changes.

---

## Features

*   Telegram and Discord notification sender scripts
*   Server availability monitoring (ping / ICMP)
*   Status-change detection (UP → DOWN, DOWN → UP) to prevent alert spam
*   Automatic DNS failover monitoring with notifications
*   Daily automated backups (binary `.backup` and script `.rsc`)
*   SFTP upload for off-site backup storage
*   Local backup retention policy to manage disk space
*   WAN IP monitoring (IPv4 and IPv6) with change notifications and automatic route updates
*   Pure RouterOS scripting — no external dependencies

---

## Prerequisites

### 1️⃣ OpenMediaVault (or any server)

* Must have a **static IP address**
* Must respond to **ICMP ping** when online
* Firewall allows echo reply

### 2️⃣ MikroTik Router

* Running **RouterOS**
* Admin access via Winbox, or SSH

### 3️⃣ Telegram Bot

* A Telegram bot token
* A chat ID to receive messages

📘 Guide to create Telegram bot & get chat ID:
👉 [Telegram bot & get chat ID](https://skywirex.com/create-telegram-bot-get-chat-id/)

### 4️⃣ Discord Webhook (Optional)

* A Discord server with admin access
* A Discord channel webhook URL

#### How to Create a Discord Webhook:

1. **Channel Settings** → **Integrations**
2. Click **Create Webhook**
3. Name the webhook (e.g., "RouterOS Notifications")
4. **Copy Webhook URL**
5. Paste the URL in `MikNotiMessage.rsc` → `discordWebhookUrl`

---

## 📦 Repository Structure

| File                      | Description                    |
| ------------------------- | ------------------------------ |
| `MikNotiMessage.rsc`      | Telegram & Discord send functions |
| `OMV_Monitor.rsc`         | Example OpenMediaVault monitor |
| `DNS_Failover.rsc`        | Automatic DNS failover monitor |
| `DailyBackup.rsc`         | Daily backup with SFTP & Retention |
| `WANIP_Monitor.rsc`       | Monitor WAN IPv4/IPv6 changes and update routes |

---

## 🛠️ Installation & Setup

### Step 1️⃣ Create Message Function Script

1. Go to **System → Scripts → Add New**
2. Set:

   * **Name**: `MikNotiMessage`
   * **Policies**:
     ✅ read
     ✅ write
     ✅ policy
     ✅ test
3. Copy the content of `MikNotiMessage.rsc`
4. Replace:

   * `tgBotToken`
   * `tgChatID`
   
   with your own Telegram details

#### Test Telegram in terminal

```routeros
$TelegramSendMessage message="Test message from MikroTik"
```

If successful, you will receive a Telegram message immediately.

#### Test Discord (if configured)

```routeros
$DiscordSendMessage message="Test message from MikroTik"
```

If successful, you will receive a Discord message in the configured channel.

---

### Step 2️⃣ Create OpenMediaVault Monitor Script

1. Go to **System → Scripts → Add New**
2. Set:

   * **Name**: `OMV_Monitor`
   * **Policies**:
     ✅ read
     ✅ write
     ✅ policy
     ✅ test
3. Copy the content of `OMV_Monitor.rsc`
4. Edit the script and set:

   ```routeros
   :local omvIp "172.16.0.10"
   ```

> **ℹ️ Note**: Discord notifications are **disabled by default**. To enable Discord notifications, uncomment the lines that create `$embedPayload`, `$discordMsg`, and the `$DiscordSendMessage` function call in the script.

#### Run manually

```routeros
/system script run OMV_Monitor
```

You will receive a Telegram notification if the server state changes.

---

## ⏱️ Automate with Scheduler

Run the monitor every 1 minute:

```routeros
/system scheduler add \
name=omv-monitor \
interval=1m \
on-event="/system script run OMV_Monitor"
```

The script will only notify when the status **actually changes**, avoiding spam.

---

## 🔄 DNS Failover Monitor

Automatically switches between your **private DNS** and **Google DNS** based on connectivity.

### Features

* Monitors private DNS server availability via ping
* Automatically switches to Google DNS (8.8.8.8 / 8.8.4.4) if private DNS is unreachable
* Switches back to private DNS when it becomes available again
* Sends Telegram/Discord notifications on DNS switchover
* Tracks DNS status and failover time

### Step 3️⃣ Create DNS Failover Script

1. Go to **System → Scripts → Add New**
2. Set:

   * **Name**: `DNS_Failover`
   * **Policies**:
     ✅ read
     ✅ write
     ✅ policy
     ✅ test
3. Copy the content of `DNS_Failover.rsc`
4. Edit the script and set:

   ```routeros
   :local privateDnsIp "8.8.8.8"     # Replace with your private DNS server IP
   ```

> **ℹ️ Note**: The default primary DNS is set to 8.8.8.8. Replace this with your actual private DNS server IP address (e.g., 192.168.1.1, 10.0.0.1, etc.)

#### Run manually

```routeros
/system script run DNS_Failover
```

You will receive a Telegram notification if a DNS switchover occurs.

---

## ⏱️ Automate DNS Failover with Scheduler

Run the DNS monitor every 1 minute:

```routeros
/system scheduler add \
name=dns-failover \
interval=1m \
on-event="/system script run DNS_Failover"
```

The script will only notify when DNS status **actually changes**, avoiding spam.

---

## 💾 Daily Backup Script

Creates daily backups, manages retention, and optionally uploads to SFTP.

### Features

* **Dual Backup**: Creates both binary (`.backup`) and script (`.rsc`) exports.
* **Smart Naming**: Files are named `YYYYMMDD-Identity`.
* **Retention Policy**: Automatically deletes local backups older than 5 days on `usb1-part1`.
* **SFTP Upload**: Optional secure upload to a remote server.
* **Notifications**: Sends status reports via Telegram/Discord.

### Step 4️⃣ Create Daily Backup Script

1. Go to **System → Scripts → Add New**
2. Set:
   * **Name**: `DailyBackup`
   * **Policies**:
     ✅ read
     ✅ write
     ✅ policy
     ✅ test
     ✅ sensitive (required if storing SSH passwords)
3. Copy the content of `DailyBackup.rsc`
4. **Configuration**:
   Edit the top section to configure the backup path and enable SSH/SFTP if desired:

   ```routeros
   :local sshEnabled true          # Set to true to enable SFTP upload
   :local sshAddress "192.168.1.100"
   :local backupPath "usb1-part1"  # Change to your USB disk name
   :local sshUser "backup_user"
   :local sshPassword "your_password"
   ```

> **ℹ️ Note**: If using **Hetzner Storage Box** for SFTP, use **port 22**, not port 23 as indicated in the Hetzner documents.

> **ℹ️ Note**: Discord notifications are **disabled by default**. To enable them, uncomment the `$DiscordSendMessage` line at the bottom of the script.

### ⏱️ Automate Backup with Scheduler

Run the backup every day at 3:00 AM:

```routeros
/system scheduler add \
name=daily-backup \
start-time=03:00:00 \
interval=1d \
on-event="/system script run DailyBackup"
```

---

## 🌐 WAN IP Monitor Script

Monitors changes to your WAN IPv4 address and IPv6 prefix, sending notifications and automatically updating your IPv6 routes when the prefix changes.

### Features

* **IPv4 Monitoring**: Detects changes on your WAN interface.
* **IPv6 Monitoring**: Detects prefix changes from your DHCPv6 client pool.
* **Dynamic Route Update**: Automatically updates static IPv6 routes based on the new prefix.
* **Notifications**: Sends status reports via Telegram/Discord.

### Step 5️⃣ Create WAN IP Monitor Script

1. Go to **System → Scripts → Add New**
2. Set:
   * **Name**: `WANIP_Monitor`
   * **Policies**:
     ✅ read
     ✅ write
     ✅ policy
     ✅ test
3. Copy the content of `WANIP_Monitor.rsc`
4. **Configuration**:
   Edit the top section to configure your interfaces and IPv6 route settings:

   ```routeros
   :global wanInterface     "pppoe-out1"
   :global ipv6PoolName     "ipv6-pool-vnpt"
   :global ipv6RouteSuffix  "1111::/80"
   :global ipv6RouteGateway "fe80::f3d1:71a:a23f:8f1c%bridgeLAN"
   :global ipv6RouteComment "IP6_ROUTE"
   ```

### ⏱️ Automate WAN IP Monitor with Scheduler

Run the monitor every 5 minutes:

```routeros
/system scheduler add \
name=wanip-monitor \
interval=5m \
on-event="/system script run WANIP_Monitor"
```

---

## **power ON** the server remotely using Wake-on-LAN.

### Steps:

1. Check **ARP table** in MikroTik to get:

   * MAC address
   * Interface
2. Use Wake-on-LAN:

```routeros
/tool wol mac=AA:BB:CC:DD:EE:FF interface=bridgeLAN
```

![image](https://pub-b731809282d4443bba205fbf4c8ae4ee.r2.dev/dda861f6b242d53735f4736debf46783.png)

---

## To Do

* ......