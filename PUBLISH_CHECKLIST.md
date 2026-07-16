# Play Store Publishing Checklist

## Prerequisites
- [ ] Google Play Developer account ($25 one-time fee)
- [ ] App icon in `assets/icon/app_icon.png` (1024x1024 px)
- [ ] Feature graphic (1024x500 px) for store listing
- [ ] Screenshots (at least 2: phone 1080x1920, tablet 1080x1920 or 2000x1200)
- [ ] Privacy policy (hosted on a public URL - use https://privacypolicies.com or host on GitHub Pages)

## Step 1: Change Package Name (Avoid "com.example")
The app currently uses `com.example.expense_tracker`. You MUST change this before publishing.

### In `android/app/build.gradle`:
- Line 26: `namespace "com.yourname.expensetracker"`
- Line 46: `applicationId "com.yourname.expensetracker"`

### In `android/app/src/main/AndroidManifest.xml`:
- Line 2: `package="com.yourname.expensetracker"`

### In `android/app/src/profile/AndroidManifest.xml`:
- Line 2: `package="com.yourname.expensetracker"`

### In `android/app/src/debug/AndroidManifest.xml` (if it exists):
- Update package name

### In `ios/Runner.xcodeproj/project.pbxproj`:
- Search for `com.example.expenseTracker` and replace with `com.yourname.expensetracker`

### In `ios/Runner/Info.plist`:
- Update `CFBundleIdentifier` if needed

### Update app display name:
- **Android**: `android/app/src/main/AndroidManifest.xml` → `android:label="Expense Tracker"`
- **iOS**: `ios/Runner/Info.plist` → `CFBundleDisplayName`

## Step 2: Update App Version
In `pubspec.yaml`:
- Line 4: `version: 1.0.0+1` (first is version name, second +1 is version code)
- Increment version code each build: `1.0.0+2`, `1.0.0+3`, etc.
- Change version name for releases: `1.1.0+4`, `2.0.0+5`, etc.

## Step 3: Generate Keystore
Run this command (replace placeholders):
```
keytool -genkey -v -keystore H:\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## Step 4: Create Signing Config
`android/app/build.gradle` already reads the keystore — there is no Gradle edit
left to make. Create `android/key.properties` and the release build picks it up:
```
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=upload
storeFile=H:\\upload-keystore.jks
```

`key.properties`, `*.jks` and `*.keystore` are gitignored — never commit them.

**Without** this file the release build falls back to the **debug key** so a
plain checkout still builds. That fallback only warns under
`flutter build --verbose`, so confirm what actually signed the artifact before
uploading:
```
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```
`CN=Android Debug` means it is debug-signed and Play will reject it.

## Step 5: Build Release App Bundle (Recommended)
```
flutter clean
flutter pub get
flutter build appbundle --obfuscate --split-debug-info=build/debug-info
```
This generates: `build/app/outputs/bundle/release/app-release.aab`

### Alternative: Build APK
```
flutter build apk --obfuscate --split-debug-info=build/debug-info
```
This generates: `build/app/outputs/flutter-apk/app-release.apk`

## Step 6: Google Play Console Setup
1. Go to https://play.google.com/console/
2. Create new app → select name, default language, app or game, free or paid
3. Fill in **Store listing**:
   - App name (max 50 chars)
   - Short description (max 80 chars)
   - Full description (max 4000 chars)
   - Screenshots (at least 2 phone + 2 tablet + 1 feature graphic)
   - App icon (512x512 px, 32-bit PNG)
   - Feature graphic (1024x500 px)
   - Categorization (Finance → Expense Tracking)
   - Contact details (email, website)
   - Privacy policy URL

## Step 7: App Content
- **Ratings**: Complete the ratings questionnaire
- **Target audience**: All ages / Everyone (check if financial content requires maturity)
- **News apps**: No (unless you publish news)
- **Ads**: No (this app has no ads)
- **Data safety**: Fill in - the app collects NO personal data, NO financial data is sent externally. All data stored locally on device.

## Step 8: Production Track
1. Go to "Production" under "Release" in Play Console
2. Create new release
3. Upload the `.aab` file
4. Fill in release notes (e.g., "Initial release - Track your daily expenses with ease")
5. Save and review

## Step 9: Final Review & Publish
1. Review all store listing info
2. Confirm pricing & distribution (free for all countries)
3. Submit for review
4. Wait 1-3 days for Google's review

## Build Commands Reference

```bash
# Clean build
flutter clean
flutter pub get

# Generate Hive adapters (if models change)
dart run build_runner build --delete-conflicting-outputs

# Debug run
flutter run

# Release app bundle (Play Store)
flutter build appbundle --obfuscate --split-debug-info=build/debug-info --target-platform android-arm,android-arm64

# Release APK (direct distribution)
flutter build apk --obfuscate --split-debug-info=build/debug-info --split-per-abi

# Test release build locally
flutter build apk --debug
```

## Files to Delete Before Publishing
- [x] `lib/routes/` → empty directory (already deleted)

Nothing else needs deleting. `README.md` and `docs/index.html` are developer
documentation — they are not bundled into the APK/AAB (only `assets/` declared in
`pubspec.yaml` ships), so they cost nothing at publish time. Keep them.

`PRIVACY_POLICY.md` was deleted, but note the Prerequisites above still require a
**hosted** privacy policy URL for the Play listing.

## Security Checklist
- [x] No internet permission in AndroidManifest
- [x] No analytics or tracking SDKs
- [x] All data stored locally via Hive
- [x] No hardcoded secrets or API keys
- [x] Currency setting persisted via SharedPreferences
- [x] Input validation on amount fields
- [x] ProGuard/R8 minification enabled
- [x] Flutter obfuscation enabled
