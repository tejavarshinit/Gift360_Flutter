# gift360

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase Cloud Messaging

The app initializes Firebase from the platform's default Firebase configuration
and handles FCM messages through `firebase_messaging`, displaying foreground
messages with `flutter_local_notifications`.

Before testing push notifications:

1. Create/configure the app in Firebase Console and run `flutterfire configure`
   for this Firebase project. Add the generated Android
   `android/app/google-services.json` and iOS
   `ios/Runner/GoogleService-Info.plist`. The Android Google Services Gradle
   plugin is applied when `google-services.json` is present. Do not commit
   service-account or Firebase Admin credentials.
2. Web builds need the Firebase web SDK values in `.env`:
   `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`,
   `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_PROJECT_ID` (optional:
   `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, and
   `FIREBASE_MEASUREMENT_ID`). Configure `FIREBASE_WEB_VAPID_KEY` with the Web
   Push certificate key from Firebase Console and add a Firebase Messaging
   service worker at `web/firebase-messaging-sw.js` for the same project. The
   Dart app reads these public Firebase web options to initialize FlutterFire.
3. Configure `NOTIFICATION_API_URL` in the selected `.env` file or with
   `--dart-define=NOTIFICATION_API_URL=...`. It defaults to
   `http://localhost:8081`. Android emulators need a host-reachable URL such as
   `http://10.0.2.2:8081`; physical devices need the backend's reachable LAN or
   HTTPS address. Set the production API URL in the production environment;
   this repository does not supply one.
4. Enable Push Notifications for the iOS app in Xcode, add the Push
   Notifications capability and APNs key in Apple/Firebase configuration, and
   use a valid signing team/profile. Android 13+ requests runtime notification
   permission; the app creates the `karatly_default` channel.

After sign-in the app registers the current FCM token against the authenticated
profile's `clientId`. Failed registrations are logged and retried on app
resume. Logout does not unregister the old token because the backend has no
unregister endpoint.

## Biometric login

Biometric login is optional and is enabled from the signed-in profile after
normal OTP authentication. The app uses the HTTPS host configured by
`BRAND_API_URL` for the ValueDesign `/api/v1/auth/biometric` gateway routes.
The Android manifest declares `USE_BIOMETRIC`; Android uses AndroidX
`BiometricPrompt` and a hardware-backed Android Keystore RSA key. iOS uses
Keychain-protected RSA with the current biometric set and requires a device
passcode; `NSFaceIDUsageDescription` explains the Face ID prompt. RSA signing
is unavailable in the iOS Secure Enclave, so the private key is protected by
Keychain access control and is never exported.

Biometric enrollment is device- and account-bound. Logout retains that
enrollment; disabling it requires a successful gateway revoke before the
local key and metadata are removed. A missing or invalidated key requires
normal OTP login and recovery from the profile.

The gateway deployment must prevent direct client access to the sibling auth
service's register/revoke routes. Its in-memory challenge store also requires
challenge issuance and login to reach the same auth-service instance; use
sticky routing or shared challenge storage in multi-instance deployments.
The application repository cannot verify these server-side routing guarantees.
