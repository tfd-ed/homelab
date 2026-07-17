# Standalone n8n Bootcamp Registration (No Backend Required)

> ✅ **100% n8n — No Express.js backend needed**

This workflow handles everything: Google OAuth, session management, MongoDB storage, file uploads to Google Drive, Telegram notifications, and duplicate prevention.

---

## What You Need

### 1. **MongoDB** (Free tier works)
- [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) — 512 MB free forever
- Create a database named `bootcamp`
- Collections: `users`, `registrations` (auto-created)

### 2. **Google Drive** (Free: 15 GB storage)
- Use the same Google account as OAuth
- Create a folder called "Bootcamp Payments"
- Get folder ID from URL: `https://drive.google.com/drive/folders/{FOLDER_ID}`
- n8n will need OAuth access to upload files

### 3. **Telegram Bot**
- Message [@BotFather](https://t.me/botfather)
- Create a bot → get `BOT_TOKEN`
- Get your admin chat ID:
  - Message [@userinfobot](https://t.me/userinfobot) to get your user ID

### 4. **Google OAuth**
- [Google Cloud Console](https://console.cloud.google.com/)
- Create OAuth 2.0 credentials
- Add redirect URI: `https://your-n8n.com/webhook/bootcamp/auth/callback`
- **Enable Google Drive API:**
  1. Go to "APIs & Services" → "Library"
  2. Search "Google Drive API"
  3. Click "Enable"
- Add OAuth scopes: `openid`, `email`, `profile`, `https://www.googleapis.com/auth/drive.file`

### 5. **Telegram Groups**
- Create 2 groups (live class + video course)
- Generate invite links from group settings

---

## Setup Steps

### 1. Import Workflow
```bash
# In n8n UI
1. Click "Import from File"
2. Select `bootcamp-registration-standalone.json`
3. Click "Import"
```

### 2. Configure Credentials
Create these credentials in n8n:

#### MongoDB
- **Name:** MongoDB account
- **Connection String:** `mongodb+srv://user:pass@cluster.mongodb.net/bootcamp`

#### Google Drive OAuth2
- **Name:** Google Drive account
- **Client ID:** (from Google Cloud Console)
- **Client Secret:** (from Google Cloud Console)
- **Scopes:** `https://www.googleapis.com/auth/drive.file`

#### Telegram
- **Name:** Telegram account
- **Bot Token:** your-bot-token

### 3. Set Environment Variables
In n8n Settings → Variables, add:

| Variable | Example Value |
|---|---|
| `GOOGLE_CLIENT_ID` | `123456789.apps.googleusercontent.com` |
| `GOOGLE_CLIENT_SECRET` | `GOCSPX-abcd1234...` |
| `N8N_BASE_URL` | `https://your-n8n.com` |
| `MONGODB_URI` | `mongodb+srv://...` |
| `MONGODB_DATABASE` | `bootcamp` |
| `JWT_SECRET` | `random-256-bit-secret-here` |
| `GDRIVE_FOLDER_ID` | `1a2B3c4D5e6F7g8H9i0J` |
| `TELEGRAM_BOT_TOKEN` | `123456:ABC-DEF...` |
| `TELEGRAM_ADMIN_CHAT_ID` | `123456789` |
| `TELEGRAM_LIVE_GROUP` | `https://t.me/+live_invite_link` |
| `TELEGRAM_VIDEO_GROUP` | `https://t.me/+video_invite_link` |
| `PAYMENT_LIVE_URL` | Payment gateway link for $49.99 |
| `PAYMENT_VIDEO_URL` | Payment gateway link for $29.99 |

**Generate JWT_SECRET:**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

**Get Google Drive Folder ID:**
1. Open Google Drive
2. Create folder "Bootcamp Payments"
3. Open the folder
4. Copy ID from URL: `https://drive.google.com/drive/folders/{THIS_IS_THE_ID}`

### 4. Create Payment Gateway Links

**ABA PayWay** (Cambodia):
1. Login to [ABA PayWay Merchant Portal](https://payway.aba.com.kh/)
2. Create Payment Link for $49.99 (Live Class)
3. Create Payment Link for $29.99 (Video Course)
4. Add URLs to environment variables

**Stripe** (International):
1. Go to [Stripe Dashboard → Payment Links](https://dashboard.stripe.com/payment-links)
2. Create two one-time payment links
3. Copy the URLs (format: `https://buy.stripe.com/...`)

**Wing/Pi Pay** (Cambodia):
1. Generate payment request links in merchant dashboard
2. Set fixed amounts for each course

### 5. Update Credential IDs
In the workflow JSON, replace these placeholders:
- `REPLACE_WITH_YOUR_MONGO_CREDENTIAL_ID`
- `REPLACE_WITH_YOUR_GDRIVE_CREDENTIAL_ID`
- `REPLACE_WITH_YOUR_TELEGRAM_CREDENTIAL_ID`
- `REPLACE_WITH_YOUR_N8N_INSTANCE_ID`

Or just assign credentials via n8n UI after import.

### 6. Activate Workflow
- Click "Active" toggle in n8n
- Test by visiting: `https://your-n8n.com/webhook/bootcamp/start`

---

## Workflow Endpoints

| URL | Purpose |
|---|---|
| `/webhook/bootcamp/start` | Landing page (start here) |
| `/webhook/bootcamp/auth` | Google OAuth initiation |
| `/webhook/bootcamp/auth/callback` | Google OAuth callback |
| `/webhook/bootcamp/already-registered` | Shown if user already registered |
| `/form/bootcamp-register` | Main registration form (5 pages) |

---

## How It Works

### Flow Diagram
```
User visits /webhook/bootcamp/start
         ↓
Click "Continue with Google"
         ↓
Google OAuth → JWT token generated
         ↓
Redirected to form with ?token=...
         ↓
Fill 5-page form (track, names, background, profile, payment)
         ↓
Upload payment screenshot → Google Drive
         ↓
Save to MongoDB
         ↓
Send Telegram notification to admin
         ↓
Show confirmation + Telegram group link
```

### Session Token (JWT)
- **Generated:** After Google OAuth success
- **Expires:** 1 hour
- **Payload:** `{ userId, email, iat, exp }`
- **Verified:** On form submission via Code node

### Duplicate Prevention
- MongoDB query checks if `userId` already has a registration
- If exists → redirect to "Already Registered" page
- If new → generate JWT and proceed to form

### MongoDB Collections

#### `users`
```js
{
  _id: ObjectId,
  googleId: "109876543210",
  email: "user@gmail.com",
  name: "Dara Chan",
  picture: "https://lh3.googleusercontent.com/...",
  createdAt: ISODate,
  lastLogin: ISODate
}
```

#### `registrations`
```js
{
  _id: ObjectId,
  userId: ObjectId,
  email: "user@gmail.com",
  courseType: "live" | "video",
  price: 49.99,
  
  firstNameEn: "Dara",
  lastNameEn: "Chan",
  firstNameKh: "ដារ៉ា",
  lastNameKh: "ចាន់",
  
  academicYear: "University — Year 2",
  major: "Computer Science",
  institution: "RUPP",
  
  githubUsername: "darachan",
  experienceLevel: "🔨 Intermediate",
  expectations: "I want to...",
  referralSource: "Telegram",
  
  transactionId: "TXN-2026123456",
  paymentScreenshotUrl: "https://drive.google.com/file/d/.../view",
  paymentScreenshotFileId: "1a2B3c4D5e...",
  
  paymentStatus: "pending" | "verified" | "rejected",
  submittedAt: ISODate,
  verifiedAt: ISODate | null,
  telegramNotificationSent: true
}
```

---

## Testing Locally

### 1. Use ngrok for public URL
```bash
ngrok http 5678
# Use the ngrok URL as N8N_BASE_URL
```

### 2. Update Google OAuth redirect URI
Add ngrok URL to Google Console:
```
https://abc123.ngrok.io/webhook/bootcamp/auth/callback
```

### 3. Visit Landing Page
```
https://abc123.ngrok.io/webhook/bootcamp/start
```

---

## Admin Tasks

### Verify Payment
After admin receives Telegram notification:

1. Check payment screenshot URL
2. Manually update MongoDB:
   ```js
   db.registrations.updateOne(
     { _id: ObjectId("...") },
     { 
       $set: { 
         paymentStatus: "verified",
         verifiedAt: new Date()
       }
     }
   )
   ```
3. Send confirmation message in Telegram group

### View All Registrations
```js
db.registrations.find({ paymentStatus: "pending" }).sort({ submittedAt: -1 })
```

---

## Cost Breakdown

| Service | Free Tier | Cost After Free |
|---|---|---|
| **n8n** (self-hosted) | ✅ Free forever | Hosting only ($5-10/mo) |
| **MongoDB Atlas** | 512 MB | $0.08/GB/mo |
| **Google Drive** | 15 GB | $1.99/mo for 100 GB |
| **Telegram Bot** | ✅ Free forever | Free |
| **Google OAuth** | ✅ Free forever | Free |

**Total:** $0-10/month depending on traffic (typically $0 for small bootcamps)

---

## Troubleshooting

### "Invalid token" error
- Check `JWT_SECRET` is set correctly
- Token expires after 1 hour — sign in again

### Google Drive upload fails
- Verify OAuth credentials in n8n
- Ensure Google Drive API is enabled in Cloud Console
- Check folder ID is correct
- Verify n8n has permission to access the folder
- Check file size < 10 MB

### Telegram notification not sent
- Verify bot token
- Ensure admin chat ID is correct (not group ID)
- Bot must be started by admin (message bot first)

### MongoDB connection failed
- Whitelist IP `0.0.0.0/0` in Atlas Network Access
- Check connection string format

### Google OAuth redirect error
- Verify redirect URI in Google Console matches exactly
- Must include `/webhook/bootcamp/auth/callback`

---

## Security Notes

- ✅ JWT tokens expire after 1 hour
- ✅ Google OAuth prevents fake sign-ups
- ✅ MongoDB prevents duplicate registrations (unique userId)
- ✅ Google Drive auto-scans file uploads for malware
- ✅ No sensitive data in URLs (token in query param, but short-lived)

### Production Recommendations
- Use HTTPS for n8n (required for Google OAuth)
- Set MongoDB network whitelist to n8n server IP only
- Rotate JWT_SECRET monthly
- Restrict Google Drive folder sharing to owner only
- Add rate limiting to n8n (built-in: 5 req/sec per IP)

---

## What's Next?

### Optional Enhancements
1. **Email confirmations** — Add Gmail/SendGrid node
2. **Payment verification automation** — Add bank API integration
3. **Admin dashboard** — Create n8n form for verification UI
4. **Google Sheets export** — Add sheet for tracking registrations
5. **Automated Telegram invites** — Use Telegram Bot API to generate single-use invite links

---

## Support

Questions? Issues?
- Check n8n execution logs
- Review MongoDB collections structure
- Test each node individually in n8n UI

Good luck with your bootcamp! 🚀
