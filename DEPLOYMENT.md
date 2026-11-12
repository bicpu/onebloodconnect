# Deploying the API and building phone APKs

The three Flutter apps use one shared API. Deploy that API publicly over HTTPS
so phones can connect from any network; do not use `10.0.2.2`, a LAN IP, or a
developer computer address in distributed APKs.

## 1. Create a MongoDB Atlas database

1. Create an Atlas cluster and a database user.
2. In Atlas Network Access, allow connections from Render. For a quick initial
   setup, `0.0.0.0/0` allows Render's changing outbound IPs; use database
   credentials with a strong password and restrict access further if you have
   static outbound IPs or private networking.
3. Copy the application's MongoDB connection string. Include the database name
   `one_blood_connect` and replace the username/password placeholders.

## 2. Deploy the API to Render

1. Push this project to a GitHub repository and create a new Render Blueprint
   using the repository's `render.yaml`.
2. Set `MONGODB_URI` to the Atlas connection string.
3. Set `FIREBASE_SERVICE_ACCOUNT_JSON` to the full contents of a Firebase
   service-account JSON key for the same Firebase project used by the apps.
   Keep this value in Render's secret environment settings; never commit the
   key or put it in an APK.
4. Deploy the service. Render provides a URL such as
   `https://one-blood-connect-api.onrender.com`. Check that opening
   `https://<your-render-host>/health` returns `{"status":"ok"}`.

The Firebase service-account key is a server-only credential. The mobile apps
continue to sign in using Firebase Auth and send their Firebase ID tokens to the
API, which verifies them using this key.

## 3. Build the three APKs

Run each command from the project root, replacing the example host with the
actual HTTPS URL assigned by Render (without a trailing slash):

```sh
flutter build apk --release \
  --dart-define=API_BASE_URL=https://one-blood-connect-api.onrender.com

cd admin
flutter build apk --release \
  --dart-define=API_BASE_URL=https://one-blood-connect-api.onrender.com

cd ../blood_bank_app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://one-blood-connect-api.onrender.com
```

The APKs are created at:

- `build/app/outputs/flutter-apk/app-release.apk`
- `admin/build/app/outputs/flutter-apk/app-release.apk`
- `blood_bank_app/build/app/outputs/flutter-apk/app-release.apk`

Share/install those release APKs on the phones. All users can reach the same
hosted API regardless of their Wi-Fi or mobile network. Android emulator
debugging still defaults to `http://10.0.2.2:3000` when no
`API_BASE_URL` is provided.

For production distribution, configure Android app signing before sharing
updates. A Render free instance may sleep when idle, so its first request after
inactivity can take longer; choose an always-on plan if that is unacceptable.
