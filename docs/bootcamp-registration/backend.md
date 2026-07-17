# Backend Architecture — Express.js

## Folder Structure

```
backend/
├── src/
│   ├── config/
│   │   ├── db.js              # MongoDB connection
│   │   ├── passport.js        # Google OAuth strategy
│   │   ├── cloudinary.js      # File storage config
│   │   └── env.js             # Validated env vars (dotenv + joi)
│   │
│   ├── models/
│   │   ├── User.js            # Google OAuth user
│   │   └── Registration.js    # Bootcamp registration
│   │
│   ├── routes/
│   │   ├── auth.js            # /api/auth/*
│   │   ├── registration.js    # /api/registration/*
│   │   ├── upload.js          # /api/upload/*
│   │   └── admin.js           # /api/admin/* (protected)
│   │
│   ├── middleware/
│   │   ├── authenticate.js    # Require session/JWT
│   │   ├── adminOnly.js       # Admin role check
│   │   ├── rateLimiter.js     # express-rate-limit configs
│   │   ├── validateBody.js    # Joi schema validation wrapper
│   │   └── errorHandler.js    # Global error handler
│   │
│   ├── services/
│   │   ├── n8nWebhook.js      # Calls n8n webhooks (axios)
│   │   ├── fileUpload.js      # Cloudinary/S3 upload logic
│   │   └── registration.js    # Business logic layer
│   │
│   ├── validators/
│   │   └── registration.js    # Joi validation schemas
│   │
│   └── app.js                 # Express app setup
│
├── .env.example
├── Dockerfile
├── docker-compose.yml
└── package.json
```

---

## app.js — Core Setup

```js
const express = require('express');
const session = require('express-session');
const MongoStore = require('connect-mongo');
const passport = require('passport');
const helmet = require('helmet');
const cors = require('cors');
const { mongoUri, sessionSecret, clientOrigin } = require('./config/env');

require('./config/passport');

const app = express();

// Security headers
app.use(helmet());

// CORS — allow only your frontend origin
app.use(cors({
  origin: clientOrigin,
  credentials: true,
}));

app.use(express.json({ limit: '10kb' })); // Prevent large JSON body attacks

// Session (stored in MongoDB)
app.use(session({
  secret: sessionSecret,
  resave: false,
  saveUninitialized: false,
  store: MongoStore.create({ mongoUrl: mongoUri }),
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 1000 * 60 * 60 * 24, // 24 hours
  },
}));

app.use(passport.initialize());
app.use(passport.session());

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/registration', require('./routes/registration'));
app.use('/api/upload', require('./routes/upload'));
app.use('/api/admin', require('./routes/admin'));

// Global error handler (must be last)
app.use(require('./middleware/errorHandler'));

module.exports = app;
```

---

## config/passport.js — Google OAuth Strategy

```js
const passport = require('passport');
const { Strategy: GoogleStrategy } = require('passport-google-oauth20');
const User = require('../models/User');
const { googleClientId, googleClientSecret, backendUrl } = require('./env');

passport.use(new GoogleStrategy({
  clientID: googleClientId,
  clientSecret: googleClientSecret,
  callbackURL: `${backendUrl}/api/auth/google/callback`,
}, async (accessToken, refreshToken, profile, done) => {
  try {
    let user = await User.findOne({ googleId: profile.id });
    if (!user) {
      user = await User.create({
        googleId: profile.id,
        email: profile.emails[0].value,
        name: profile.displayName,
        picture: profile.photos[0]?.value,
      });
    } else {
      user.lastLogin = new Date();
      await user.save();
    }
    return done(null, user);
  } catch (err) {
    return done(err, null);
  }
}));

passport.serializeUser((user, done) => done(null, user._id));
passport.deserializeUser(async (id, done) => {
  try {
    const user = await User.findById(id);
    done(null, user);
  } catch (err) {
    done(err, null);
  }
});
```

---

## routes/auth.js

```js
const router = require('express').Router();
const passport = require('passport');

// Redirect to Google consent screen
router.get('/google',
  passport.authenticate('google', { scope: ['profile', 'email'] })
);

// Google callback
router.get('/google/callback',
  passport.authenticate('google', { failureRedirect: '/login?error=auth_failed' }),
  async (req, res) => {
    // Check if already registered — redirect to status page if so
    const Registration = require('../models/Registration');
    const existing = await Registration.findOne({ userId: req.user._id });
    if (existing) {
      return res.redirect(`${process.env.CLIENT_ORIGIN}/registration/status`);
    }
    res.redirect(`${process.env.CLIENT_ORIGIN}/register`);
  }
);

// Get current session user
router.get('/me', (req, res) => {
  if (!req.isAuthenticated()) return res.status(401).json({ error: 'Not authenticated' });
  res.json({
    id: req.user._id,
    email: req.user.email,
    name: req.user.name,
    picture: req.user.picture,
  });
});

// Logout
router.post('/logout', (req, res, next) => {
  req.logout((err) => {
    if (err) return next(err);
    req.session.destroy(() => res.json({ success: true }));
  });
});

module.exports = router;
```

---

## routes/registration.js

```js
const router = require('express').Router();
const authenticate = require('../middleware/authenticate');
const { registrationLimiter } = require('../middleware/rateLimiter');
const validate = require('../middleware/validateBody');
const { registrationSchema } = require('../validators/registration');
const registrationService = require('../services/registration');

// Submit registration
router.post('/',
  authenticate,
  registrationLimiter,
  validate(registrationSchema),
  async (req, res, next) => {
    try {
      const result = await registrationService.submit(req.user, req.body);
      res.status(201).json(result);
    } catch (err) {
      next(err);
    }
  }
);

// Get current user's registration status
router.get('/status', authenticate, async (req, res, next) => {
  try {
    const result = await registrationService.getStatus(req.user._id);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
```

