# AutoDoc - Convenciones y Arquitectura

Este documento describe las convenciones principales y la arquitectura utilizada en el proyecto **AutoDoc**, con el objetivo de mantener la consistencia, facilitar la mantenibilidad y prevenir regresiones.

## 1. Arquitectura (Clean Architecture + Provider)

El proyecto sigue una estructura inspirada en Clean Architecture pero adaptada a Flutter usando **Provider** para la gestión de estado. 

La aplicación está dividida en **features** (módulos). Cada módulo tiene la siguiente estructura de carpetas:

```text
lib/
└── features/
    └── [nombre_modulo]/
        ├── data/
        │   ├── repositories/    # Interacción directa con Firebase/APIs
        │   └── services/        # Lógica de negocio y casos de uso
        └── presentation/
            ├── pages/           # Pantallas completas
            ├── widgets/         # Componentes reutilizables específicos de la feature
            └── providers/       # Gestión de estado (ChangeNotifier)
```

### Reglas de Estado:
- Toda la lógica de estado debe residir en los **Providers**.
- Los Providers no deben importar UI (`package:flutter/material.dart` está permitido para `ChangeNotifier`, pero no deben retornar Widgets).
- La UI (`pages` y `widgets`) debe ser lo más "tonta" posible y simplemente reaccionar a los cambios de estado.
- Las llamadas a Firebase se realizan en la capa de `data` (Services/Repositories) y **nunca** directamente desde la UI.

## 2. Reglas de UI (Tema global, Responsive)

### 2.1 Tema y Colores
- Nunca usar colores "hardcodeados" (ej: `Colors.white` o `Colors.blue`).
- Siempre usar el tema global mediante `Theme.of(context)`.
  - Ejemplo: `Theme.of(context).colorScheme.surface` en lugar de `Colors.white` para soportar **Dark Mode**.
  - Los colores principales de la marca (ej. morado AutoDoc) están definidos en `AppColors` y mapeados en `AppTheme`.

### 2.2 Responsive Design
- Usar la clase utilitaria `Responsive` (`lib/core/utils/responsive.dart`) para escalar fuentes, paddings y dimensiones.
  - Ejemplo: `fontSize: Responsive.fontSize(context, 14)`
  - Ejemplo: `padding: EdgeInsets.all(Responsive.width(context, 4))`
- Esto asegura que la app se vea bien tanto en pantallas pequeñas de teléfonos como en tablets.

## 3. Reglas de Firebase (Roles, Estructura de Colecciones)

### 3.1 Base de Datos (Firestore)
La estructura de colecciones sigue las siguientes reglas:
- `usuarios`: Almacena perfiles. El campo `rol` define los permisos.
- `vehiculos`: Sub-documentos que referencian a un propietario (`id_propietario`).
- `servicios`: Historial de mantenimiento, hace referencia a vehículos y talleres.
- `talleres`: Perfiles de mecánicos/talleres verificados.
- `resenias`: Calificaciones dadas por dueños a talleres.
- `alertas`: Notificaciones y próximos mantenimientos.
- `admin_logs`: Registro de auditoría (logs) para acciones tomadas por el rol "Administrador".

### 3.2 Roles de Usuario
El sistema maneja tres roles principales definidos en el campo `rol` del documento de usuario:
1. **Propietario**: Usuario estándar que registra sus vehículos.
2. **Mecanico**: Usuario de taller, puede interactuar con el directorio y subir servicios.
3. **Administrador**: Tiene acceso total, puede suspender/aprobar talleres, eliminar usuarios y moderar reseñas.

Cualquier cambio de rol debe ser efectuado desde el panel de administración (`admin_service.dart`) y dejar un rastro en `admin_logs`.

## 4. Lint Rules y Estilo de Código
- En `.analysis_options.yaml` se han activado reglas estrictas para mantener la consistencia:
  - `prefer_const_constructors`: Obliga a usar `const` en widgets para optimizar el rendimiento.
  - `avoid_print`: Prohíbe el uso de `print()` en producción (usar `debugPrint` o un logger si es necesario).
  - `require_trailing_commas`: Asegura que el formateador automático (dart format) mantenga el código ordenado y en forma de árbol estructurado.
- Siempre ejecuta `dart format .` y `dart fix --apply` antes de hacer un commit.
