# Gift360 developer notes

## First-login SuperCoin reward

After an authenticated login or registration, `AppInstallRewardService` calls
`POST /api/v1/supercoin/first-login-reward` through the configured
ValueDesign API client. It sends a random UUID persisted in secure storage as
`gift360_device_id`; it does not read a hardware identifier. The backend is
the source of truth and awards at most once per account. The success dialog
appears only when the API confirms `status: credited`.

The backend migration `V58__first_login_supercoin_rewards.sql` must be applied
before enabling this feature. Eligibility is controlled by the backend
campaign-start setting and the customer's profile. If the external credit is
pending reconciliation, the app does not show a success dialog.

On Android, `MainActivity.kt` exposes `Settings.Secure.ANDROID_ID` over the
`gift360/device_id` MethodChannel. The app hashes that value before sending a
stable UUID-shaped identifier to the backend. On other platforms it stores a
random UUID in secure storage.

## Firebase Cloud Messaging

Firebase initialization and message handling are in `lib/main.dart` and the
push notification service. Notification permission is requested through
Firebase Messaging, including Android 13+ runtime permission handling. The
FCM token is retrieved and printed only in debug builds for testing; it is not
sent to the backend. Foreground notifications, notification taps, and
terminated-state notification launches retain their existing handling.

Configure the platform Firebase files for the Firebase project before
building. Do not commit Firebase Admin service-account credentials.