---

## routes/upload.js

```js
const router = require('express').Router();
const multer = require('multer');
const authenticate = require('../middleware/authenticate');
const { uploadLimiter } = require('../middleware/rateLimiter');
const fileUploadService = require('../services/fileUpload');
const n8n = require('../services/n8nWebhook');

// Multer: memory storage, 5MB limit, images only
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
      return cb(new Error('Only JPEG, PNG, and WebP images are allowed'));
    }
    cb(null, true);
  },
});

router.post('/payment-screenshot',
  authenticate,
  uploadLimiter,
  upload.single('screenshot'),
  async (req, res, next) => {
    try {
      if (!req.file) return res.status(400).json({ error: 'No file provided' });

      const url = await fileUploadService.uploadPaymentScreenshot(
        req.file.buffer,
        req.file.mimetype,
        req.user._id.toString()
      );

      // Update registration record
      const Registration = require('../models/Registration');
      const reg = await Registration.findOneAndUpdate(
        { userId: req.user._id },
        { paymentScreenshotUrl: url, paymentStatus: 'pending' },
        { new: true }
      );

      if (!reg) return res.status(404).json({ error: 'Registration not found' });

      // Notify via n8n
      await n8n.paymentProof({
        registrationId: reg._id,
        email: req.user.email,
        name: req.user.name,
        courseType: reg.courseType,
        screenshotUrl: url,
      });

      res.json({ success: true, screenshotUrl: url });
    } catch (err) {
      next(err);
    }
  }
);

module.exports = router;
```

---

## routes/admin.js

```js
const router = require('express').Router();
const authenticate = require('../middleware/authenticate');
const adminOnly = require('../middleware/adminOnly');
const Registration = require('../models/Registration');
const { Parser } = require('json2csv');
const n8n = require('../services/n8nWebhook');

router.use(authenticate, adminOnly);

// List all registrations with optional filters
router.get('/', async (req, res, next) => {
  try {
    const filter = {};
    if (req.query.courseType) filter.courseType = req.query.courseType;
    if (req.query.paymentStatus) filter.paymentStatus = req.query.paymentStatus;

    const registrations = await Registration.find(filter)
      .populate('userId', 'email name picture')
      .sort({ createdAt: -1 });

    res.json(registrations);
  } catch (err) {
    next(err);
  }
});

// Verify a payment
router.patch('/:id/verify-payment', async (req, res, next) => {
  try {
    const reg = await Registration.findByIdAndUpdate(
      req.params.id,
      { paymentStatus: 'verified' },
      { new: true }
    ).populate('userId');

    if (!reg) return res.status(404).json({ error: 'Not found' });

    // Trigger Telegram group assignment + confirmation email via n8n
    await n8n.registration({
      registrationId: reg._id,
      userId: reg.userId._id,
      courseType: reg.courseType,
      email: reg.userId.email,
      name: reg.userId.name,
      firstNameEn: reg.firstNameEn,
      lastNameEn: reg.lastNameEn,
      githubUsername: reg.githubUsername,
      referralSource: reg.referralSource,
    });

    res.json({ success: true, registration: reg });
  } catch (err) {
    next(err);
  }
});

// Export to CSV
router.get('/export/csv', async (req, res, next) => {
  try {
    const registrations = await Registration.find()
      .populate('userId', 'email name');

    const fields = [
      { label: 'ID', value: '_id' },
      { label: 'Created At', value: 'createdAt' },
      { label: 'Email', value: 'userId.email' },
      { label: 'Name (EN)', value: (row) => `${row.firstNameEn} ${row.lastNameEn}` },
      { label: 'Name (KH)', value: (row) => `${row.firstNameKh} ${row.lastNameKh}` },
      { label: 'Course', value: 'courseType' },
      { label: 'Education', value: 'educationLevel' },
      { label: 'Year', value: 'academicYear' },
      { label: 'Major', value: 'major' },
      { label: 'GitHub', value: 'githubUsername' },
      { label: 'Experience', value: 'experienceLevel' },
      { label: 'Referral', value: 'referralSource' },
      { label: 'Payment Status', value: 'paymentStatus' },
    ];

    const parser = new Parser({ fields });
    const csv = parser.parse(registrations.map(r => r.toObject({ virtuals: false })));

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=registrations.csv');
    res.send(csv);
  } catch (err) {
    next(err);
  }
});

// Trigger Google Sheets sync
router.post('/export/sheets', async (req, res, next) => {
  try {
    await n8n.exportSheets();
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
```

---

## services/n8nWebhook.js

```js
const axios = require('axios');

const N8N_BASE = process.env.N8N_WEBHOOK_BASE_URL; // e.g. http://n8n:5678/webhook
const TOKEN = process.env.N8N_INTERNAL_TOKEN;

const headers = { 'X-Internal-Token': TOKEN };

const post = (path, data) =>
  axios.post(`${N8N_BASE}${path}`, data, { headers, timeout: 10000 });

module.exports = {
  authValidated: (data) => post('/auth-validated', data),
  registration: (data) => post('/registration', data),
  paymentProof: (data) => post('/payment-proof', data),
  exportSheets: () => post('/export-sheets', {}),
};
```

---

## Docker Compose

```yaml
version: '3.8'
services:
  backend:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - MONGO_URI=mongodb://mongo:27017/bootcamp
    depends_on:
      - mongo
    restart: unless-stopped

  mongo:
    image: mongo:7
    volumes:
      - mongo_data:/data/db
    restart: unless-stopped

  n8n:
    image: n8nio/n8n
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
    restart: unless-stopped

volumes:
  mongo_data:
  n8n_data:
```
