# Alpha X Gym — System Architecture Document

## 1. Overview
Alpha X Gym is an enterprise-grade fitness platform connecting gym clients and gym administrators.

## 2. Monorepo Architecture
```text
alpha_x_gym/
├── apps/
│   └── mobile/           # Flutter Client (Android & iOS)
├── backend/              # Node.js + TypeScript + Express + Prisma API
├── docs/                 # Architectural specifications
├── .gitignore
└── README.md
```

## 3. Mobile Architecture (Clean Architecture + BLoC)
```text
lib/
├── core/
│   ├── constants/        # System keys, endpoints, timeouts
│   ├── errors/           # Failures, exceptions
│   ├── network/          # Dio client, token refresh interceptor
│   ├── storage/          # Secure storage & persistent cache
│   ├── theme/            # Alpha X Dark-First design system
│   └── utils/            # Validators, formatters, loggers
├── features/             # Vertical feature slices
└── main.dart
```

## 4. Backend Architecture (Layered Controller-Service-Repository)
```text
src/
├── config/               # Zod-validated environment config
├── constants/            # Roles, error codes, HTTP codes
├── middlewares/          # Auth, role-guard, error-handler, rate-limiter
├── modules/              # Domain-specific feature modules
├── utils/                # Response envelopes, password hashing
└── server.ts             # Express application entrypoint
```

## 5. Security & Isolation
- **Role Scoping**: Client operations are strictly bound to authenticated `userId`.
- **Zero Mobile Secrets**: All database and third-party credentials reside exclusively on the server.
- **Dynamic QR Check-ins**: Time-limited signed HMAC tokens prevent screenshot-based attendance sharing.
- **Payment Verification**: Client-reported payment status is never trusted; verification happens server-side.
