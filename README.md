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
* ⏱ Run checks automatically via Scheduler

The included examples monitor the **on/off status of an OpenMediaVault (OMV) server** on a local network and send notifications when status changes. Optional DNS failover monitoring is also available.

---

## Features

* Telegram notification sender script
* Discord notification sender script
* Server availability monitoring (ping / ICMP)
* Status-change detection (UP → DOWN, DOWN → UP)
* Pure RouterOS scripting — no external dependencies

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

You can also **power ON** the server remotely using Wake-on-LAN.

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

* Notifications for ntfy