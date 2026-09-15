# Anexo — inventario de literales sin traducir (GAPS-06)

Barrido de un worker de Codex. **Es un reporte de otro agente y esta truncado a 120
filas**: usalo como punto de partida, nunca como verdad. Se guarda porque costo cuota
y el gap 8 sigue abierto.

**El gap decia 64 literales en 24 ficheros. El barrido da 274 en 58.** La diferencia
no esta explicada: puede que el barrido cuente de mas (cadenas que no son UI) o que la
medicion anterior mirara solo una parte. Medirlo bien ES el primer trabajo de esa tanda.

Inventario acotado a `lib/**/presentation/**`. Se muestran 120 filas; el barrido completo detectó 274 ocurrencias en 58 archivos, por lo que quedan 154 fuera del límite.

#### `lib/features/mechanic/presentation/pages/initiate_service_screen.dart` — 26

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `initiate_service_screen.dart:740` | `Volver` | `commonBack` |
| `initiate_service_screen.dart:744` | `Iniciar Servicio` | `serviceStart` |
| `initiate_service_screen.dart:765` | `Kilometraje de ingreso` | `serviceEntryMileageTitle` |
| `initiate_service_screen.dart:771` | `Kilometraje de ingreso` | `serviceEntryMileage` |
| `initiate_service_screen.dart:778` | `Alertas detectadas` | `serviceDetectedAlerts` |
| `initiate_service_screen.dart:785` | `Tareas a realizar` | `serviceTasksToPerform` |
| `initiate_service_screen.dart:809` | `Materiales / repuestos` | `serviceMaterialsParts` |
| `initiate_service_screen.dart:818` | `Mano de obra` | `serviceLabor` |
| `initiate_service_screen.dart:822` | `Mano de obra` | `serviceLabor` |
| `initiate_service_screen.dart:832` | `Costo del servicio (total)` | `serviceTotalCostTitle` |
| `initiate_service_screen.dart:838` | `Costo del servicio` | `serviceCost` |
| `initiate_service_screen.dart:841` | `Se calcula sumando materiales y mano de obra` | `serviceCostCalculation` |
| `initiate_service_screen.dart:845` | `Observaciones técnicas` | `serviceTechnicalNotes` |
| `initiate_service_screen.dart:852` | `Detalles del trabajo realizado...` | `serviceWorkDetailsHint` |
| `initiate_service_screen.dart:856` | `Foto de factura / comprobante` | `serviceInvoiceTitle` |
| `initiate_service_screen.dart:863` | `FINALIZAR SERVICIO` | `serviceFinishButton` |
| `initiate_service_screen.dart:1048` | `Tomar otra` | `serviceTakeAnotherPhoto` |
| `initiate_service_screen.dart:1055` | `Archivo` | `commonFile` |
| `initiate_service_screen.dart:1062` | `Eliminar` | `commonDelete` |
| `initiate_service_screen.dart:1098` | `Cámara` | `commonCamera` |
| `initiate_service_screen.dart:1105` | `Archivo / PDF` | `serviceFilePdf` |
| `initiate_service_screen.dart:1144` | `Reintentar` | `errorRetry` |
| `initiate_service_screen.dart:1179` | `Ver tablero` | `serviceViewBoard` |
| `initiate_service_screen.dart:1192` | `Recibir vehículo` | `serviceReceiveVehicle` |
| `initiate_service_screen.dart:1230` | `Desde catálogo` | `serviceFromCatalog` |
| `initiate_service_screen.dart:1737` | `Recibir vehículo` | `serviceReceiveVehicle` |

#### `lib/features/mechanic/presentation/pages/workshop_settings_screen.dart` — 14

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `workshop_settings_screen.dart:171` | `Configuración` | `workshopSettingsTitle` |
| `workshop_settings_screen.dart:235` | `Guardar Cambios` | `upSaveChanges` |
| `workshop_settings_screen.dart:353` | `Cancelar` | `commonCancel` |
| `workshop_settings_screen.dart:359` | `Confirmar` | `commonConfirm` |
| `workshop_settings_screen.dart:431` | `Información Pública` | `workshopPublicInfo` |
| `workshop_settings_screen.dart:438` | `Nombre del Taller` | `workshopName` |
| `workshop_settings_screen.dart:446` | `Especialidad` | `workshopSpecialty` |
| `workshop_settings_screen.dart:465` | `Departamento` | `workshopDepartment` |
| `workshop_settings_screen.dart:476` | `Municipio` | `workshopMunicipality` |
| `workshop_settings_screen.dart:517` | `Teléfono de Contacto (opcional)` | `workshopContactPhone` |
| `workshop_settings_screen.dart:521` | `Ej: 7788-9900` | `workshopPhoneHint` |
| `workshop_settings_screen.dart:572` | `Ubicación Geográfica` | `workshopLocationTitle` |
| `workshop_settings_screen.dart:645` | `Por GPS` | `workshopUseGps` |
| `workshop_settings_screen.dart:655` | `En Mapa` | `workshopUseMap` |

