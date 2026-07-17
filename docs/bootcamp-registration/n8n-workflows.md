# n8n Workflow Designs

All workflows are triggered via n8n webhooks. The Express.js backend calls these webhooks after performing its own validation and DB writes, keeping n8n focused on automation (notifications, storage sync, assignment logic).

---

## Workflow 1 — Google Authentication Validation

**Trigger:** Webhook POST `/n8n/auth-validated`  
**Called by:** Backend after successful Google OAuth callback  
**Purpose:** Log authenticated sessions, detect first-time users vs returning

```
[Webhook] ─► [Check MongoDB: user exists?]
                  │                │
               New User        Existing User
                  │                │
         [Create User Record]  [Update lastLogin]
                  │                │
                  └───────┬────────┘
                          ▼
                  [Respond: { isNew, userId }]
```

### Input Payload
```json
{
  "googleId": "1098234...",
  "email": "user@gmail.com",
  "name": "Dara Chan",
  "picture": "https://lh3.googleusercontent.com/..."
}
```

### Output
```json
{
  "isNew": true,
  "userId": "664abc...",
  "alreadyRegistered": false
}
```

---

## Workflow 2 — Registration Submission

**Trigger:** Webhook POST `/n8n/registration`  
**Called by:** Backend after saving registration to MongoDB  
**Purpose:** Orchestrate post-submission actions

```
[Webhook]
    │
    ▼
[Set Variables: courseType, email, name]
    │
    ▼
[IF courseType == "video"]
  ├── TRUE ──► [Assign Video Telegram Group Link]
  └── FALSE ─► [Assign Live Class Telegram Group Link]
                         │
                         ▼
              [Update MongoDB: telegramGroupAssigned]
                         │
                         ▼
              [Trigger Workflow 5: Confirmation Email]
                         │
                         ▼
              [Trigger Workflow 6: Admin Notification]
                         │
                         ▼
              [Respond: { telegramLink, classStartDate? }]
```

### Input Payload
```json
{
  "registrationId": "664def...",
  "userId": "664abc...",
  "courseType": "live",
  "email": "user@gmail.com",
  "name": "Dara Chan",
  "firstNameEn": "Dara",
  "lastNameEn": "Chan",
  "githubUsername": "darachan",
  "referralSource": "Telegram"
}
```

---

## Workflow 3 — Payment Proof Storage

**Trigger:** Webhook POST `/n8n/payment-proof`  
**Called by:** Backend after file upload to Cloudinary/S3  
**Purpose:** Log payment event, notify admin, flag for verification

```
[Webhook]
    │
    ▼
[Update MongoDB Registration: paymentStatus = "pending", screenshotUrl]
    │
    ▼
[Send Admin Telegram Message]
    │   "💰 New payment proof submitted"
    │   "Name: Dara Chan | Course: Live Class"
    │   "Screenshot: <url>"
    │   "Verify: <admin dashboard link>"
    │
    ▼
[Log to Google Sheets: "Pending Payments" sheet]
    │
    ▼
[Respond: { received: true }]
```

### Admin Telegram Message Format
```
💰 New Payment Proof
━━━━━━━━━━━━━━━━━━━
👤 Dara Chan (darachan)
📧 user@gmail.com
📚 Course: Live Online Class ($49.99)
📎 Screenshot: https://res.cloudinary.com/...
🔗 Review: https://admin.yourbootcamp.com/registrations/664def
```

---

## Workflow 4 — Telegram Group Assignment

**Trigger:** Called internally from Workflow 2 (Execute Workflow node)  
**Purpose:** Generate correct invite link based on course type

```
[Input: courseType]
    │
    ▼
[Switch: courseType]
  ├── "video" ──► [Read Env: VIDEO_TELEGRAM_INVITE_LINK]
  └── "live"  ──► [Read Env: LIVE_TELEGRAM_INVITE_LINK]
                         │
                         ▼
              [Optionally: Generate single-use invite via Telegram Bot API]
                         │
                         ▼
              [Return: { telegramInviteLink }]
```

> **Note:** For security, consider generating single-use Telegram invite links via `createChatInviteLink` (member_limit=1) so each registrant gets a unique link after payment verification rather than a static group link.

