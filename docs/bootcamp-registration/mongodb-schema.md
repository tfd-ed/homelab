# MongoDB Schema Design

---

## Collection: `users`

Stores authenticated Google users. Created on first login.

```js
// models/User.js
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  googleId: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  },
  name: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100,
  },
  picture: {
    type: String,
    default: null,
  },
  isAdmin: {
    type: Boolean,
    default: false,
  },
  lastLogin: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,  // adds createdAt, updatedAt
});

module.exports = mongoose.model('User', userSchema);
```

### Indexes
```js
userSchema.index({ googleId: 1 }, { unique: true });
userSchema.index({ email: 1 },    { unique: true });
```

---

## Collection: `registrations`

One registration per user (enforced by unique index on `userId`).

```js
// models/Registration.js
const mongoose = require('mongoose');

const registrationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,   // Prevents duplicate registrations
    index: true,
  },

  // ── Course Selection ──────────────────────────────────────
  courseType: {
    type: String,
    enum: ['video', 'live'],
    required: true,
  },
  coursePrice: {
    type: Number,
    required: true,
    enum: [29.99, 49.99],
  },

  // ── Personal Information ──────────────────────────────────
  firstNameEn: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50,
  },
  lastNameEn: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50,
  },
  firstNameKh: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50,
  },
  lastNameKh: {
    type: String,
    required: true,
    trim: true,
    maxlength: 50,
  },

  // ── Education Background ──────────────────────────────────
  educationLevel: {
    type: String,
    required: true,
    enum: ['high_school', 'university', 'graduate', 'working_professional', 'other'],
  },
  academicYear: {
    type: String,
    enum: ['year_1', 'year_2', 'year_3', 'year_4', 'graduate', 'other', 'n/a'],
    default: 'n/a',
  },
  major: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100,
  },

  // ── Technical Profile ─────────────────────────────────────
  githubUsername: {
    type: String,
    required: true,
    trim: true,
    maxlength: 39,                  // GitHub username limit
    match: /^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,37}[a-zA-Z0-9])?$/, // GitHub username rules
  },
  experienceLevel: {
    type: String,
    required: true,
    enum: ['beginner', 'basic', 'intermediate', 'advanced'],
  },

  // ── Motivation ────────────────────────────────────────────
  expectations: {
    type: String,
    required: true,
    trim: true,
    maxlength: 2000,
  },

  // ── Marketing Attribution ─────────────────────────────────
  referralSource: {
    type: String,
    required: true,
    enum: ['facebook', 'telegram', 'youtube', 'friend_referral', 'previous_student', 'website', 'other'],
  },

  // ── Payment ───────────────────────────────────────────────
  paymentScreenshotUrl: {
    type: String,
    default: null,
  },
  paymentStatus: {
    type: String,
    enum: ['unpaid', 'pending', 'verified', 'rejected'],
    default: 'unpaid',
  },
  paymentVerifiedAt: {
    type: Date,
    default: null,
  },
  paymentVerifiedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },

  // ── Post-Registration ─────────────────────────────────────
  telegramGroupAssigned: {
    type: String,
    default: null,
  },
  confirmationEmailSentAt: {
    type: Date,
    default: null,
  },

}, {
  timestamps: true,
});
```

### Indexes
```js
// Prevent duplicate registrations — one per user
registrationSchema.index({ userId: 1 }, { unique: true });

// Admin filtering
registrationSchema.index({ courseType: 1, paymentStatus: 1 });
registrationSchema.index({ createdAt: -1 });
registrationSchema.index({ referralSource: 1 });
```

---

## Validation Rules Summary

| Field | Rule |
|-------|------|
| `userId` | Unique — blocks duplicate registration |
| `courseType` | Only `video` or `live` |
| `coursePrice` | Must match course type: video=29.99, live=49.99 |
| `firstNameEn/lastNameEn` | Required, trimmed, max 50 chars |
| `firstNameKh/lastNameKh` | Required, trimmed, max 50 chars |
| `githubUsername` | Required, regex validated, max 39 chars |
| `expectations` | Required, max 2000 chars |
| `paymentScreenshotUrl` | Set only after file upload |
| `paymentStatus` | Default `unpaid`; only backend/admin can set `verified` |

---

## Business Logic — Duplicate Registration Prevention

The combination of:
1. `unique: true` on `userId` in the Registration schema
2. Auth middleware requiring a valid session before accessing `/api/registration`
3. Redirect at OAuth callback if registration already exists

...ensures one user → one registration at both the DB level and application level.

---

## Derived Price Logic (service layer)

```js
// services/registration.js
const COURSE_PRICES = { video: 29.99, live: 49.99 };

async function submit(user, body) {
  // Check for existing registration first
  const existing = await Registration.findOne({ userId: user._id });
  if (existing) {
    throw Object.assign(new Error('Already registered'), { statusCode: 409 });
  }

  const coursePrice = COURSE_PRICES[body.courseType];
  if (!coursePrice) throw Object.assign(new Error('Invalid course type'), { statusCode: 400 });

  const registration = await Registration.create({
    userId: user._id,
    coursePrice,
    ...body,
  });

  return { registrationId: registration._id, courseType: registration.courseType };
}
```
