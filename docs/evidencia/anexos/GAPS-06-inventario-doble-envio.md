# Anexo — inventario verificado de doble envio (GAPS-06)

Barrido de un worker de Codex, **verificado abriendo cada archivo**. Se guarda en el
repo porque costo cuota y porque el gap 7 sigue abierto: la proxima tanda arranca de
aqui en vez de rehacerlo. La distincion que usa la columna de veredicto es la que
importa: un boton que cambia de aspecto pero sigue recibiendo taps NO esta protegido.

**El gap decia CINCO formularios. Son QUINCE grupos vulnerables.**

Verificado abriendo los archivos actuales. Agrupé controles del mismo widget para respetar el máximo de 30 filas. `AppButton.isLoading` sí bloquea taps internamente (`app_button.dart:58,70,246`); no es solo visual.

| # | Widget / ruta:línea del callback | Flag y relación con `onPressed` | Veredicto |
|---:|---|---|---|
| 1 | `auth_screen.dart:575` Google; `auth_screen.dart:639` recuperar contraseña | Hay `AuthProvider.isLoading`, pero no gobierna ninguno de esos botones; permanecen clicables | **VULNERABLE** |
| 2 | `chat_screen.dart:1077` (`onTap`, nueva reserva) | Sin flag ni guard mientras `solicitarReserva` y el mensaje están en vuelo | **VULNERABLE** |
| 3 | `chat_screen.dart:892` enviar; `:839`, `:1050`, `:1063` adjuntos; `:1400` editar mensaje | Sin flag, `onPressed`/`onTap` siguen activos | **VULNERABLE** |
| 4 | `reserva_detail_screen.dart:477` reprogramar | Sin flag ni guard durante `reprogramarReserva` | **VULNERABLE** |
| 5 | `cotizacion_chat_card.dart:452,460` aceptar/rechazar | Sin flag ni `onPressed: null`; callbacks escriben estado | **VULNERABLE** |
| 6 | `reserva_chat_card.dart:381,389,410,424` acciones de reserva | Sin flag ni guard; el estado puede seguir pendiente durante el write | **VULNERABLE** |
| 7 | `alerts_screen.dart:804` guardar kilometraje | Sin flag; `AppButton` no usa `isLoading` | **VULNERABLE** |
| 8 | `notifications_screen.dart:79` marcar todo leído | Sin flag ni guard en `markAllAsRead` | **VULNERABLE** |
| 9 | `vehicle_profile_screen.dart:1006` kilometraje; `:795` fechas; `:512` nueva nota | Sin flag que gobierne esos botones | **VULNERABLE** |
| 10 | `share_vehicle_sheet.dart:28` aceptar invitación; `:311` retirar usuario | Sin flag para esos botones; `_isLoading` solo protege agregar/aceptar dentro del sheet | **VULNERABLE** |
| 11 | `vehicle_gallery_widget.dart:45` subir foto | Sin flag ni deshabilitación durante Storage | **VULNERABLE** |
| 12 | `talleres_con_acceso_card.dart:241` retirar acceso | Sin flag; el botón sigue disponible durante el write | **VULNERABLE** |
| 13 | `catalogo_servicios_screen.dart:308` eliminar ítem | `CatalogoProvider.isLoading` no gobierna el botón de la tarjeta | **VULNERABLE** |
| 14 | `empleados_screen.dart:402` desactivar empleado | `EmpleadoProvider.isLoading` no gobierna el botón de la tarjeta | **VULNERABLE** |
| 15 | `mechanic_reviews_screen.dart:239` reportar; `:294` publicar respuesta; `:500` abrir respuesta | Sin flag de envío en esos flujos | **VULNERABLE** |
| 16 | Moderación admin: `admin_resenias_screen.dart:82,296`; `taller_admin_card.dart:108,122,129`; `admin_verificaciones_screen.dart:280,296,315,376` | `isLoading`/`resolviendo` reemplazan la lista o la fila por spinner; no usan `onPressed: null`, pero el control deja de estar montado | **PROTEGIDO** |
| 17 | `auth_screen.dart:470`; `email_verification_screen.dart:90,104,115` | Login usa `isLoading` y además `_submit` retorna si está cargando. Verificación usa `_busy ? null` y guard interno | **PROTEGIDO** |
| 18 | `admin/widgets/dialog_crear_usuario.dart:127` | `_isSubmitting ? null` y `isLoading` | **PROTEGIDO** |
| 19 | `cotizacion_picker.dart:277` | `_isSubmitting ? null : _submit`; `_submit` también tiene guard | **PROTEGIDO** |
| 20 | `reserva_detail_screen.dart:461,468,486,494` | Para cambios de estado, `_isLoading` reemplaza el cuerpo por spinner (`:310`). Cotizar abre el picker protegido | **PROTEGIDO** |
| 21 | `add_vehicle_form.dart:909`; `task_complete_screen.dart:380`; `task_config_screen.dart:189` | `_isFinishing`/`_isLoading` deshabilitan explícitamente o mediante `AppButton.isLoading` | **PROTEGIDO** |
| 22 | `vehicle_profile_screen.dart:1107` eliminar vehículo | `isVerifying` alimenta `AppButton.isLoading`, que bloquea taps aunque el callback no sea literalmente `null` | **PROTEGIDO** |
| 23 | `share_vehicle_sheet.dart:194,212` agregar/aceptar | `_isLoading ? null` | **PROTEGIDO** |
| 24 | `compartir_historial_screen.dart:219,305` emitir/revocar pase | `_cargando` oculta el botón de emitir; `_revocando` tiene guard y `isLoading` | **PROTEGIDO** |
| 25 | `workshop_gallery_screen.dart:247,255`; `vehicle_gallery_widget.dart:159` borrar foto | `slotEnCurso` reemplaza controles por spinner; borrar foto cierra la pantalla antes del write | **PROTEGIDO** |
| 26 | `initiate_service_screen.dart:864,1145,1196,1740` finalizar/recibir | `_isSaving` y `_recibiendo` deshabilitan; el reintento cambia a la rama con botón protegido | **PROTEGIDO** |
| 27 | `workshop_settings_screen.dart:237`; `workshop_verification_screen.dart:661,777` | `_isSaving`/`provider.enviando` usan `null`; `slotEnCurso` reemplaza el botón de subida | **PROTEGIDO** |
| 28 | `profile_setup_screen.dart:723`; `user_profile_screen.dart:211,767` | Flags gobiernan `onPressed: null` o `AppButton.isLoading` | **PROTEGIDO** |
| 29 | `core/widgets/review_sheet.dart:450`; `service_finalized_screen.dart:189` | `_isSubmitting` usa `null`; `_enviandoResenia` bloquea mediante `AppButton.isLoading` | **PROTEGIDO** |
| 30 | `service_history_screen.dart:777`; `review_chat_card.dart:92`; `cotizacion_chat_card.dart:483` | Solo leen/preparan datos y abren otro formulario; no escriben directamente | **N/A** |