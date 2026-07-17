# Simple Bootcamp Registration Form (No Authentication)

> ⚡ **Ultra-simple version** — No Google OAuth, just a direct 4-page form

Perfect for quick setup when you don't need user authentication or duplicate prevention.

---

## What's Included

✅ **4-page form** (Track → Personal Info → Background → Payment)  
✅ **Email collection** (instead of Google OAuth)  
✅ **Google Drive upload** for payment screenshots  
✅ **MongoDB storage**  
✅ **Telegram admin notifications**  
✅ **Dynamic pricing** based on course selection  
✅ **No authentication required** — anyone can register  

⚠️ **Note:** No duplicate prevention — users can submit multiple times

---

## What You Need

### 1. **MongoDB** (Free: 512 MB)
- [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
- Create database: `bootcamp`
- Collection: `registrations` (auto-created)

### 2. **Google Drive** (Free: 15 GB)
- Create folder "Bootcamp Payments"
- Get folder ID from URL

### 3. **Telegram Bot**
- Message [@BotFather](https://t.me/botfather) → create bot
- Get bot token
- Get your admin chat ID from [@userinfobot](https://t.me/userinfobot)

### 4. **Telegram Groups**
- Create 2 groups (live class + video course)
- Generate invite links

---

## Setup Steps

### 1. Import to n8n
```
1. Open n8n
2. Click "Import from File"
3. Select `bootcamp-registration-simple.json`
4. Click "Import"
```

### 2. Add Credentials

#### MongoDB
- **Connection String:** `mongodb+srv://user:pass@cluster.mongodb.net/bootcamp`

#### Google Drive OAuth2
- [Create credentials in Google Cloud Console](https://console.cloud.google.com/)
- Enable Google Drive API
- Client ID + Client Secret

#### Telegram
- **Bot Token:** from @BotFather

### 3. Set Environment Variables

In n8n Settings → Variables:

| Variable | Value |
|---|---|
| `N8N_BASE_URL` | `https://your-n8n.com` |
| `MONGODB_URI` | `mongodb+srv://...` |
| `MONGODB_DATABASE` | `bootcamp` |
| `GDRIVE_FOLDER_ID` | `1a2B3c4D5e...` |
| `TELEGRAM_BOT_TOKEN` | `123456:ABC-DEF...` |
| `TELEGRAM_ADMIN_CHAT_ID` | `123456789` |
| `TELEGRAM_LIVE_GROUP` | `https://t.me/+live_link` |
| `TELEGRAM_VIDEO_GROUP` | `https://t.me/+video_link` |
| `PAYMENT_LIVE_URL` | Payment gateway link for $49.99 |
| `PAYMENT_VIDEO_URL` | Payment gateway link for $29.99 |

### 4. Create Payment Gateway Links

**Option 1: ABA PayWay** (Cambodia)

1. Login to [ABA PayWay Merchant Portal](https://payway.aba.com.kh/)
2. Create Payment Link:
   - **Live Class:** Amount = $49.99, Description = "Backend Bootcamp - Live Class"
   - **Video Course:** Amount = $29.99, Description = "Backend Bootcamp - Video Course"
3. Copy the payment URLs
4. Add to environment variables

**Option 2: Wing/Pi Pay/True Money**

1. Generate payment request link in your provider's dashboard
2. Set fixed amounts for each course
3. Copy the payment URLs

**Option 3: Stripe**

1. Go to [Stripe Dashboard → Payment Links](https://dashboard.stripe.com/payment-links)
2. Create two payment links:
   - **Live Class:** $49.99 one-time payment
   - **Video Course:** $29.99 one-time payment
3. Copy the URLs (format: `https://buy.stripe.com/...`)

**Option 4: PayPal**

1. Create PayPal.Me links or Payment Buttons
2. Set preset amounts
3. Copy the payment URLs

**Example URLs:**
```bash
PAYMENT_LIVE_URL="https://payway.aba.com.kh/pay/abc123..."
PAYMENT_VIDEO_URL="https://payway.aba.com.kh/pay/xyz789..."

# Or Stripe
PAYMENT_LIVE_URL="https://buy.stripe.com/test_abc123"
PAYMENT_VIDEO_URL="https://buy.stripe.com/test_xyz789"
```

### 5. Activate & Share

1. Click "Active" toggle in n8n
2. Share form URL: `https://your-n8n.com/form/simple-form-page-1`

---

## Form Flow

```
Page 1: Choose Track (Live $49.99 or Video $29.99)
   ↓
Page 2: Personal Info (Email + Name in English & Khmer)
   ↓
Page 3: Background (Academic year, major, GitHub, expectations)
   ↓
Page 4: Payment (Click payment link button, upload screenshot)
   ↓
Upload to Google Drive
   ↓
Save to MongoDB
   ↓
Telegram notification to admin
   ↓
Success page with Telegram group link
```

---

## Differences from Authenticated Version

| Feature | Simple Version | Authenticated Version |
|---|---|---|
| **User Auth** | ❌ None | ✅ Google OAuth |
| **Duplicate Prevention** | ❌ No | ✅ Yes (by Google ID) |
| **Email Collection** | Manual field | From Google profile |
| **Session Token** | ❌ No | ✅ JWT |
| **Setup Complexity** | ⚡ Very Easy | 🔧 Moderate |
| **Number of Nodes** | 15 | 35+ |
| **Form URL** | Direct access | After OAuth redirect |

---

## MongoDB Schema

```js
{
  _id: ObjectId,
  email: "user@example.com",  // ← Collected from form, not Google
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
  paymentScreenshotFileId: "1a2B3c...",
  
  paymentStatus: "pending",
  submittedAt: ISODate("2026-06-17T..."),
  verifiedAt: null,
  telegramNotificationSent: false
}
```

---

## Handling Duplicates (Manual)

Since there's no auth, users can submit multiple times. To check for duplicates:

### Query MongoDB by Email
```js
db.registrations.find({ email: "user@example.com" }).sort({ submittedAt: -1 })
```

### Mark Duplicate as Invalid
```js
db.registrations.updateOne(
  { _id: ObjectId("...") },
  { $set: { paymentStatus: "duplicate", notes: "Duplicate submission" } }
)
```

### Add Email Index (Optional)
```js
db.registrations.createIndex({ email: 1 })
```

---

## Admin Workflow

### 1. Receive Telegram Notification
```
💰 New Bootcamp Registration
━━━━━━━━━━━━━━━━━━━
👤 Name: Dara Chan
📧 Email: user@example.com
📚 Track: Live Class ($49.99)
📎 Payment Screenshot: [Google Drive Link]
🔗 Registration ID: 665abc123...
```

### 2. Verify Payment
1. Click Google Drive link
2. Check payment screenshot
3. Verify transaction ID

### 3. Update Registration Status
```js
db.registrations.updateOne(
  { _id: ObjectId("665abc123...") },
  { 
    $set: { 
      paymentStatus: "verified",
      verifiedAt: new Date(),
      telegramNotificationSent: true
    }
  }
)
```

### 4. Send Confirmation
Message the user on Telegram or email them confirmation

---

## Cost Breakdown

| Service | Free Tier |
|---|---|
| **n8n** (self-hosted) | ✅ Free |
| **MongoDB** | ✅ 512 MB free |
| **Google Drive** | ✅ 15 GB free |
| **Telegram Bot** | ✅ Free |

**Total:** $0/month (+ n8n hosting ~$5-10/mo if using cloud VPS)

---

## Troubleshooting

### Form not loading
- Check workflow is "Active"
- Verify webhook URL: `/form/simple-form-page-1`

### Google Drive upload fails
- Verify OAuth credentials
- Check Google Drive API is enabled
- Ensure folder ID is correct

### Telegram notification not sent
- Verify bot token
- Check admin chat ID
- Ensure bot is started (message it first)

### MongoDB connection error
- Whitelist IP: `0.0.0.0/0` in MongoDB Atlas
- Check connection string format

---

## Add Duplicate Prevention (Optional)

Want to prevent duplicate submissions by email? Add this node after Page 2:

### MongoDB — Check Existing Email
```json
{
  "operation": "findOne",
  "collection": "registrations",
  "query": "={{ { email: $json['Email Address'] } }}"
}
```

### IF — Email Exists?
```json
{
  "conditions": [
    {
      "leftValue": "={{ $json._id }}",
      "rightValue": "",
      "operator": "isNotEmpty"
    }
  ]
}
```

**If exists** → Show error page  
**If new** → Continue to Page 3

---

## Upgrade to Authenticated Version

If you need:
- ✅ Google sign-in
- ✅ Stronger duplicate prevention
- ✅ User profiles
- ✅ Session management

→ Use `bootcamp-registration-standalone.json` instead

---

## Support

Questions? Check:
- n8n execution logs
- MongoDB collections
- Telegram bot status
- Google Drive folder permissions

---

## Quick Start Command

```bash
# Get form URL after activation
echo "Form URL: https://your-n8n.com/form/simple-form-page-1"

# Share on social media, Telegram, or embed on website
```

**Done!** 🎉 Your registration form is live.
