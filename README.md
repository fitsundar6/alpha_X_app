# ALPHA X GYM

> **Strength • Conditioning • Boxing • Transformation**  
> *Train Strong. Move Better. Become Better.*

A scalable, production-grade digital fitness platform designed for gym clients, personal trainers, and gym administrators. Powered by a high-performance Flutter mobile application and a cloud-native TypeScript / Prisma / PostgreSQL backend with integrated Google Gemini Foundation AI coaching.

---

## 🏗 Repository Architecture

```text
alpha_x_gym/
├── apps/
│   └── mobile/           # Flutter cross-platform mobile application (Android & iOS)
│       ├── android/      # Native Android project with Health Connect, Camera, release signing
│       ├── ios/          # Native iOS project with Apple HealthKit, ATS, and Motion sensors
│       └── lib/          # Dart codebase (Clean Architecture & Feature Modules)
├── backend/              # Production Node.js + TypeScript + Express + Prisma REST API
│   ├── prisma/           # Schema definitions and database migrations
│   └── src/              # Modular backend architecture (Auth, Admin, Workout, Diet, AI Coach)
├── docs/                 # System architecture, API documentation, and roadmaps
├── .github/              # GitHub Actions CI/CD workflows for automated Android & iOS releases
├── .gitignore            # Strict monorepo git exclusion rules (secrets, keys, binaries)
└── README.md             # Project documentation and developer quickstart
```

---

## ⚡ Tech Stack

| Layer | Technologies |
| :--- | :--- |
| **Mobile Client** | Flutter 3.47+ (Dart 3.13+), Material 3 Dark-First theme, Clean Architecture, BLoC & ChangeNotifier |
| **Backend REST API** | Node.js 20+, TypeScript 5+, Express.js 4, Zod schema validation, Helmet, CORS, Rate Limiting |
| **Database & ORM** | PostgreSQL (Neon Cloud Serverless Pooler), Prisma ORM 6 |
| **AI Engine** | Google Gemini Foundation AI (`gemini-2.5-flash`), dynamic context assembly, telemetry insights |
| **Hardware & Sensors**| Android Health Connect, Apple HealthKit, Pedometer, Camera (AI live meal recognition) |
| **Security & Auth** | Single Master Admin architecture, bcrypt-hashed credentials, JWT access/refresh rotation, HMAC QR signing |

---

## 🚀 Quickstart & Setup Guide

### Prerequisites
- **Git**
- **Node.js** `v20+` or `v24+` & `npm`
- **Flutter SDK** `v3.24+` (Channel stable)
- **Java Development Kit (JDK)** `17+`
- **Android SDK** (API 34+ / 36) with Command-Line Tools

---

### 1. Setting Up the Backend

1. **Navigate to the backend directory:**
   ```bash
   cd backend
   npm install
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   Open `.env` and fill in:
   - `DATABASE_URL`: Your PostgreSQL connection string (e.g. Neon Cloud)
   - `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`: Secure 64-character random strings
   - `ADMIN_EMAIL`: Master gym admin email
   - `ADMIN_PASSWORD_HASH`: Pre-computed bcrypt password hash (`npm run hash-password "your_password"`)
   - `GEMINI_API_KEY`: Google Gemini API key from Google AI Studio

3. **Generate Prisma Client and build:**
   ```bash
   npm run build
   ```

4. **Start the server:**
   ```bash
   # Development (hot reload)
   npm run dev

   # Production
   npm start
   ```

---

### 2. Setting Up the Mobile App

1. **Navigate to the mobile app directory:**
   ```bash
   cd apps/mobile
   flutter pub get
   ```

2. **Run Flutter analyze and tests:**
   ```bash
   flutter analyze
   flutter test
   ```

3. **Launch in development mode:**
   ```bash
   # Connect to local development server:
   flutter run --dart-define=ENV=dev

   # Connect to cloud production backend:
   flutter run --dart-define=ENV=prod
   ```

---

## 📦 Production Release Builds

### Android Release

#### 1. Configure Release Signing
Create `apps/mobile/android/key.properties` (this file is excluded from Git):
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=upload
storeFile=app/upload-keystore.jks
```
*(If `key.properties` is absent, the Gradle build will automatically fall back to debug signing for testing).*

#### 2. Build Production APK (Direct Sideloading / Testing)
```bash
cd apps/mobile
flutter build apk --release --dart-define=ENV=production
```
- Output location: `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

#### 3. Build Production AAB (Google Play Store)
```bash
cd apps/mobile
flutter build appbundle --release --dart-define=ENV=production
```
- Output location: `apps/mobile/build/app/outputs/bundle/release/app-release.aab`

---

### iOS Release

> **Note:** Compiling and packaging iOS binaries (`.ipa` / Xcode archive) requires a **macOS machine with Xcode installed**. Windows environments cannot directly compile iOS Mach-O binaries.

#### Building on macOS:
1. Open the project in Xcode:
   ```bash
   cd apps/mobile/ios
   pod install
   open Runner.xcworkspace
   ```
2. In Xcode:
   - Select your Apple Developer Team in **Signing & Capabilities**.
   - Verify the Bundle Identifier: `com.alphax.gym.alphaXGym`.
   - Set the active scheme to **Runner > Any iOS Device (arm64)**.
   - Select **Product > Archive**.
3. Alternatively, build via Flutter CLI on macOS:
   ```bash
   flutter build ipa --release --dart-define=ENV=production
   ```

#### Automated Cloud Builds via GitHub Actions:
The repository includes a ready-to-use GitHub Actions workflow (`.github/workflows/build_apps.yml`) that automatically boots an Apple Silicon `macos-14` cloud runner on every push to `main` to build and package the production iOS IPA and Android APK!

---

## 🔒 Security & Secrets Policy

1. **Zero Secret Commits**:
   - `.env`, `.env.*`, and private config files are strictly gitignored.
   - Android keystores (`*.keystore`, `*.jks`) and `key.properties` are strictly gitignored.
   - Apple certificates, provisioning profiles (`*.mobileprovision`), and signing keys (`*.p12`) are strictly gitignored.
   - Python bytecode (`*.pyc`, `__pycache__`) and local database files are strictly gitignored.
2. **Environment Hierarchy**:
   - Production builds always default to secure HTTPS (`https://alpha-x-app.vercel.app/api/v1`).
   - Localhost and LAN IPs (`192.168.*`, `10.0.2.2`, `localhost`) are automatically pruned in release mode.
   - Cleartext HTTP traffic is disabled in production via Android `network-security-config.xml`.
