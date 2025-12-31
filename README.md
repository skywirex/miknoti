# miknoti — MikroTik Notification Scripts

Send notifications from a **MikroTik RouterOS** device using scripts, with a real-world example of **monitoring server on/off status** (OpenMediaVault) and sending alerts via **Telegram**.

![image](https://pub-b731809282d4443bba205fbf4c8ae4ee.r2.dev/8b9b94b2ade751f2d3839d8520c5e270.png)

---

## 🚀 Overview

**miknoti** is a lightweight collection of RouterOS scripts that enables your MikroTik router to:

* 📩 Send notifications to Telegram, Discord ... 
* 🔍 Monitor server availability (ping-based)
* ⏱ Run checks automatically via Scheduler

The included example monitors the **on/off status of an OpenMediaVault (OMV) server** on a local network and sends notifications when its status changes.

---

## Features

* Telegram notification sender script
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
* Admin access via Winbox, WebFig, or SSH

### 3️⃣ Telegram Bot

* A Telegram bot token
* A chat ID to receive messages

📘 Guide to create Telegram bot & get chat ID:
👉 [Telegram bot & get chat ID](https://skywirex.com/create-telegram-bot-get-chat-id/)

---

## 📦 Repository Structure

| File                      | Description                    |
| ------------------------- | ------------------------------ |
| `TelegramSendMessage.rsc` | Telegram send function         |
| `OMV_Monitor.rsc`         | Example OpenMediaVault monitor |

---

## 🛠️ Installation & Setup

### Step 1️⃣ Create Telegram Send Function Script

1. Go to **System → Scripts → Add New**
2. Set:

   * **Name**: `TelegramSendMessage`
   * **Policies**:
     ✅ read
     ✅ write
     ✅ policy
     ✅ test
3. Copy the content of `TelegramSendMessage.rsc`
4. Replace:

   * `tgBotToken`
   * `tgChatID`
     with your own Telegram details

#### Test in terminal

```routeros
$TelegramSendMessage message="Test message from MikroTik%0ASecond line%0ABold: <b>works</b>"
```

If successful, you will receive a Telegram message immediately.

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

#### Run manually

```routeros
/system script run OMV_Monitor
```

You will receive a Telegram notification if the server state changes.

---

## ⏱️ Automate with Scheduler (Recommended)

Run the monitor every 1 minutes:

```routeros
/system scheduler add \
name=omv-monitor \
interval=1m \
on-event="/system script run OMV_Monitor"
```

The script will only notify when the status **actually changes**, avoiding spam.

---

## (Optional) Wake-on-LAN from MikroTik

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

## 🔌 Integration Ideas

You can reuse `TelegramSendMessage` for:

* Interface up/down alerts
* PPPoE user status
* Security alerts