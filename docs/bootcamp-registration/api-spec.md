# API Specification

Base URL: `https://api.yourbootcamp.com` (or `http://localhost:3000` locally)

All endpoints return `application/json`. Auth-required endpoints need an active session cookie (set by Google OAuth flow).

---

## Authentication

### `GET /api/auth/google`
Initiates Google OAuth flow. Redirects user to Google consent screen.

**Query Params:** none  
**Response:** HTTP 302 redirect to Google

---

### `GET /api/auth/google/callback`
Google redirects here after consent. Sets session cookie and redirects to frontend.

**Success redirect:**
- If new user with no registration → `CLIENT_ORIGIN/register`
- If user already has registration → `CLIENT_ORIGIN/registration/status`

**Failure redirect:** `CLIENT_ORIGIN/login?error=auth_failed`

---

### `GET /api/auth/me`
Returns the current authenticated user.

**Auth:** Required  
**Response 200:**
```json
{
  "id": "664abc123...",
  "email": "user@gmail.com",
  "name": "Dara Chan",
  "picture": "https://lh3.googleusercontent.com/..."
}
```

**Response 401:**
```json
{ "error": "Not authenticated" }
```

---

### `POST /api/auth/logout`
Destroys the session and logs the user out.

**Auth:** Required  
**Response 200:**
```json
{ "success": true }
```

---

## Registration

### `POST /api/registration`
Submit a new bootcamp registration. Can only be called once per Google account.

**Auth:** Required  
**Rate Limit:** 5 requests per 15 minutes per IP  
**Content-Type:** `application/json`

**Request Body:**
```json
{
  "courseType": "live",

  "firstNameEn": "Dara",
  "lastNameEn": "Chan",
  "firstNameKh": "ដារ៉ា",
  "lastNameKh": "ចាន់",

  "educationLevel": "university",
  "academicYear": "year_2",
  "major": "Computer Science",

  "githubUsername": "darachan",
  "experienceLevel": "basic",

  "expectations": "I want to learn how to build REST APIs and deploy them.",

  "referralSource": "telegram"
}
```

**Validation Rules:**
| Field | Required | Type | Constraints |
|-------|----------|------|-------------|
| courseType | ✓ | string | `video` or `live` |
| firstNameEn | ✓ | string | max 50 chars |
| lastNameEn | ✓ | string | max 50 chars |
| firstNameKh | ✓ | string | max 50 chars |
| lastNameKh | ✓ | string | max 50 chars |
| educationLevel | ✓ | string | enum (see schema) |
| academicYear | | string | enum (see schema) |
| major | ✓ | string | max 100 chars |
| githubUsername | ✓ | string | GitHub username regex |
| experienceLevel | ✓ | string | enum (see schema) |
| expectations | ✓ | string | 10–2000 chars |
| referralSource | ✓ | string | enum (see schema) |

**Response 201:**
```json
{
  "registrationId": "664def456...",
  "courseType": "live"
}
```

**Response 409 — Already registered:**
```json
{ "error": "Already registered" }
```

**Response 422 — Validation error:**
```json
{
  "error": "Validation failed",
  "details": [
    { "field": "githubUsername", "message": "Invalid GitHub username format" }
  ]
}
```

---

### `GET /api/registration/status`
Returns the current user's registration and payment status.

**Auth:** Required  
**Response 200:**
```json
{
  "registrationId": "664def456...",
  "courseType": "live",
  "coursePrice": 49.99,
  "paymentStatus": "pending",
  "paymentScreenshotUrl": "https://res.cloudinary.com/...",
  "telegramGroupAssigned": null,
  "createdAt": "2026-06-17T08:00:00.000Z"
}
```

**Response 404 — No registration found:**
```json
{ "registered": false }
```

---

## File Upload

### `POST /api/upload/payment-screenshot`
Upload payment proof screenshot. Updates the registration record.

**Auth:** Required  
**Rate Limit:** 3 uploads per hour per user  
**Content-Type:** `multipart/form-data`

**Form Fields:**
| Field | Required | Type | Constraints |
|-------|----------|------|-------------|
| screenshot | ✓ | file | JPEG/PNG/WebP, max 5MB |

**Response 200:**
```json
{
  "success": true,
  "screenshotUrl": "https://res.cloudinary.com/yourapp/payment-screenshots/664abc_1718611200.jpg"
}
```

**Response 400 — No file / wrong type:**
```json
{ "error": "Only JPEG, PNG, and WebP images are allowed" }
```

**Response 404 — No registration yet:**
```json
{ "error": "Registration not found. Please complete the form first." }
```

---

## Admin Endpoints

All admin routes require authentication + `isAdmin: true` on the User document.

### `GET /api/admin`
List all registrations.

**Auth:** Admin  
**Query Params:**
- `courseType` — filter by `video` or `live`
- `paymentStatus` — filter by `unpaid | pending | verified | rejected`

**Response 200:** Array of registration objects (with populated `userId` field)

---

### `PATCH /api/admin/:id/verify-payment`
Mark a registration's payment as verified. Triggers Telegram group assignment + confirmation email via n8n.

**Auth:** Admin  
**Response 200:**
```json
{
  "success": true,
  "registration": { "...full registration object..." }
}
```

---

### `GET /api/admin/export/csv`
Download all registrations as a CSV file.

**Auth:** Admin  
**Response:** `text/csv` file download

---

### `POST /api/admin/export/sheets`
Trigger n8n to sync all registrations to Google Sheets.

**Auth:** Admin  
**Response 200:**
```json
{ "success": true }
```

---

## Error Response Format

All errors follow this format:

```json
{
  "error": "Human-readable error message",
  "details": [ ]   // optional, for validation errors
}
```

| HTTP Status | Meaning |
|-------------|---------|
| 400 | Bad request / invalid file |
| 401 | Not authenticated |
| 403 | Not authorized (not admin) |
| 404 | Resource not found |
| 409 | Conflict (e.g. duplicate registration) |
| 422 | Validation failed |
| 429 | Rate limit exceeded |
| 500 | Internal server error |
