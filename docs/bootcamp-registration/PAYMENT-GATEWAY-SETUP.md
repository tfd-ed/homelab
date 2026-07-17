# Payment Gateway Integration Guide

This guide shows you how to integrate payment gateway links directly into your n8n registration forms. Instead of static QR codes, users click a button that takes them to your payment provider's secure checkout page.

---

## 🎯 Benefits of Payment Gateway Links

| Advantage | Description |
|-----------|-------------|
| **One-Click Payment** | Users click button → redirected to secure payment page |
| **Mobile Friendly** | Works perfectly on phones (no QR scanning needed) |
| **Professional** | Uses official payment provider branding |
| **Automatic Amount** | Price is pre-filled, no manual entry errors |
| **Multiple Providers** | Support ABA, Stripe, PayPal, Wing, Pi Pay, etc. |
| **Webhook Ready** | Some providers can auto-verify payments |
| **No Image Hosting** | Just paste the URL, no base64 conversion needed |

---

## 🔧 Supported Payment Providers

### 1. **ABA PayWay** (Cambodia) 🇰🇭

**Best for:** Cambodian businesses accepting ABA, ACLEDA, Wing, Pi Pay

**Setup:**
1. Sign up at [https://payway.aba.com.kh/](https://payway.aba.com.kh/)
2. Complete merchant verification
3. Create payment links:
   - Go to **Merchant Portal → Payment Links**
   - Create link for **Live Class ($49.99)**
   - Create link for **Video Course ($29.99)**
   - Set description: "Backend Bootcamp - [Track Name]"
4. Copy the payment URLs

**URL Format:**
```
https://payway.aba.com.kh/pay/[merchant-id]/[payment-id]
```

**Features:**
- ✅ Supports ABA, ACLEDA, Wing, Pi Pay, True Money
- ✅ QR code built-in on payment page
- ✅ Mobile banking integration
- ✅ Webhook notifications available
- ✅ Transaction reports dashboard

---

### 2. **Stripe** (International) 🌍

**Best for:** International payments, credit/debit cards

**Setup:**
1. Sign up at [https://stripe.com](https://stripe.com)
2. Go to **Dashboard → Payment Links**
3. Click "Create payment link"
4. Configure:
   - **Product:** Backend Bootcamp - Live Class
   - **Price:** $49.99 USD
   - **Payment type:** One-time
   - **Tax:** Optional (set if required)
5. Click "Create link"
6. Copy the URL (format: `https://buy.stripe.com/...`)
7. Repeat for Video Course ($29.99)

**URL Format:**
```
https://buy.stripe.com/test_abc123xyz
https://buy.stripe.com/live_def456uvw
```

**Features:**
- ✅ Credit/debit cards worldwide
- ✅ Apple Pay, Google Pay
- ✅ Automatic receipt emails
- ✅ Webhook integration for auto-verification
- ✅ Subscription option (if you want recurring payments)
- ✅ Tax calculation built-in

**Webhook Setup (Optional):**
```javascript
// n8n Webhook endpoint to receive Stripe events
// POST /webhook/stripe-payment
{
  "event": "payment_intent.succeeded",
  "data": {
    "amount": 4999,
    "customer_email": "user@example.com",
    "metadata": {
      "registration_id": "665abc123..."
    }
  }
}
```

---

### 3. **PayPal** 💙

**Best for:** Familiar payment option, no credit card needed

**Setup:**
1. Login to [https://paypal.com/paypalme](https://paypal.com/paypalme)
2. Create PayPal.Me link
3. Or use **Payment Buttons**:
   - Go to [https://www.paypal.com/buttons/](https://www.paypal.com/buttons/)
   - Create button for $49.99
   - Create button for $29.99
   - Get the hosted button URL

**URL Format:**
```
https://www.paypal.me/yourusername/49.99
https://www.paypal.com/paypalme/yourusername/29.99USD
```

**Features:**
- ✅ No credit card needed (PayPal balance)
- ✅ Buyer protection
- ✅ International support
- ✅ Mobile app integration

---

### 4. **Wing** (Cambodia) 🇰🇭

**Best for:** Cambodian mobile money payments

**Setup:**
1. Contact Wing business team
2. Request payment link feature
3. Generate payment requests via merchant portal
4. Set fixed amounts for each course

**Features:**
- ✅ Mobile-first payment
- ✅ No bank account needed
- ✅ Popular in Cambodia

---

### 5. **Pi Pay** (Cambodia) 🇰🇭

**Best for:** Tech-savvy Cambodian users

**Setup:**
1. Register as Pi Pay merchant
2. Use merchant API or portal to generate payment links
3. Set amounts and descriptions

**Features:**
- ✅ Fast mobile payments
- ✅ Growing user base in Cambodia

---

## 📋 Implementation Steps

### Step 1: Create Payment Links

Choose your provider and create **2 payment links**:
- **Live Class:** $49.99
- **Video Course:** $29.99

### Step 2: Add to n8n Environment Variables

In n8n: **Settings → Variables**

```bash
PAYMENT_LIVE_URL="https://your-payment-provider.com/pay/live-class"
PAYMENT_VIDEO_URL="https://your-payment-provider.com/pay/video-course"
```

### Step 3: Import Workflow

The n8n workflows already have payment link integration built-in. Just import:
- `bootcamp-registration-simple.json` (no auth)
- `bootcamp-registration-standalone.json` (with Google OAuth)

### Step 4: Test Payment Flow

1. Fill out registration form
2. Get to payment page
3. Click "Pay $49.99 Now" button
4. Verify it opens correct payment link
5. Complete test payment
6. Upload payment screenshot
7. Check Telegram notification

---

## 🎨 How It Looks in the Form

The payment page displays:

```html
┌──────────────────────────────────────┐
│  ✅ Almost done! One final step.     │
│  Your registration details saved.    │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│      Your selected track             │
│   🎓 Live Online Class               │
│        $49.99                        │
│  One-time payment · No recurring     │
└──────────────────────────────────────┘

   💳 Click the button below to pay securely:

   ┌─────────────────────────┐
   │   🔒 Pay $49.99 Now    │
   └─────────────────────────┘
      ↑ Opens in new tab

   Secure payment via ABA · Wing · Pi Pay

⚠️ Important: After completing payment,
   return here to upload your receipt screenshot.

⬇️ Upload your payment screenshot below:
   [Choose File button]
```

---

## 🔐 Security Best Practices

### 1. Use HTTPS Only
```bash
# Bad
PAYMENT_LIVE_URL="http://payway.com/..."

# Good
PAYMENT_LIVE_URL="https://payway.com/..."
```

### 2. Set Fixed Amounts
Configure payment links with fixed amounts to prevent users from changing the price.

### 3. Add Metadata (Optional)
Some providers (like Stripe) allow metadata:
```json
{
  "metadata": {
    "course": "backend-bootcamp",
    "track": "live",
    "registration_email": "user@example.com"
  }
}
```

### 4. Enable Webhooks (Optional)
Auto-verify payments without manual checking:
- Stripe: `payment_intent.succeeded`
- PayPal: IPN (Instant Payment Notification)
- ABA PayWay: Payment callback URL

---

## 🤖 Advanced: Auto-Verify Payments with Webhooks

### Stripe Example

**1. Create n8n Webhook:**
```
Webhook URL: https://your-n8n.com/webhook/stripe-payment-verification
```

**2. Add Webhook in Stripe Dashboard:**
- Events: `payment_intent.succeeded`

**3. n8n Workflow:**
```json
{
  "nodes": [
    {
      "name": "Webhook — Stripe Payment",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "stripe-payment-verification"
      }
    },
    {
      "name": "MongoDB — Update Registration",
      "type": "n8n-nodes-base.mongodb",
      "parameters": {
        "operation": "updateOne",
        "collection": "registrations",
        "query": "={{ { email: $json.data.object.customer_email } }}",
        "updateDocument": "={{ { $set: { paymentStatus: 'verified', verifiedAt: new Date() } } }}"
      }
    },
    {
      "name": "Telegram — Notify Admin",
      "type": "n8n-nodes-base.telegram",
      "parameters": {
        "text": "✅ Payment verified automatically for {{ $json.data.object.customer_email }}"
      }
    }
  ]
}
```

---

## 📊 Comparison: Payment Links vs QR Codes

| Aspect | Payment Links | QR Codes |
|--------|--------------|-----------|
| **Mobile Experience** | ✅ Excellent (one tap) | ⚠️ Requires camera app |
| **Desktop Experience** | ✅ Excellent (one click) | ❌ Awkward (need phone) |
| **Setup Complexity** | ✅ Very simple (just URL) | ⚠️ Need image + base64 |
| **Dynamic Pricing** | ⚠️ Need separate links | ✅ QR can encode amount |
| **Professional Look** | ✅ Clean button UI | ✅ Professional QR design |
| **Provider Branding** | ✅ Shows provider logo | ✅ Shows QR + logo |
| **Auto-Verification** | ✅ Webhook support | ⚠️ Manual check |
| **No Image Hosting** | ✅ Just text URL | ⚠️ Need base64/hosting |

---

## 🔧 Troubleshooting

### Issue: Payment button doesn't open

**Cause:** Invalid or missing payment URL

**Solution:**
1. Check environment variables in n8n
2. Verify URLs start with `https://`
3. Test URLs in browser directly

### Issue: Wrong amount displayed

**Cause:** Payment link has different amount than form

**Solution:**
1. Create separate payment links for each course
2. Verify `PAYMENT_LIVE_URL` is for $49.99
3. Verify `PAYMENT_VIDEO_URL` is for $29.99

### Issue: Payment link expired

**Cause:** Some providers expire links after 30-90 days

**Solution:**
1. Generate new payment links
2. Update environment variables
3. Consider using permanent links (Stripe, PayPal.Me)

### Issue: Users complete payment but don't upload screenshot

**Cause:** They forget to return to the form

**Solution:**
1. Add warning message (already included)
2. Send email reminder with form link
3. Payment provider may allow success redirect URL

---

## 💡 Pro Tips

### 1. Add Success Redirect (Stripe)
```javascript
// In Stripe payment link settings
"after_completion": {
  "type": "redirect",
  "redirect": {
    "url": "https://your-n8n.com/form/payment-success?email={{CUSTOMER_EMAIL}}"
  }
}
```

### 2. Use Short URLs
```bash
# Long URL
PAYMENT_LIVE_URL="https://buy.stripe.com/test_fZe01bfIg0Kb8bSdQR"

# Better: Use bit.ly or your own domain
PAYMENT_LIVE_URL="https://your-domain.com/pay/live"
```

### 3. Test Mode First
- **Stripe:** Use test keys (`pk_test_...`)
- **PayPal:** Use sandbox mode
- **ABA PayWay:** Request test merchant account

### 4. Track Conversions
Add UTM parameters:
```
PAYMENT_LIVE_URL="https://buy.stripe.com/abc123?utm_source=n8n&utm_campaign=bootcamp"
```

---

## 📝 Environment Variable Template

Copy this to your `.env` or n8n Variables:

```bash
# Payment Gateway URLs
PAYMENT_LIVE_URL="https://your-provider.com/pay/live-49.99"
PAYMENT_VIDEO_URL="https://your-provider.com/pay/video-29.99"

# Or with Stripe
PAYMENT_LIVE_URL="https://buy.stripe.com/test_abc123"
PAYMENT_VIDEO_URL="https://buy.stripe.com/test_xyz789"

# Or with PayPal
PAYMENT_LIVE_URL="https://www.paypal.me/yourusername/49.99USD"
PAYMENT_VIDEO_URL="https://www.paypal.me/yourusername/29.99USD"

# Or with ABA PayWay
PAYMENT_LIVE_URL="https://payway.aba.com.kh/pay/merchant123/live-class"
PAYMENT_VIDEO_URL="https://payway.aba.com.kh/pay/merchant123/video-course"
```

---

## 🎓 Example: Full ABA PayWay Setup

### 1. Merchant Registration
- Contact ABA PayWay sales team
- Submit business documents
- Wait for approval (1-2 weeks)

### 2. Create Payment Links
```
Login → Payment Links → Create New

Live Class:
- Name: Backend Bootcamp - Live
- Amount: $49.99
- Currency: USD
- Description: Live Online Class (Tue/Thu 7-9 PM)
- Generate Link

Video Course:
- Name: Backend Bootcamp - Video
- Amount: $29.99
- Currency: USD
- Description: Self-Paced Video Course
- Generate Link
```

### 3. Add to n8n
```bash
PAYMENT_LIVE_URL="https://payway.aba.com.kh/pay/YOUR_MERCHANT/live"
PAYMENT_VIDEO_URL="https://payway.aba.com.kh/pay/YOUR_MERCHANT/video"
```

### 4. Test
- Click button in form
- Opens ABA PayWay page
- Shows $49.99 or $29.99
- QR code displayed for mobile banking
- Complete test payment
- Upload receipt

---

## 📞 Support Resources

| Provider | Support Link |
|----------|-------------|
| **Stripe** | [https://support.stripe.com](https://support.stripe.com) |
| **PayPal** | [https://www.paypal.com/support](https://www.paypal.com/support) |
| **ABA PayWay** | [https://payway.aba.com.kh/support](https://payway.aba.com.kh/support) |
| **Wing** | Contact Wing business support |
| **Pi Pay** | Contact Pi Pay merchant support |

---

**Done!** 🎉 Your registration form now uses professional payment gateway links instead of static QR codes.
