# AutoDoc — Índices de Firestore Requeridos

Para que la aplicación funcione correctamente en producción y las consultas complejas de ordenamiento y filtrado no fallen, es obligatorio crear los siguientes índices compuestos en Firebase Console.

> Puedes desplegar estos índices usando el Firebase CLI si agregas este contenido a `firestore.indexes.json` y ejecutas `firebase deploy --only firestore:indexes`.

## Colección `conversaciones`

| Campos Indexados | Dirección | Razón |
|------------------|-----------|-------|
| `id_propietario` | Ascendente | Listar los chats del usuario actual. |
| `ultimo_mensaje_ts` | Descendente | Ordenar los chats más recientes primero. |

| Campos Indexados | Dirección | Razón |
|------------------|-----------|-------|
| `id_mecanico` | Ascendente | Listar los chats del taller/mecánico actual. |
| `ultimo_mensaje_ts` | Descendente | Ordenar los chats más recientes primero. |

## Colección `mensajes` (Subcolección de conversaciones)

| Campos Indexados | Dirección | Razón |
|------------------|-----------|-------|
| `timestamp` | Descendente | Ordenar mensajes cronológicamente. |
| (El índice básico suele ser suficiente, pero si se filtra por estado + fecha, requiere compuesto) |

## Colección `servicios`

| Campos Indexados | Dirección | Razón |
|------------------|-----------|-------|
| `id_vehiculo` | Ascendente | Obtener el historial de un auto específico. |
| `fecha` | Descendente | Mostrar los servicios más recientes primero. |

## Colección `alertas`

| Campos Indexados | Dirección | Razón |
|------------------|-----------|-------|
| `id_vehiculo` | Ascendente | Mostrar alertas de un auto específico. |
| `estado` | Ascendente | Filtrar solo alertas pendientes. |
| `fecha_limite` | Ascendente | Ordenar por vencimiento inminente. |

## Colección `resenias`

| Campos Indexados | Dirección | Razón |
|------------------|-----------|-------|
| `id_taller` | Ascendente | Obtener reseñas de un taller específico. |
| `fecha_resenia` | Descendente | Mostrar las opiniones más recientes primero. |

## Colección `usuarios`

| Campos Indexados | Dirección | Razón |
|------------------|-----------|-------|
| `rol` | Ascendente | Panel Admin: Filtrar mecánicos. |
| `fecha_registro` | Descendente | Panel Admin: Ordenar por fecha. |
