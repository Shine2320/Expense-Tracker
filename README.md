# 💰 Expense Tracker

A modern personal expense tracking mobile app built with Flutter, featuring Material 3 UI, Riverpod state management, and Hive local storage.

## 📱 Screenshots

*(Coming soon)*

## ✨ Features

- **Dashboard** - View monthly salary, balance, expenses chart, and recent transactions
- **Calendar View** - Browse expenses by date with highlighted days
- **Expense List** - All expenses grouped by date with swipe-to-delete
- **Add/Edit Expenses** - Quick modal sheet with name, amount, date picker, and category selection
- **Month Summary** - Full monthly expense list with category pie chart
- **Settings** - Edit salary, carry-over balance, manage categories, toggle theme
- **Categories** - 10 default categories + ability to add custom categories with emojis
- **Light & Dark Mode** - Material 3 theming with automatic color scheme generation

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| **Framework** | Flutter 3.16+ |
| **State Management** | Riverpod |
| **Local Storage** | Hive |
| **Charts** | fl_chart |
| **Calendar** | table_calendar |
| **Theme** | Material 3 |
| **Min Android** | 13 (API 33) |

## 📋 Prerequisites

Before running the project, ensure you have the following installed:

| Requirement | Version |
|-------------|---------|
| **Flutter SDK** | 3.16.5 or higher |
| **Dart** | 3.2.3 or higher |
| **Java JDK** | 21 or higher |
| **Android SDK** | API 33+ (Android 13) |
| **Android Studio** | Latest version recommended |

### Verify Installation

```bash
flutter doctor
```

Ensure all checks pass, especially:
- [✓] Flutter
- [✓] Android toolchain
- [✓] Android Studio (or VS Code)
- [✓] Connected device

## 🚀 Setup & Run

### 1. Clone or Download

The project is already in your `H:\Expense Tracker` directory.

### 2. Install Dependencies

```bash
cd "H:\Expense Tracker"
flutter pub get
```

### 3. Generate Hive Adapters

```bash
dart run build_runner build --delete-conflicting-outputs
```

This generates the required `.g.dart` files for Hive data models.

### 4. Run on Android Device/Emulator

```bash
# Connect an Android device or start an emulator, then:
flutter run
```

### 5. Build Release APK

```bash
flutter build apk --release
```

The APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── app.dart                           # MaterialApp configuration
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # Color constants
│   │   ├── app_spacing.dart           # Spacing constants
│   │   └── app_strings.dart           # String constants
│   ├── theme/
│   │   └── app_theme.dart             # Light & dark themes
│   └── utils/
│       ├── currency_formatter.dart    # Currency formatting
│       └── date_utils.dart            # Date utilities
├── data/
│   ├── models/
│   │   ├── expense_model.dart         # Expense data model
│   │   ├── category_model.dart        # Category data model
│   │   └── monthly_balance_model.dart # Balance data model
│   ├── repositories/
│   │   ├── expense_repository.dart    # Expense CRUD operations
│   │   ├── category_repository.dart   # Category management
│   │   └── balance_repository.dart    # Balance calculations
│   └── datasources/
│       └── hive_storage.dart          # Hive initialization
├── presentation/
│   ├── providers/
│   │   ├── expense_provider.dart      # Expense state
│   │   ├── category_provider.dart     # Category state
│   │   ├── balance_provider.dart      # Balance state
│   │   ├── calendar_provider.dart     # Calendar state
│   │   └── theme_provider.dart        # Theme state
│   ├── screens/
│   │   ├── home/
│   │   │   └── home_shell.dart        # Bottom navigation shell
│   │   ├── dashboard/                 # Home screen
│   │   ├── calendar/                  # Calendar screen
│   │   ├── expenses/                  # Expense list screen
│   │   ├── add_expense/               # Add/edit expense modal
│   │   ├── month_summary/             # Monthly summary screen
│   │   └── settings/                  # Settings screen
│   └── widgets/                       # Reusable widgets
└── routes/                            # Navigation routes
```

## 📊 How It Works

### Balance Calculation

```
Available Balance = Monthly Salary + Previous Month Carry-over
Total Expenses    = Sum of all expenses for the month
Remaining Balance = Available Balance - Total Expenses
```

At month end, the remaining balance automatically carries over to the next month.

### Data Persistence

All data is stored locally using Hive, a fast NoSQL database:
- **Expenses** - Stored individually with date, category, and amount
- **Categories** - 10 default categories + user-created custom ones
- **Monthly Balances** - Auto-generated per month (format: `YYYY-MM`)

## 🎨 Customization

### Change Default Categories

Edit `lib/data/models/category_model.dart`:

```dart
static List<CategoryModel> defaultCategories() {
  return [
    CategoryModel(id: 'food', name: 'Food & Dining', emoji: '🍔'),
    // Add or modify categories here
  ];
}
```

### Change Currency Symbol

Currency is set to Indian Rupee (₹) by default. To change it, edit `lib/core/utils/currency_formatter.dart`:

```dart
static String format(double amount) {
  return NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN').format(amount);
}
```

### Change App Icon

1. Place your icon image (PNG, 1024x1024 recommended) in `assets/icon/`
2. Update `pubspec.yaml` with your icon filename:

```yaml
flutter_launcher_icons:
  android: true
  image_path: "assets/icon/your_icon.png"
  adaptive_icon_background: "#6750A4"
  adaptive_icon_foreground: "assets/icon/your_icon.png"
```

3. Generate icons:

```bash
flutter pub run flutter_launcher_icons
```

## 🐛 Troubleshooting

### Gradle Build Fails

```bash
# Clean and rebuild
cd android && gradlew clean
flutter clean
flutter pub get
flutter run
```

### Hive Adapter Regeneration

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Flutter Doctor Issues

```bash
flutter doctor --android-licenses
flutter upgrade
```

## 📝 Dependencies

| Package | Purpose |
|---------|---------|
| flutter_riverpod | State management |
| hive_flutter | Local database |
| table_calendar | Calendar UI |
| fl_chart | Charts & graphs |
| uuid | Unique ID generation |
| intl | Date & currency formatting |

## 🚀 Play Store Publishing Guide

### Pre-Release Checklist

1. **Change Package Name**
   ```
   Edit android/app/build.gradle:
   applicationId "com.yourname.expensetracker"
   ```

2. **Generate Upload Keystore**
   ```bash
   keytool -genkey -v -keystore expense-tracker-key.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias expense-tracker
   ```

3. **Configure Signing**
   Create `android/key.properties`:
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=expense-tracker
   storeFile=<path-to-keystore>
   ```

   Update `android/app/build.gradle`:
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }
   
   android {
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile file(keystoreProperties['storeFile'])
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
           }
       }
   }
   ```

4. **Build Release APK/AAB**
   ```bash
   flutter build appbundle --release
   ```

5. **Submit to Play Console**
   - Create app in Google Play Console
   - Upload AAB file
   - Fill app details (description, screenshots, content rating)
   - Link privacy policy (host `PRIVACY_POLICY.md` on a website)
   - Complete Data Safety section (select "No data collected")
   - Submit for review

### Security Features

| Feature | Status |
|---------|--------|
| No internet permission | ✅ |
| No external APIs | ✅ |
| No analytics/tracking | ✅ |
| No sensitive permissions | ✅ |
| No hardcoded secrets | ✅ |
| Code obfuscation (R8) | ✅ |
| Resource shrinking | ✅ |
| Backup disabled | ✅ |
| Privacy policy | ✅ |

## 📄 License

MIT