---

## Workflow 5 — Confirmation Email

**Trigger:** Called from Workflow 2 (Execute Workflow node)  
**Purpose:** Send registration confirmation email

### Email Template — Video Course
```
Subject: 🎉 You're registered for Backend Bootcamp!

Hi [Name],

You've successfully registered for the Self-Paced Video Course.

📚 Course: Express.js + MongoDB Backend Development
💰 Amount: $29.99
📅 Access: Immediate upon payment verification

📱 Join your Telegram group: [VIDEO_GROUP_LINK]

Once your payment is verified (usually within 24h), you'll receive
your course access credentials.

Questions? Reply to this email.

— The Bootcamp Team
```

### Email Template — Live Class
```
Subject: 🎉 See you in class — Backend Bootcamp!

Hi [Name],

You've successfully registered for the Live Online Class.

📚 Course: Express.js + MongoDB Backend Development
💰 Amount: $49.99
📅 Class Starts: [CLASS_START_DATE]
🕐 Schedule: [CLASS_SCHEDULE]

📱 Join your Telegram group: [LIVE_GROUP_LINK]

Once your payment is verified, you'll receive your Zoom/Meet link.

— The Bootcamp Team
```

---

## Workflow 6 — Admin Notification

**Trigger:** Called from Workflow 2  
**Purpose:** Alert admin channel on every new registration

```
[Input: registration data]
    │
    ▼
[Format Telegram Message]
    │
    ▼
[Send to Admin Telegram Channel/Group]
    │
    ▼
[Append row to Google Sheets: "All Registrations"]
```

### Admin Telegram Notification Format
```
📝 New Registration
━━━━━━━━━━━━━━━━━━━
👤 Dara Chan (ដារ៉ា ចាន់)
📧 user@gmail.com
🐙 GitHub: darachan
📚 Course: Live Class ($49.99)
🎓 Education: University Student — Year 2 (CS)
💡 Experience: Basic
📣 Referred by: Telegram
⏰ 2026-06-17 14:32 UTC
```

---

## Workflow 7 — Registration Export to Google Sheets

**Trigger:** Schedule (daily at 08:00) OR webhook `/n8n/export-sheets`  
**Purpose:** Sync all registrations to Google Sheets for admin review

```
[Trigger: Schedule / Webhook]
    │
    ▼
[Fetch all registrations from MongoDB]
    │
    ▼
[Transform: flatten nested fields, format dates]
    │
    ▼
[Google Sheets: Clear "Registrations" sheet]
    │
    ▼
[Google Sheets: Append all rows]
    │
    ▼
[IF triggered by webhook: Respond with row count]
```

### Google Sheets Columns
| Column | Field |
|--------|-------|
| A | Registration ID |
| B | Submitted At |
| C | Full Name (EN) |
| D | Full Name (KH) |
| E | Email |
| F | Course Type |
| G | Amount |
| H | Education Level |
| I | Academic Year |
| J | Major |
| K | GitHub Username |
| L | Experience Level |
| M | Referral Source |
| N | Payment Status |
| O | Telegram Group |
| P | Payment Screenshot URL |

---

## n8n Environment Variables

Set these in n8n's **Credentials** or **Environment** settings:

```env
MONGO_URI=mongodb://user:pass@localhost:27017/bootcamp
VIDEO_TELEGRAM_INVITE_LINK=https://t.me/+xxxxx
LIVE_TELEGRAM_INVITE_LINK=https://t.me/+yyyyy
ADMIN_TELEGRAM_BOT_TOKEN=7xxxxxxx:AAxxxx
ADMIN_TELEGRAM_CHAT_ID=-100xxxxxxx
CLASS_START_DATE=2026-08-01
CLASS_SCHEDULE=Mon/Wed/Fri 19:00–21:00 ICT
GOOGLE_SHEETS_SPREADSHEET_ID=1BxiM...
ADMIN_DASHBOARD_BASE_URL=https://admin.yourbootcamp.com
```

---

## Webhook Security

All n8n webhooks should use **Header Auth** credential:
- Header: `X-Internal-Token`
- Value: a long random secret shared with the Express backend

This prevents external actors from calling your webhooks directly.
