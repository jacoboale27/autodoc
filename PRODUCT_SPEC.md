# AutoDoc — Especificaciones del Producto

## 1. Resumen

**AutoDoc** es una plataforma mobile-first (Flutter + Firebase) que conecta propietarios de vehículos con mecánicos y talleres. Permite gestionar documentos vehiculares, historial de mantenimiento, alertas de vencimiento y comunicación directa entre propietarios y mecánicos, con moderación y auditoría a cargo de un rol administrador.

- **Plataformas**: Android, iOS, Web (Flutter Web), landing pública en Next.js.
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Functions), reglas de seguridad declarativas (`firestore.rules`, `storage.rules`).
- **Idiomas**: ES/EN vía `flutter gen-l10n` (`lib/l10n/`).

## 2. Roles de usuario

| Rol | Descripción | Pantalla principal |
|---|---|---|
| **Propietario** | Usuario estándar. Registra vehículos, gestiona alertas, busca talleres, chatea con mecánicos. | `/dashboard` |
| **Mecánico/Taller** | Atiende vehículos, registra servicios, gestiona disponibilidad, empleados y cotizaciones. | `/mechanic_dashboard` |
| **Administrador** | Acceso total: modera reseñas, gestiona usuarios, aprueba talleres, audita logs. | `/admin/dashboard` |

El rol vive en el campo `rol` del documento de usuario (colección `usuarios`). Cualquier cambio de rol pasa por el panel de administración (`admin_service.dart`) y deja rastro en `admin_logs`.

## 3. Modelo de datos (Firestore)

| Colección | Propósito |
|---|---|
| `usuarios` | Perfiles; el campo `rol` define permisos. |
| `vehiculos` | Sub-documentos referenciando a un propietario (`id_propietario`). |
| `servicios` | Historial de mantenimiento; referencia vehículos y talleres. |
| `talleres` | Perfiles de mecánicos/talleres verificados. |
| `resenias` | Calificaciones de dueños a talleres. |
| `alertas` | Notificaciones y próximos mantenimientos. |
| `admin_logs` | Auditoría de acciones del rol Administrador. |

## 4. Features y flujos clave (por módulo, `lib/features/`)

### 4.1 Onboarding y Auth
- **onboarding**: carrusel de bienvenida (`onboarding_screen.dart`) presentando el valor del producto antes del login.
- **auth**: login, registro y reset de contraseña en una única pantalla (`auth_screen.dart`).
- **splash**: `splash_screen.dart` decide el enrutamiento inicial según sesión/rol.

### 4.2 Propietario — Dashboard (`dashboard/`)
- `dashboard_screen.dart`: panel principal del propietario.
- `garage_screen.dart`: garaje con los vehículos registrados.
- `vehicle_profile_screen.dart`: ficha de un vehículo (documentos, datos, historial).
- `service_history_screen.dart`: historial de mantenimientos realizados.
- `alerts_screen.dart` / `notifications_screen.dart`: alertas de vencimiento y notificaciones push.
- `task_config_screen.dart` / `task_complete_screen.dart`: configuración y cierre de tareas/mantenimientos programados.
- `workshop_directory_screen.dart`: directorio/búsqueda de talleres.

### 4.3 Chat y reservas (`chat/`)
- `conversaciones_list_screen.dart`: lista de conversaciones propietario↔mecánico.
- `chat_screen.dart`: mensajería directa.
- `reserva_detail_screen.dart`: detalle de una reserva/cotización de servicio.

### 4.4 Mecánico/Taller (`mechanic/`)
- `mechanic_dashboard_screen.dart`: panel del taller.
- `vehicle_search_screen.dart`: búsqueda de vehículos/clientes.
- `initiate_service_screen.dart`: inicio de un nuevo servicio.
- `reparaciones_kanban_screen.dart`: tablero kanban de reparaciones en curso.
- `catalogo_servicios_screen.dart`: catálogo de servicios ofrecidos.
- `mechanic_service_history_screen.dart`: historial de servicios prestados.
- `empleados_screen.dart`: gestión de empleados del taller.
- `workshop_settings_screen.dart`: configuración del taller (disponibilidad, datos).
- `mechanic_reviews_screen.dart`: reseñas recibidas.
- `mechanic_pending_screen.dart`: estado "pendiente de aprobación" (antes de ser verificado por un admin).

### 4.5 Perfil (`profile/`)
- `profile_setup_screen.dart`: configuración inicial de perfil (post-registro).
- `user_profile_screen.dart`: edición de perfil.
- `about_screen.dart`: información de la app.

### 4.6 Reseñas (`reviews/`)
- Lógica de reseñas de talleres consumida desde `dashboard`/`mechanic` (calificación de propietarios a talleres, colección `resenias`).

### 4.7 Administración (`admin/`)
- `admin_dashboard_screen.dart`: panel general.
- `admin_usuarios_screen.dart`: gestión de usuarios (suspender/reactivar/cambiar rol).
- `admin_talleres_screen.dart`: aprobación/gestión de talleres.
- `admin_resenias_screen.dart`: moderación de reseñas.
- `admin_logs_screen.dart`: auditoría de acciones administrativas (`admin_logs`).
- `admin_seed_screen.dart`: utilidades de seed/datos de prueba.

### 4.8 Landing
- `landing/`: pantalla de landing dentro de la propia app.
- `landing-web/` (Next.js, proyecto separado): landing pública de marketing, desplegada en Vercel.

## 5. Arquitectura

**Clean Architecture adaptada a Flutter + Provider** (ver `CONVENTIONS.md`). Cada feature sigue:

```
lib/features/[modulo]/
├── data/
│   ├── repositories/   # acceso directo a Firebase/APIs
│   └── services/       # lógica de negocio / casos de uso
└── presentation/
    ├── pages/          # pantallas completas
    ├── widgets/        # componentes reutilizables de la feature
    └── providers/      # estado (ChangeNotifier)
```

Reglas principales:
- Todo el estado vive en **Providers**; los Providers no retornan Widgets.
- La UI es "tonta": solo reacciona a cambios de estado.
- Las llamadas a Firebase ocurren solo en la capa `data` (nunca desde la UI).
- Tema global obligatorio (`Theme.of(context)`), sin colores hardcodeados — soporte Dark Mode.
- Diseño responsive vía la utilidad `Responsive` (`lib/core/utils/responsive.dart`).

`lib/core/` contiene lo transversal: constants, models compartidos, providers globales (auth, sesión, tema), router (GoRouter con auth guards), servicios compartidos (notificaciones, traducción), theme y widgets comunes (scaffold, nav bar, botones).

## 6. Backend y despliegue

- **Cloud Functions** (`functions/`, Node.js) — documentadas en `docs/FIREBASE_FUNCTIONS.md`.
- **Firestore/Storage rules** con tests dedicados (`test_rules/`), desplegadas con `firebase deploy --only firestore:rules,storage`.
- **Runbook de producción** (`docs/RUNBOOK.md`) define niveles de incidente (P0: brecha de datos activa, P1: servicio degradado) y respuesta a incidentes de seguridad.
- **Build/deploy**: APK/App Bundle (Android), `flutter build web --release` (Web), Vercel para `landing-web`.

## 7. Testing

- Unitarios/widget: `flutter test`.
- Integración: `flutter test integration_test` (requiere emuladores Firebase).
- Reglas de Firestore: `firebase emulators:exec "npm test" --only firestore`.

## 8. Fuentes

Documento generado a partir de `README.md`, `CONVENTIONS.md`, el grafo de conocimiento (`graphify-out/graph.json`) y la estructura real de `lib/features/`.
