# Familator iOS

Native iOS app for Familator—todo lists, routines, dashboard, and profile—using SwiftUI and Supabase (no Next.js dependency).

## Requirements

- Xcode 15+
- iOS 16+
- Supabase project
- For Google Sign-In: Google Cloud iOS OAuth client and Supabase Dashboard configured

## Setup

### 1. Open the project in Xcode

- **Option A (recommended):** If you have [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed:
  ```bash
  xcodegen generate
  open Familator.xcodeproj
  ```
- **Option B:** Create a new iOS App project in Xcode:
  1. File → New → Project → iOS → App
  2. Product Name: **Familator**, Interface: **SwiftUI**, Language: **Swift**
  3. Save in the repo root (so the project is `Familator.xcodeproj`)
  4. Delete the default `ContentView.swift` and add the existing `Familator` folder: File → Add Files to "Familator" → select the `Familator` folder (Create groups, Copy items if needed unchecked)
  5. Add Swift Package dependencies:
     - File → Add Package Dependencies
     - Add **Supabase**: `https://github.com/supabase/supabase-swift` (version 2.0.0 or later)
     - Add **GoogleSignIn**: `https://github.com/google/GoogleSignIn-iOS` (version 8.0 or later)
  6. Link the app target to **Supabase** and **GoogleSignIn**
  7. Set the app target’s **Info** tab (or Info.plist) so that:
     - **Bundle Identifier** is e.g. `com.familator.app`
     - **Custom iOS Target Properties** include:
       - `SUPABASE_URL`: your Supabase project URL (e.g. `https://xxx.supabase.co`)
       - `SUPABASE_ANON_KEY`: your Supabase anon/public key
       - `GOOGLE_CLIENT_ID`: your Google iOS OAuth client ID (optional; omit or leave empty to hide “Sign in with Google”)

### 2. Supabase

The app connects directly to your Supabase project. No schema changes are required; it uses the same tables and RLS as the web app.

- **SUPABASE_URL**: find this in the Supabase Dashboard → Settings → API → Project URL
- **SUPABASE_ANON_KEY**: find this in the Supabase Dashboard → Settings → API → Project API keys → `anon` `public`

Set these in the app’s Info.plist (or in a xcconfig / scheme) so `AppConfig` can read them. For release, use a non-committed config (e.g. xcconfig that’s in `.gitignore`).

### 3. Google Sign-In (optional)

To enable “Sign in with Google”:

1. **Google Cloud Console**
   - Create an **iOS** OAuth 2.0 Client ID.
   - Use your app’s **Bundle ID** (e.g. `com.familator.app`).
   - No redirect URI is required for the native SDK.

2. **Supabase Dashboard**
   - Authentication → Providers → Google: enable and add:
     - **Client ID (for OAuth)**: enter **both** your Web client ID and your iOS client ID, separated by a comma (e.g. `web-id.apps.googleusercontent.com,ios-id.apps.googleusercontent.com`). This lets Supabase accept ID tokens from the iOS app and avoids "Unacceptable audience in id_token" errors.
     - **Client Secret**: your **Web** client's secret.

3. **App**
   - Set **GOOGLE_CLIENT_ID** in Info.plist (or Config.xcconfig) to your **iOS** OAuth client ID (the one you created with application type “iOS”, not the Web client).
   - Set **GOOGLE_URL_SCHEME** to the reversed client ID (e.g. `com.googleusercontent.apps.981867394136-xxxx`) so the app can receive the OAuth callback. Add it to Config.xcconfig; the scheme is `com.googleusercontent.apps.` + the part of your **iOS** client ID before `.apps.googleusercontent.com`.

**Important:** If you see “Custom scheme URIs are not allowed for 'WEB' client type”, you are using the **Web** OAuth client ID in the app. The iOS app must use the **iOS** client ID. Create an iOS OAuth 2.0 Client in Google Cloud Console (APIs & Services → Credentials → Create Credentials → OAuth client ID → Application type: **iOS**), set your bundle ID, then put that client ID in `GOOGLE_CLIENT_ID` and use its reversed form in `GOOGLE_URL_SCHEME`.

**Config not applied:** If the app tries to reach `your-project.supabase.co` or you see "hostname could not be found", values from `Config.xcconfig` are not in the build. Ensure `Config.xcconfig` exists in the repo root with real values (and `SUPABASE_URL` in quotes), then **Product → Clean Build Folder** (⇧⌘K) and run again. Under the project’s **Info** tab, Debug/Release should show Config.xcconfig as the base configuration.

## Run

1. Select the **Familator** scheme and a simulator or device.
2. Build and run (⌘R).

Sign in with email/password or Google (if configured).

## Features

- **Auth:** Email/password and Google Sign-In via Supabase Auth.
- **Dashboard:** Favorites, urgent & due tasks, due routines.
- **Todo:** Lists, filters (Today, Due now, Upcoming, Next week, Recurring), tasks with subtasks, create/edit lists and tasks.
- **Today:** Today list and due routines with complete actions.
- **Profile:** Display name, email, avatar, sign out.

Calendar is not included; the app does not use Google Calendar.
