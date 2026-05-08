# Firebase Cloud Messaging (FCM) Push Notifications - Setup Guide

This document outlines the remaining steps to fully configure Firebase Cloud Messaging for your eHarvest Flutter application.

## Files Created/Modified

### ✅ Already Implemented
1. **pubspec.yaml** - Added dependencies:
   - `firebase_core: ^3.0.0`
   - `firebase_messaging: ^15.0.0`
   - `flutter_local_notifications: ^18.0.0`

2. **lib/services/notification_api_service.dart** - API service for:
   - `registerToken()` - POST to `/api/notifications/register-token`
   - `deactivateToken()` - DELETE to `/api/notifications/deactivate-token`

3. **lib/services/notification_service.dart** - Main notification handler with:
   - `init()` - Firebase initialization, permissions, token registration
   - `setupListeners()` - Handles foreground, background, and terminated states
   - `showLocalNotification()` - Displays popup notifications
   - `deleteToken()` - Token cleanup on logout

4. **lib/firebase_options.dart** - Firebase configuration template (needs to be generated)

5. **android/app/src/main/AndroidManifest.xml** - Added POST_NOTIFICATIONS permission

6. **lib/main.dart** - Added NotificationService.init() call

7. **lib/services/auth_service.dart** - Updated logout() to call NotificationService.deleteToken()

---

## Remaining Setup Steps

### Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" and enter your project name
3. Choose your Google Cloud Platform (GCP) resources location
4. Enable Google Analytics (optional but recommended)
5. Click "Create project" and wait for it to complete

### Step 2: Generate Firebase Configuration Files

#### Using FlutterFire CLI (Recommended)

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Run configuration command in your project root:
   ```bash
   flutterfire configure
   ```

3. When prompted, select your Firebase project and platforms (Android/iOS)
4. This automatically generates/updates `lib/firebase_options.dart` with your credentials

#### Manual Configuration (if FlutterFire CLI doesn't work)

**For Android:**
1. Go to Firebase Console → Project Settings
2. Click "Add App" → Select Android
3. Enter package name: `com.eharvest.mobile`
4. Download `google-services.json`
5. Place it at: `android/app/google-services.json`

**For iOS:**
1. Click "Add App" → Select iOS
2. Enter bundle ID: `com.eharvest.mobile`
3. Download `GoogleService-Info.plist`
4. Open iOS project in Xcode and add the plist file to Runner project

### Step 3: Enable Firebase Messaging in Console

1. In Firebase Console, go to **Cloud Messaging** (under Engage)
2. Verify FCM API is enabled
3. Note your **Sender ID** (Server Sender ID) - you'll need this for backend integration

### Step 4: Update gradle Files

The FlutterFire CLI handles this, but verify these are set:

