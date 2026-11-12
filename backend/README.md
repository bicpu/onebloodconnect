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
