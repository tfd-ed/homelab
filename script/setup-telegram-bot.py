#!/usr/bin/env python3
"""
setup-telegram-bot.py
Register commands, set descriptions, and send branded welcome/info messages
for the Homelab Aggregate Telegram Bot.

Workflow: Telegram Trigger → PVE Status + PVE RAW Temp + PVE Disk Usage
          → Merge → Aggregate (JS) → Ollama TinyLlama → Send Telegram Reply

Usage:
    python3 setup-telegram-bot.py --token <BOT_TOKEN>              # setup only
    python3 setup-telegram-bot.py --token <BOT_TOKEN> --welcome <CHAT_ID>
    python3 setup-telegram-bot.py --token <BOT_TOKEN> --info <CHAT_ID>
    # or set TELEGRAM_BOT_TOKEN env var
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

# ---------------------------------------------------------------------------
# Bot commands (visible in Telegram's / menu)
# ---------------------------------------------------------------------------
COMMANDS = [
    ("start",  "Welcome message & help"),
    ("help",   "Show all available commands"),
    ("status", "Full Proxmox status: CPU, RAM, disk, temperatures"),
]

# ---------------------------------------------------------------------------
# Inline keyboard buttons — each triggers the aggregate workflow via n8n
# Format: (message text sent to n8n, button label)
# ---------------------------------------------------------------------------
QUICK_QUESTIONS = [
    ("status", "📊 Full status report"),
]

# ---------------------------------------------------------------------------
# Static info cards sent by --info  (title, body_text)
# ---------------------------------------------------------------------------
INFO_CARDS = [
    (
        "🖥️  Hardware",
        (
            "Model: GMKTec NucBox M5 Ultra\n"
            "CPU:   AMD Ryzen 7 7730U  (8C/16T, up to 4.5 GHz)\n"
            "RAM:   64 GB DDR4\n"
            "SSD:   1 TB NVMe\n"
            "OS:    Proxmox VE 9.1"
        ),
    ),
    (
        "🌐  Network",
        (
            "192.168.100.50   — Proxmox host\n"
            "192.168.100.230  — n8n (workflow engine)\n"
            "192.168.100.250  — Ollama (TinyLlama inference)"
        ),
    ),
    (
        "🛠️  Useful links",
        (
            "Proxmox: https://192.168.100.50:8006\n"
            "n8n:     http://192.168.100.230:5678"
        ),
    ),
]

BOT_DESCRIPTION = (
    "Proxmox aggregate monitor powered by TinyLlama. "
    "Send any message to get a live status report: CPU, RAM, disk usage, "
    "temperatures, and an AI-generated health note."
)
BOT_SHORT_DESCRIPTION = "Proxmox status reporter with AI health note"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def api(token: str, method: str, payload: dict) -> dict:
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  HTTP {e.code}: {body}", file=sys.stderr)
        return {"ok": False, "description": body}


def build_quick_keyboard() -> list:
    """Build 2-column inline keyboard from QUICK_QUESTIONS."""
    rows = []
    for i in range(0, len(QUICK_QUESTIONS), 2):
        row = []
        for cb_data, label in QUICK_QUESTIONS[i:i+2]:
            row.append({"text": label, "callback_data": cb_data})
        rows.append(row)
    return rows


def send_message(token: str, chat_id: str, text: str,
                 keyboard: list | None = None, parse_mode: str = "Markdown") -> bool:
    payload: dict = {"chat_id": chat_id, "text": text, "parse_mode": parse_mode}
    if keyboard:
        payload["reply_markup"] = {"inline_keyboard": keyboard}
    result = api(token, "sendMessage", payload)
    ok = result.get("ok", False)
    if not ok:
        print(f"  ✗ sendMessage failed: {result.get('description')}", file=sys.stderr)
    return ok


# ---------------------------------------------------------------------------
# Setup functions
# ---------------------------------------------------------------------------

def set_commands(token: str):
    print("Setting bot commands...")
    commands = [{"command": cmd, "description": desc} for cmd, desc in COMMANDS]
    result = api(token, "setMyCommands", {"commands": commands})
    if result.get("ok"):
        print(f"  ✓ {len(commands)} commands registered")
    else:
        print(f"  ✗ Failed: {result.get('description')}")


def set_description(token: str):
    print("Setting bot description...")
    r1 = api(token, "setMyDescription",      {"description": BOT_DESCRIPTION})
    r2 = api(token, "setMyShortDescription", {"short_description": BOT_SHORT_DESCRIPTION})
    print(f"  {'✓' if r1.get('ok') else '✗'} Description")
    print(f"  {'✓' if r2.get('ok') else '✗'} Short description")


def get_info(token: str):
    print("Bot info:")
    result = api(token, "getMe", {})
    if result.get("ok"):
        bot = result["result"]
        print(f"  Name    : {bot.get('first_name')}")
        print(f"  Username: @{bot.get('username')}")
        print(f"  ID      : {bot.get('id')}")
    else:
        print(f"  ✗ {result.get('description')}")


def set_webhook(token: str, webhook_url: str):
    print(f"Setting webhook to {webhook_url}...")
    result = api(token, "setWebhook", {"url": webhook_url, "drop_pending_updates": True})
    print(f"  {'✓ Webhook registered' if result.get('ok') else '✗ ' + result.get('description', '')}")


def delete_webhook(token: str):
    print("Deleting webhook...")
    result = api(token, "deleteWebhook", {"drop_pending_updates": False})
    print(f"  {'✓ Webhook deleted' if result.get('ok') else '✗ ' + result.get('description', '')}")


# ---------------------------------------------------------------------------
# Message functions
# ---------------------------------------------------------------------------

def send_welcome(token: str, chat_id: str):
    """
    Send the welcome card with a description and the full quick-question keyboard.
    Trigger this manually, or route /start and /help through it in n8n.
    """
    print(f"Sending welcome message to {chat_id}...")

    text = (
        "👋 *Homelab Monitor*\n\n"
        "I fetch live *Proxmox* metrics and generate a health report using "
        "*TinyLlama* running locally.\n\n"
        "💡 *What I report:*\n"
        "• CPU, RAM, and root disk usage (OK / WARN / CRIT)\n"
        "• CPU, GPU, and NVMe temperatures\n"
        "• Storage pool usage\n"
        "• AI-generated one-line health note\n\n"
        "*Send any message or tap below to get a status report:*"
    )

    ok = send_message(token, chat_id, text, keyboard=build_quick_keyboard())
    print(f"  {'✓ Sent' if ok else '✗ Failed'}")


def send_info(token: str, chat_id: str):
    """
    Send each static info card as a separate message, the last one
    gets the quick-question keyboard attached.
    """
    print(f"Sending info cards to {chat_id}...")

    # Header
    send_message(token, chat_id,
                 "ℹ️ *Homelab quick reference*\n"
                 "Here is everything you need to know about this server:")

    for i, (title, body) in enumerate(INFO_CARDS):
        is_last = i == len(INFO_CARDS) - 1
        text = f"*{title}*\n\n`{body}`"
        keyboard = build_quick_keyboard() if is_last else None
        ok = send_message(token, chat_id, text, keyboard=keyboard)
        print(f"  {'✓' if ok else '✗'} {title}")


def send_help(token: str, chat_id: str):
    """Send the command list with the quick keyboard."""
    print(f"Sending help message to {chat_id}...")

    lines = ["*Available commands:*\n"]
    for cmd, desc in COMMANDS:
        lines.append(f"/{cmd} — {desc}")

    lines += [
        "",
        "Or send any message — it will trigger a live Proxmox status report.",
        "Tap the button below for an instant snapshot:",
    ]

    ok = send_message(token, chat_id, "\n".join(lines), keyboard=build_quick_keyboard())
    print(f"  {'✓ Sent' if ok else '✗ Failed'}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Configure the Homelab AI Telegram bot")
    parser.add_argument("--token",       default=os.environ.get("TELEGRAM_BOT_TOKEN"),
                        help="Bot token (or set TELEGRAM_BOT_TOKEN env var)")
    parser.add_argument("--webhook",     metavar="URL",
                        help="Register this URL as the bot webhook (your n8n trigger URL)")
    parser.add_argument("--del-webhook", action="store_true",
                        help="Remove the webhook")
    parser.add_argument("--welcome",     metavar="CHAT_ID",
                        help="Send welcome message with keyboard to CHAT_ID")
    parser.add_argument("--info",        metavar="CHAT_ID",
                        help="Send static info cards to CHAT_ID")
    parser.add_argument("--help-msg",    metavar="CHAT_ID",
                        help="Send help/command list to CHAT_ID")
    parser.add_argument("--info-only",   action="store_true",
                        help="Skip command/description setup, only send messages")
    args = parser.parse_args()

    if not args.token:
        print("Error: provide --token or set TELEGRAM_BOT_TOKEN", file=sys.stderr)
        sys.exit(1)

    get_info(args.token)
    print()

    if not args.info_only:
        set_commands(args.token)
        set_description(args.token)
        print()

    if args.webhook:
        set_webhook(args.token, args.webhook)

    if args.del_webhook:
        delete_webhook(args.token)

    if args.welcome:
        send_welcome(args.token, args.welcome)

    if args.info:
        send_info(args.token, args.info)

    if args.help_msg:
        send_help(args.token, args.help_msg)

    print("\nDone.")


if __name__ == "__main__":
    main()