**android/build.gradle.kts** (project level):
```kotlin
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

**android/app/build.gradle.kts** (app level):
```kotlin
plugins {
    id 'com.google.gms.google-services'
}
```

### Step 5: Install Dependencies

Run the following commands:
```bash
flutter pub get
flutter pub upgrade
```

### Step 6: iOS-Specific Setup (if building for iOS)

If you're targeting iOS, complete these steps:

1. **Enable Push Notifications Capability** in Xcode:
   - Open `ios/Runner.xcworkspace` (not the .xcodeproj)
   - Select Runner project → Runner target
   - Go to "Signing & Capabilities"
   - Click "+ Capability" and add "Push Notifications"

2. **Update Podfile** if needed (usually FlutterFire handles this):
   - Open `ios/Podfile`
   - Ensure `firebase_messaging` post_install hook is present

3. **Create APNs Key** (for production):
   - In Apple Developer Portal, create an APNs key
   - Upload to Firebase Console → Project Settings → Cloud Messaging tab

### Step 7: Backend API Integration

Your backend needs to implement these two endpoints:

#### POST `/api/notifications/register-token`
**Request Body:**
```json
{
  "userId": "123",
  "fcmToken": "abcd1234...",
  "deviceType": "android"
}
```
**Response:** 200/201 on success

**Purpose:** Store the FCM token on the backend so you can send notifications to this device.

#### DELETE `/api/notifications/deactivate-token`
**Request Body:**
```json
{
  "fcmToken": "abcd1234..."
}
```
**Response:** 200/204 on success

**Purpose:** Remove the token when user logs out so no notifications are sent to the old device.

### Step 8: Test FCM Setup

1. Run your app:
   ```bash
   flutter run
   ```

2. Check the console logs for messages like:
   - `FCM token registered successfully`
   - You should see your FCM token printed

3. Send a test notification from Firebase Console:
   - Go to Cloud Messaging → Send first message
   - Enter a notification title and body
   - Select your app
   - Click "Send"

### Step 9: Handle Notification Taps (Optional)

Currently, notification tap navigation is handled in `NotificationService._handleMessageNavigation()`. 
You can customize this based on your app's needs:

**Example:** Navigate to orders page when user taps an order notification:
```dart
static void _handleMessageNavigation(RemoteMessage message) {
  final Map<String, dynamic> data = message.data;
  
  if (data.containsKey('type') && data['type'] == 'order') {
    // Your navigation logic here
    navigatorKey.currentState?.pushNamed('/orders');
  }
}
```

---

## Notification Flow

### Foreground (App is Open)
1. User receives notification while using the app
2. FCM triggers `FirebaseMessaging.onMessage` listener
3. `flutter_local_notifications` shows a popup

### Background (App is Minimized)
1. User receives notification while app is not in foreground
2. FCM automatically displays the notification
3. When user taps, app resumes and `setupListeners()` is triggered

### Terminated (App is Closed)
1. User receives notification with app fully closed
2. FCM displays the notification in notification center
3. When user taps, app launches and `FirebaseMessaging.onMessageOpenedApp` listener fires
4. Navigation logic is triggered based on message data

---

## Troubleshooting

### Issue: Token not registering
- **Check:** User denied notification permissions
- **Solution:** App gracefully skips token registration if denied, but you should prompt user to enable in settings

### Issue: Notifications not received
- **Check:** Backend is sending notifications with correct FCM tokens
- **Check:** Firebase project is properly configured
- **Check:** google-services.json is in the correct location (android/app/)

### Issue: App crashes on startup
- **Check:** `firebase_options.dart` has valid configuration
- **Check:** All dependencies are properly installed (`flutter pub get`)
- **Check:** Run `flutter clean` and `flutter pub get` again

### Issue: "MissingPluginException"
- **Solution:** Run `flutter clean` then rebuild
- **Solution:** On Android: `./gradlew clean` in android folder

---

## Architecture Overview

```
main.dart
  └── NotificationService.init()
      ├── Firebase.initializeApp()
      ├── _flutterLocalNotificationsPlugin.initialize()
      ├── _firebaseMessaging.requestPermission()
      ├── _registerTokenWithBackend()
      │   └── NotificationApiService.registerToken()
      └── setupListeners()
          ├── FirebaseMessaging.onMessage (Foreground)
          ├── FirebaseMessaging.onMessageOpenedApp (Terminated)
          └── FirebaseMessaging.onBackgroundMessage (Background)
```

**On Logout:**
```
AuthService.logout()
  └── NotificationService.deleteToken()
      ├── NotificationApiService.deactivateToken()
      └── _firebaseMessaging.deleteToken()
```

---

## Security Notes

- ✅ FCM tokens are automatically rotated by Firebase
- ✅ Tokens are stored locally and cleared on logout
- ✅ API calls use the standard `api` base URL from global_variables.dart
- ✅ Graceful error handling prevents app crashes if Firebase initialization fails
- ✅ User permission denial is handled gracefully

---

## Next Steps

1. **Run `flutterfire configure`** to generate your Firebase configuration
2. **Update backend** to implement the two notification endpoints
3. **Test the integration** by sending a test notification
4. **Customize notification handling** in `_handleMessageNavigation()` based on your requirements