#### `lib/features/mechanic/presentation/pages/mechanic_reviews_screen.dart` — 13

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `mechanic_reviews_screen.dart:56` | `Mis Reseñas` | `mechanicMyReviews` |
| `mechanic_reviews_screen.dart:148` | `Aún no tienes reseñas` | `mechanicNoReviews` |
| `mechanic_reviews_screen.dart:166` | `Reseñas` | `reviewsTitle` |
| `mechanic_reviews_screen.dart:230` | `Cancelar` | `commonCancel` |
| `mechanic_reviews_screen.dart:236` | `Reportar` | `reviewReport` |
| `mechanic_reviews_screen.dart:280` | `Ej. Gracias por tu confianza...` | `reviewReplyHint` |
| `mechanic_reviews_screen.dart:281` | `Respuesta` | `reviewResponseLabel` |
| `mechanic_reviews_screen.dart:286` | `Cancelar` | `commonCancel` |
| `mechanic_reviews_screen.dart:292` | `Publicar` | `commonPublish` |
| `mechanic_reviews_screen.dart:338` | `$estrellas de 5 estrellas` | `reviewStarsCount` |
| `mechanic_reviews_screen.dart:412` | `Reportar esta reseña` | `reviewReportAction` |
| `mechanic_reviews_screen.dart:496` | `Responder` | `reviewReplyAction` |
| `mechanic_reviews_screen.dart:534` | `$i estrellas: ${counts[i]} de $total reseñas` | `reviewRatingBreakdown` |

#### `lib/features/mechanic/presentation/pages/empleados_screen.dart` — 12

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `empleados_screen.dart:121` | `Nombre completo` | `upFullName` |
| `empleados_screen.dart:128` | `Correo` | `upEmailAddress` |
| `empleados_screen.dart:140` | `Contraseña temporal` | `employeeTemporaryPassword` |
| `empleados_screen.dart:149` | `Teléfono (opcional)` | `employeePhoneOptional` |
| `empleados_screen.dart:175` | `Cancelar` | `commonCancel` |
| `empleados_screen.dart:181` | `Crear` | `commonCreate` |
| `empleados_screen.dart:233` | `Cancelar` | `commonCancel` |
| `empleados_screen.dart:239` | `Desactivar` | `employeeDeactivate` |
| `empleados_screen.dart:291` | `Empleados` | `employeesTitle` |
| `empleados_screen.dart:301` | `Acceso restringido` | `employeeRestrictedAccess` |
| `empleados_screen.dart:312` | `Aún no tienes empleados` | `employeeEmptyTitle` |
| `empleados_screen.dart:401` | `Desactivar a ${empleado.nombreCompleto}` | `employeeDeactivateNamed` |

#### `lib/features/dashboard/presentation/pages/task_complete_screen.dart` — 12

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `task_complete_screen.dart:115` | `Volver` | `commonBack` |
| `task_complete_screen.dart:119` | `Completar Servicio` | `serviceCompleteTitle` |
| `task_complete_screen.dart:191` | `Km Actual` | `currentMileageShort` |
| `task_complete_screen.dart:203` | `Último` | `lastServiceShort` |
| `task_complete_screen.dart:215` | `Fecha` | `commonDate` |
| `task_complete_screen.dart:231` | `DETALLES DEL SERVICIO` | `serviceDetailsTitle` |
| `task_complete_screen.dart:233` | `Registra la información del mantenimiento realizado.` | `serviceDetailsSubtitle` |
| `task_complete_screen.dart:240` | `Costo total` | `serviceTotalCostLabel` |
| `task_complete_screen.dart:245` | `Opcional.` | `commonOptional` |
| `task_complete_screen.dart:249` | `Notas, taller o refacciones` | `serviceNotesLabel` |
| `task_complete_screen.dart:253` | `Ej: Se usó aceite sintético 5W-30...` | `serviceNotesHint` |
| `task_complete_screen.dart:258` | `EVIDENCIA (RECIBO O FOTO)` | `serviceEvidenceTitle` |

