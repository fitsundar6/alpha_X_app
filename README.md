# ALPHA X GYM

> **Strength • Conditioning • Boxing • Transformation**  
> *Train Strong. Move Better. Become Better.*

A scalable, production-grade digital fitness platform designed for gym clients, personal trainers, and gym administrators.

---

## 🏗 Repository Structure

```text
alpha_x_gym/
├── apps/
│   └── mobile/           # Flutter cross-platform mobile app (Android & iOS)
├── backend/              # Node.js + TypeScript + Express + Prisma REST API
├── docs/                 # System architecture, API documentation, and roadmaps
├── .gitignore            # Monorepo git exclusion rules (secrets, builds, node_modules)
└── README.md             # Project documentation and developer quickstart
```

---

## ⚡ Tech Stack

- **Mobile App**: Flutter (Dart), Clean Architecture, BLoC State Management, Material 3 Dark First
- **Backend API**: Node.js, TypeScript, Express.js, Zod validation, JWT authentication
- **Database**: PostgreSQL (Neon Cloud), Prisma ORM
- **Security**: Strict server-side role validation, HMAC dynamic QR attendance, encrypted token storage

---

## 🚀 Quickstart Guide

### Prerequisites
- Node.js `v20+` or `v24+`
- Flutter SDK `v3.24+` or `v3.47+`
- Git

### 1. Setting Up the Backend
```bash
cd backend
npm install
cp .env.example .env
npm run build
npm run dev
```

### 2. Setting Up the Mobile App
```bash
cd apps/mobile
flutter pub get
flutter run
```
