# One Blood Connect — Node.js / Express API

REST API backend for the **One Blood Connect** Flutter app.  
Data is stored in **MongoDB** (Atlas or local). Authentication uses **Firebase Auth** — every request must carry a valid Firebase ID token.

---

## Stack

| Layer | Tech |
|---|---|
| Runtime | Node.js ≥ 18 |
| Framework | Express 4 |
| Database | MongoDB via Mongoose 8 |
| Auth | Firebase Admin SDK 12 |
| Dev server | nodemon |

---

## Quick start

### 1. Install dependencies
```bash
cd backend
npm install
```

### 2. Configure environment
Copy the example env file and fill in your values:
```bash
cp .env.example .env
```

`.env` fields:

| Key | Description |
|---|---|
| `MONGODB_URI` | MongoDB connection string. Local: `mongodb://localhost:27017/one_blood_connect`. Atlas: get from the Atlas dashboard → Connect → Drivers. |
| `PORT` | Port the server listens on (default `3000`). |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Path to the Firebase service-account JSON file for local development. |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Full service-account JSON contents; use as a secret environment variable on a hosting provider. Takes precedence over the file path. |

### 3. Get the Firebase service account key
1. Go to [Firebase Console](https://console.firebase.google.com) → your project → **Project Settings** → **Service Accounts**.
2. Click **Generate new private key** → download the JSON file.
3. Save it as `backend/firebase-service-account.json` (already git-ignored).

For a hosted deployment, set `FIREBASE_SERVICE_ACCOUNT_JSON` to the complete
contents of this file as a secret environment variable. Never commit the key or
include it in a mobile app.

### Provision or revoke an administrator

Administrator access is stored in the Firebase user's signed custom claims.
Only an authorized operator with access to the existing Firebase Admin SDK
credentials should run the provisioning tool. Obtain the user's Firebase UID
from a trusted Firebase Admin Console workflow, then run the command from the
`backend` directory using the existing `.env`/service-account configuration:

```bash
node scripts/manage-admin-role.js grant <FIREBASE_UID>
node scripts/manage-admin-role.js revoke <FIREBASE_UID>
```

The tool is a local/server-side command only; it is not invoked at application
startup and has no HTTP endpoint. It preserves unrelated custom claims and
refuses malformed or unknown existing role claims rather than replacing them.
Granting takes effect after the user refreshes their Firebase ID token. Revoking
removes the `admin` role and revokes that user's refresh tokens; the API checks
token revocation during authentication so previously issued tokens stop working.
The user must sign in again to receive a fresh token with the remaining roles.

### 4. Run

**Development** (auto-restarts on file change):
```bash
npm run dev
```

**Production**:
```bash
npm start
```

The server prints:
```
[Firebase] Admin SDK initialised
[MongoDB] Connected to one_blood_connect
[Server] Listening on http://localhost:3000
```

---

## API reference

All endpoints require:
```
Authorization: Bearer <Firebase ID token>
```

The Flutter `ApiService` class fetches this token automatically via `FirebaseAuth.instance.currentUser.getIdToken()`.

### Donors

| Method | Path | Description |
|---|---|---|
| `GET` | `/donors/me` | Get current user's donor profile |
| `POST` | `/donors/register` | Register as a donor (create/replace profile) |
| `PATCH` | `/donors/me` | Partially update donor profile |
| `GET` | `/donors/search?page=1&pageSize=25` | Search opted-in eligible donors (bounded pages) |

Donor search preserves the JSON-array response. `page` defaults to `1` and must
be between `1` and `10000`; `pageSize` defaults to `25` and is capped at `100`.
Ordering is newest first with MongoDB `_id` as a stable tie-breaker. Search is
rate-limited per authenticated Firebase UID (30 requests per 15 minutes by
default) and per Express-observed client IP (300 requests per 15 minutes by
default). These limits can be configured with
`DONOR_SEARCH_RATE_LIMIT_WINDOW_MS`, `DONOR_SEARCH_RATE_LIMIT_USER_MAX`, and
`DONOR_SEARCH_RATE_LIMIT_IP_MAX`.

The limiter stores counters in process memory. Limits are therefore per backend
process and are not shared across multiple instances; a shared store is needed
if coordinated limits across instances are required. Express does not trust
forwarded IP headers unless proxy trust is configured, so the IP key uses the
socket peer by default.

## Private image storage

New booking proofs, donor-request proofs, and donor profile photos are validated
and re-encoded with `sharp`, then written outside MongoDB. The API requires
`PRIVATE_FILE_STORAGE_PATH` to be set to a private, persistent directory before
image reads or writes can succeed. There is intentionally no built-in storage
path or public/static fallback. Choose the host-mounted Docker path separately;
the directory must be backed up and must not be web-served.

`PRIVATE_FILE_MAX_IMAGE_BYTES` sets the maximum input size per image (default
2,097,152 bytes). `PRIVATE_FILE_MAX_PROOF_BYTES` sets the combined input limit
for the two booking/request proof images (default 4,194,304 bytes). The global
JSON request parser remains limited to 8 MB. Only JPEG and PNG are accepted;
the server checks actual decoded content, enforces a 20-million-pixel ceiling,
re-encodes the image, and strips embedded metadata.

Image API responses contain availability flags, not image bytes. Clients fetch
images from authenticated record-scoped routes. Legacy Base64 data URIs remain
readable through those same authorization checks; no migration or deletion is
performed by the application code. `sharp` 0.35 requires Node.js 20.9 or newer;
confirm the backend container runtime supports it before deployment.

**POST /donors/register body:**
```json
{
  "fullName": "Rohan Sharma",
  "email": "rohan@example.com",
  "bloodGroup": "O+",
  "donationStream": "Whole Blood",
  "preScreeningAnswers": { "0": true, "1": false, "2": false, "3": false, "4": true },
  "readyAnyTime": true,
  "showToOthers": true,
  "lastDonationDate": "2024-06-15T00:00:00.000Z",
  "lastDonationUnits": 1
}
```

**PATCH /donors/me body** (any subset of):
```json
{
  "readyAnyTime": false,
  "showToOthers": true,
  "preferredVenue": "Hospital / Medical Center",
  "bloodGroup": "O+",
  "hospitalBookingActive": true,
  "bookingStatus": "confirmed"
}
```

---

### Blood Requests

| Method | Path | Description |
|---|---|---|
| `POST` | `/blood-requests` | Broadcast a new blood request |
| `GET` | `/blood-requests/my` | List all requests by current user |
| `GET` | `/blood-requests/:id` | Get a single request (for TrackRequestPage) |
| `PATCH` | `/blood-requests/:id/cancel` | Cancel a request |

**POST /blood-requests body:**
```json
{
  "patientName": "Rohan Sharma",
  "patientAge": 32,
  "patientGender": "Male",
  "bloodGroup": "O+",
  "units": 2,
  "component": "PRBC (Packed Red)",
  "urgency": "Critical Red",
  "hospital": "JIPMER Super Speciality Hospital",
  "ward": "ICU Tower B",
  "bedNumber": "Bed #14",
  "hubZone": "JIPMER / Gorimedu",
  "attender": "Ananya Sharma (Sister)",
  "contactPhone": "9842170920",
  "emergencyPushEnabled": true,
  "notifyNss": true
}
```

**Response includes `_id`** — pass this to `TrackRequestPage(requestId: ...)`.

**Request status lifecycle:**
```
pending → received → verifying → preparing → ready → fulfilled
                                                    ↘ cancelled
```

---

### Bookings

| Method | Path | Description |
|---|---|---|
| `POST` | `/bookings` | Create a hospital slot booking |
| `GET` | `/bookings/active` | Get current user's active booking |
| `GET` | `/bookings/:id` | Get a specific booking |
| `PATCH` | `/bookings/:id/cancel` | Cancel a booking |

**POST /bookings body:**
```json
{
  "facilityName": "JIPMER Central Blood Bank Hub",
  "facilityAddress": "Super Specialty Block, JIPMER, Pondicherry",
  "facilityPhone": "+91 413 229 6000",
  "slotDate": "2024-10-20T10:30:00.000Z",
  "slotTime": "10:30 AM",
  "donorName": "Rohan Sharma",
  "bloodGroup": "O+"
}
```

**GET /bookings/active response:**
```json
{ "active": true, "booking": { "_id": "...", "bookingRef": "OBC-APP-2024-4231", ... } }
// or
{ "active": false }
```

---

## Flutter integration

All three apps accept their shared backend URL through the `API_BASE_URL`
compile-time define. For production APKs, build with the hosted HTTPS URL:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com
```

The default remains `http://10.0.2.2:3000` for Android emulator development.
For deployment steps and the build commands for all three apps, see the
project's [deployment guide](../DEPLOYMENT.md).

---

## Project structure

```
backend/
├── src/
│   ├── config/
│   │   ├── db.js          # MongoDB connection
│   │   └── firebase.js    # Firebase Admin SDK init
│   ├── middleware/
│   │   └── auth.js        # Firebase token verification
│   ├── models/
│   │   ├── Donor.js
│   │   ├── BloodRequest.js
│   │   └── Booking.js
│   ├── routes/
│   │   ├── donors.js
│   │   ├── bloodRequests.js
│   │   └── bookings.js
│   └── index.js           # Entry point
├── .env.example
├── .gitignore
└── package.json
```