#### `lib/features/mechanic/presentation/widgets/mechanic_sidebar.dart` — 11

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `mechanic_sidebar.dart:113` | `Dashboard` | `mechanicNavDashboard` |
| `mechanic_sidebar.dart:121` | `Buscar Vehículo` | `mechanicNavSearchVehicle` |
| `mechanic_sidebar.dart:129` | `Mis Servicios` | `mechanicNavServices` |
| `mechanic_sidebar.dart:138` | `Reparaciones` | `mechanicNavRepairs` |
| `mechanic_sidebar.dart:146` | `Mis Reseñas` | `mechanicNavReviews` |
| `mechanic_sidebar.dart:154` | `Mensajes` | `mechanicNavMessages` |
| `mechanic_sidebar.dart:163` | `Empleados` | `mechanicNavEmployees` |
| `mechanic_sidebar.dart:171` | `Catálogo` | `mechanicNavCatalog` |
| `mechanic_sidebar.dart:179` | `Fotos del taller` | `mechanicNavWorkshopPhotos` |
| `mechanic_sidebar.dart:187` | `Configuración` | `mechanicNavSettings` |
| `mechanic_sidebar.dart:200` | `Cerrar Sesión` | `authSignOut` |

#### `lib/features/mechanic/presentation/pages/mechanic_dashboard_screen.dart` — 10

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `mechanic_dashboard_screen.dart:87` | `Dashboard` | `mechanicDashboardTitle` |
| `mechanic_dashboard_screen.dart:182` | `Buscar` | `mechanicDashboardSearch` |
| `mechanic_dashboard_screen.dart:263` | `Ingresos (Mes)` | `mechanicIncomeMonth` |
| `mechanic_dashboard_screen.dart:273` | `Servicios (Mes)` | `mechanicServicesMonth` |
| `mechanic_dashboard_screen.dart:280` | `Total Servicios` | `mechanicTotalServices` |
| `mechanic_dashboard_screen.dart:288` | `Vehículos Atendidos` | `mechanicVehiclesServed` |
| `mechanic_dashboard_screen.dart:295` | `Calificación` | `mechanicRating` |
| `mechanic_dashboard_screen.dart:302` | `Reseñas` | `mechanicReviews` |
| `mechanic_dashboard_screen.dart:327` | `Tendencia de Ingresos` | `mechanicIncomeTrend` |
| `mechanic_dashboard_screen.dart:514` | `Servicios Recientes` | `mechanicRecentServices` |

#### `lib/features/dashboard/presentation/pages/task_config_screen.dart` — 9

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `task_config_screen.dart:137` | `Frecuencia de mantenimiento` | `maintenanceFrequencyTitle` |
| `task_config_screen.dart:146` | `Frecuencia en Kilómetros` | `maintenanceFrequencyKm` |
| `task_config_screen.dart:150` | `Ej. 5000` | `maintenanceFrequencyKmHint` |
| `task_config_screen.dart:151` | `Debe ser mayor que 0.` | `positiveValueHint` |
| `task_config_screen.dart:157` | `Frecuencia en Meses` | `maintenanceFrequencyMonths` |
| `task_config_screen.dart:161` | `Ej. 6` | `maintenanceFrequencyMonthsHint` |
| `task_config_screen.dart:162` | `Debe ser mayor que 0.` | `positiveValueHint` |
| `task_config_screen.dart:169` | `Preajustes rápidos` | `maintenanceQuickPresets` |
| `task_config_screen.dart:186` | `Guardar Configuración` | `maintenanceSaveConfig` |

#### `lib/features/mechanic/presentation/pages/vehicle_search_screen.dart` — 8

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `vehicle_search_screen.dart:269` | `Buscar Vehículo` | `vehicleSearchTitle` |
| `vehicle_search_screen.dart:359` | `Ej: ABC123` | `vehicleSearchPlateHint` |
| `vehicle_search_screen.dart:372` | `Escanear código QR de la placa` | `vehicleSearchQrLabel` |
| `vehicle_search_screen.dart:405` | `BUSCAR AUTO` | `vehicleSearchButton` |
| `vehicle_search_screen.dart:451` | `No hay búsquedas recientes` | `vehicleSearchNoRecent` |
| `vehicle_search_screen.dart:565` | `No se pudieron cargar tus servicios` | `vehicleSearchServicesError` |
| `vehicle_search_screen.dart:566` | `Revisa tu conexión e inténtalo de nuevo.` | `errorConnectionRetry` |
| `vehicle_search_screen.dart:579` | `No hay servicios activos` | `vehicleSearchNoActiveServices` |

#### `lib/features/admin/presentation/pages/admin_usuarios_screen.dart` — 5

| Ruta:línea | Literal exacto | Clave ARB propuesta |
|---|---|---|
| `admin_usuarios_screen.dart:55` | `Motivo / Detalle` | `adminReasonDetail` |
| `admin_usuarios_screen.dart:104` | `Eliminar` | `adminDelete` |
| `admin_usuarios_screen.dart:281` | `OK` | `commonOk` |
| `admin_usuarios_screen.dart:316` | `Exportar CSV` | `adminExportCsv` |
| `admin_usuarios_screen.dart:321` | `Filtros avanzados` | `adminAdvancedFilters` |

**TOTAL:** 274 ocurrencias directas detectadas, 58 archivos.  
**Mostradas:** 120 filas. **Fuera por límite:** 154 filas.