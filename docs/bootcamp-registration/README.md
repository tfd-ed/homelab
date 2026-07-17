# Backend Development Bootcamp — Registration System

> Express.js + MongoDB Bootcamp | n8n-Powered Automation

## Overview

This project includes **3 implementation options**:

### 1. **Full Stack (Backend + n8n)** — Original Design
- Express.js backend + n8n automation
- Google OAuth 2.0 authentication
- Complete admin dashboard
- See: [backend.md](./backend.md), [api-spec.md](./api-spec.md)

### 2. **Standalone n8n** — No Backend Required ⭐ Recommended
- 100% n8n workflow (no Express needed)
- Built-in Google OAuth + JWT
- MongoDB + Google Drive + Telegram
- See: [bootcamp-registration-standalone.json](./bootcamp-registration-standalone.json)
- Setup: [STANDALONE-SETUP.md](./STANDALONE-SETUP.md)

### 3. **Simple Form** — No Authentication ⚡ Fastest
- Direct 4-page form (no auth)
- Email-based registration
- Perfect for quick launches
- See: [bootcamp-registration-simple.json](./bootcamp-registration-simple.json)
- Setup: [SIMPLE-SETUP.md](./SIMPLE-SETUP.md)

---

## Quick Comparison

| Feature | Full Stack | Standalone n8n | Simple Form |
|---------|-----------|---------------|-------------|
| **Backend Required** | ✅ Express.js | ❌ No | ❌ No |
| **Authentication** | ✅ Google OAuth | ✅ Google OAuth | ❌ Email only |
| **Duplicate Prevention** | ✅ Strong | ✅ Strong | ⚠️ Manual |
| **Setup Time** | 🕐 60 min | 🕐 15 min | ⚡ 5 min |
| **Complexity** | 🔧🔧🔧 High | 🔧🔧 Medium | 🔧 Low |
| **Monthly Cost** | $10-20 | $0-10 | $0 |
| **Best For** | Production apps | Small-medium bootcamps | Quick launches |

---

## System Features

All versions support:

- **Two enrollment tracks**: Self-Paced Video Course ($29.99) and Live Online Class ($49.99)
- **Multi-step registration form** with personal, education, and technical fields (Khmer & English)
- **Payment gateway integration** with clickable payment links (ABA PayWay, Stripe, PayPal, Wing, Pi Pay)
- **Payment flow** with secure redirect to payment provider and receipt screenshot upload
- **Google Drive** or **Cloudinary** file storage
- **MongoDB** data persistence
- **Telegram notifications** to admin
- **Automatic Telegram group assignment** based on course selection

---

## Document Index

| File | Description |
|------|-------------|
| **n8n Workflows** | |
| [bootcamp-registration-standalone.json](./bootcamp-registration-standalone.json) | Complete n8n workflow (no backend) |
| [bootcamp-registration-simple.json](./bootcamp-registration-simple.json) | Simplified form (no auth) |
| [STANDALONE-SETUP.md](./STANDALONE-SETUP.md) | Setup guide for standalone workflow |
| [SIMPLE-SETUP.md](./SIMPLE-SETUP.md) | Setup guide for simple form |
| [PAYMENT-GATEWAY-SETUP.md](./PAYMENT-GATEWAY-SETUP.md) | How to integrate payment links (ABA, Stripe, PayPal, etc.) |
| **Backend Documentation** | |
| [architecture.md](./architecture.md) | System architecture overview, component diagram |
| [backend.md](./backend.md) | Express.js API design, folder structure, middleware |
| [mongodb-schema.md](./mongodb-schema.md) | MongoDB collections, indexes, validation rules |
| [api-spec.md](./api-spec.md) | Full REST API specification with request/response examples |
| [n8n-workflows.md](./n8n-workflows.md) | n8n workflow designs for all automation pipelines |
| [ui-wireframes.md](./ui-wireframes.md) | UI/UX wireframe descriptions, component breakdown, typography |
| [security.md](./security.md) | Auth, duplicate prevention, rate limiting, file upload security |

---

## Quick Start — Standalone n8n (Recommended)

```bash
# 1. Import workflow to n8n
# Download: bootcamp-registration-standalone.json

# 2. Add credentials in n8n UI:
#    - MongoDB
#    - Google Drive OAuth2
#    - Telegram Bot

# 3. Set environment variables (in n8n Settings → Variables)

# 4. Activate workflow

# 5. Visit: https://your-n8n.com/webhook/bootcamp/start
```

See [STANDALONE-SETUP.md](./STANDALONE-SETUP.md) for full instructions.

---

## Quick Start — Simple Form (Fastest)

```bash
# 1. Import workflow to n8n
# Download: bootcamp-registration-simple.json

# 2. Add credentials:
#    - MongoDB
#    - Google Drive OAuth2
#    - Telegram Bot

# 3. Set 10 environment variables

# 4. Activate & share form URL
```

See [SIMPLE-SETUP.md](./SIMPLE-SETUP.md) for full instructions.

---

## Quick Start — Full Stack (Backend + n8n)

```bash
# 1. Clone and install backend
git clone <your-repo>
cd bootcamp-registration/backend
npm install

# 2. Configure environment
cp .env.example .env
# Fill in: MONGO_URI, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET,
#           SESSION_SECRET, CLOUDINARY_URL (or S3 config)

# 3. Start Express backend
npm run dev     # http://localhost:3000

# 4. Start n8n
docker run -it --rm \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n

# 5. Import workflows
# In n8n UI → Import from File → select files in /n8n-workflows/
```

---

## High-Level User Journey

```
[Landing Page]
      │
      ▼
[Google Sign-In] ──── already registered? ──► [Your Registration Status Page]
      │
      ▼
[Course Selection]
  ┌───┴────┐
  │        │
Video    Live Class
$29.99   $49.99
  └───┬────┘
      │
      ▼
[Registration Form]
  Personal Info (EN + KH)
  Education Background
  Technical Profile
  Motivation & Referral
      │
      ▼
[Payment Modal]
  QR Code + Bank Info
  Upload Screenshot
      │
      ▼
[Submit] ──► n8n webhook
      │
      ▼
[Success Page]
  ┌────┴────┐
  │         │
Video     Live Class
Telegram  Telegram + Schedule
Group     Group Link
```

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Frontend | HTML/CSS/JS (or Vue 3 / React) |
| Backend API | Node.js + Express.js |
| Database | MongoDB (Atlas or self-hosted) |
| Auth | Google OAuth 2.0 (Passport.js) |
| File Storage | Cloudinary or AWS S3 |
| Automation | n8n (self-hosted on homelab) |
| Messaging | Telegram Bot API |
| Email | Nodemailer / SendGrid |
| Sheets Export | Google Sheets API (via n8n) |
| Containerization | Docker + Docker Compose |
