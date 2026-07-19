# AutoDoc 🚗📋

**Tu copiloto para el control total de tu vehículo.**

AutoDoc es una plataforma mobile-first (Flutter + Firebase) que conecta propietarios de vehículos con mecánicos y talleres. Permite gestionar documentos vehiculares, historial de mantenimiento, alertas de vencimiento, y comunicación directa entre propietarios y mecánicos.

---

## 📋 Tabla de contenido

- [Roles](#roles)
- [Requisitos](#requisitos)
- [Setup rápido](#setup-rápido)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Ejecutar la app](#ejecutar-la-app)
- [Tests](#tests)
- [Despliegue](#despliegue)
- [Variables de entorno y secrets](#variables-de-entorno-y-secrets)
- [Documentación adicional](#documentación-adicional)

---

## 👥 Roles

| Rol | Descripción | Pantalla principal |
|-----|-------------|-------------------|
| **Propietario** | Usuario estándar. Registra vehículos, gestiona alertas, busca talleres, chatea con mecánicos. | `/dashboard` |
| **Mecánico/Taller** | Atiende vehículos, registra servicios, gestiona disponibilidad y cotizaciones. | `/mechanic_dashboard` |
| **Administrador** | Acceso total. Modera reseñas, gestiona usuarios, aprueba talleres, audita logs. | `/admin/dashboard` |

---

## ⚙️ Requisitos

| Herramienta | Versión mínima |
|-------------|---------------|
| Flutter | 3.11+ |
| Dart | 3.11+ |
| Node.js | 20+ |
| Firebase CLI | 13+ |
| pnpm | 8+ (solo para landing-web) |

---

## 🚀 Setup rápido

### 1. Clonar y configurar Flutter

```bash
git clone <repo-url> autodoc
cd autodoc
flutter pub get
```

### 2. Firebase

```bash
# Instalar Firebase CLI si no la tienes
npm install -g firebase-tools

# Login
firebase login

# Verificar proyecto vinculado
cat .firebaserc
```

El archivo `lib/firebase_options.dart` ya contiene la configuración del proyecto Firebase. Si necesitas regenerar:

```bash
# Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurar
flutterfire configure
```

### 3. Emuladores Firebase (desarrollo local)

```bash
# Iniciar emuladores de Auth, Firestore, Storage, Functions
firebase emulators:start

# La app detecta automáticamente los emuladores si están corriendo
```

### 4. Cloud Functions

```bash
cd functions
npm install
cd ..
```

### 5. Landing Web (Next.js)

```bash
cd landing-web
pnpm install
pnpm dev  # Inicia en localhost:3000
cd ..
```

### 6. Generar localizaciones

```bash
flutter gen-l10n
```

---

## 📁 Estructura del proyecto

```
autodoc/
├── lib/
│   ├── config/              # Configuración global
│   ├── core/
│   │   ├── constants/       # Constantes de la app
│   │   ├── models/          # Modelos de datos compartidos
│   │   ├── providers/       # Providers globales (auth, session, theme)
│   │   ├── router/          # GoRouter con auth guards
│   │   ├── services/        # Servicios compartidos (notificaciones, traducción)
│   │   ├── theme/           # AppTheme, AppColors, AppTextStyles
│   │   ├── utils/           # Utilidades (responsive, role_utils)
│   │   └── widgets/         # Widgets compartidos (scaffold, nav bar, buttons)
│   ├── features/
│   │   ├── admin/           # Panel de administración
│   │   ├── auth/            # Login, registro, reset password
│   │   ├── chat/            # Conversaciones, mensajes, cotizaciones, reservas
│   │   ├── dashboard/       # Dashboard, garaje, alertas, perfil vehículo
│   │   ├── landing/         # Pantalla landing in-app
│   │   ├── mechanic/        # Dashboard mecánico, servicios, taller
│   │   ├── onboarding/      # Onboarding screens
│   │   ├── profile/         # Setup y edición de perfil
│   │   ├── reviews/         # Reseñas de talleres
│   │   └── splash/          # Splash screen con routing
│   ├── l10n/                # Archivos de localización (ES/EN)
│   ├── firebase_options.dart
│   └── main.dart
├── functions/               # Cloud Functions (Node.js)
├── landing-web/             # Landing page (Next.js)
├── test/                    # Tests unitarios
├── integration_test/        # Tests de integración
├── firestore.rules          # Reglas de seguridad Firestore
├── storage.rules            # Reglas de seguridad Storage
├── docs/                    # Documentación técnica
│   └── FIREBASE_FUNCTIONS.md
├── CONVENTIONS.md           # Convenciones de código
└── pubspec.yaml
```

Para más detalles sobre las convenciones, ver [`CONVENTIONS.md`](CONVENTIONS.md).

---

## ▶️ Ejecutar la app

### Android / iOS

```bash
flutter run
```

### Web

```bash
flutter run -d chrome
```

### Con emuladores Firebase

```bash
# Terminal 1: Emuladores
firebase emulators:start

# Terminal 2: App
flutter run
```

---

## 🧪 Tests

### Tests unitarios

```bash
flutter test
```

### Tests de integración

```bash
# Asegúrate de que los emuladores estén corriendo
firebase emulators:start

# En otra terminal
flutter test integration_test
```

### Tests de reglas Firestore

```bash
# Los tests de reglas se ejecutan contra el emulador
firebase emulators:exec "npm test" --only firestore
```

---

## 🚢 Despliegue

### APK / App Bundle (Android)

```bash
flutter build apk --release
# o
flutter build appbundle --release
```

### Flutter Web

```bash
flutter build web --release
```

### Cloud Functions

```bash
firebase deploy --only functions
```

### Firestore Rules + Storage Rules

```bash
firebase deploy --only firestore:rules,storage
```

### Landing Web (Vercel)

```bash
cd landing-web
pnpm build
# Desplegar con Vercel CLI o conectar repositorio a Vercel
```

---

## 🔐 Variables de entorno y secrets

| Archivo | Propósito | Incluido en Git |
|---------|-----------|-----------------|
| `lib/firebase_options.dart` | Configuración Firebase (API keys) | ✅ Sí |
| `.firebaserc` | Proyecto Firebase vinculado | ✅ Sí |
| `functions/.env` | Variables de Cloud Functions (si las hay) | ❌ No |
| `android/app/google-services.json` | Config Firebase Android | ❌ No (agregar manualmente) |
| `ios/Runner/GoogleService-Info.plist` | Config Firebase iOS | ❌ No (agregar manualmente) |

### Para obtener los archivos de configuración:

1. Ir a [Firebase Console](https://console.firebase.google.com)
2. Seleccionar el proyecto AutoDoc
3. Descargar `google-services.json` (Android) y `GoogleService-Info.plist` (iOS)
4. Colocarlos en las rutas indicadas arriba

---

## 📚 Documentación adicional

- [Convenciones de código](CONVENTIONS.md)
- [Cloud Functions](docs/FIREBASE_FUNCTIONS.md)
- [Reglas Firestore](firestore.rules)
- [Reglas Storage](storage.rules)

---

## 🤝 Contribuir

1. Crea un branch desde `main`
2. Sigue las convenciones en [`CONVENTIONS.md`](CONVENTIONS.md)
3. Ejecuta `dart format .` y `dart fix --apply` antes de commit
4. Asegúrate de que `flutter test` pase
5. Crea un Pull Request con descripción clara

---

**Tiempo estimado de setup para nuevo dev: ~20 minutos** ⏱️
