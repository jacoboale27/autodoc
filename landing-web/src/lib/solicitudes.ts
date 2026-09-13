// Unico destino de los formularios de la landing.
//
// La landing es un export estatico (`output: "export"`), asi que no tiene
// servidor propio: cualquier envio tiene que salir a un endpoint. Antes de
// UX-01 habia dos respuestas a eso y las dos mentian — un `action="#"` que no
// enviaba nada, y un POST sin autenticar a la REST API de Firestore contra
// /talleres, coleccion cuya regla es `allow create: if isAdmin()` y que por
// tanto devolvia 403 siempre. Ahora ambos formularios hablan con la Cloud
// Function `recibirSolicitudLanding`, que valida, limita y persiste.
//
// La URL se puede sobreescribir en tiempo de compilacion para apuntar al
// emulador; `output: "export"` incrusta el valor en el bundle.
export const ENDPOINT_SOLICITUDES =
  process.env.NEXT_PUBLIC_SOLICITUDES_ENDPOINT ||
  "https://us-central1-autodoc-6ef5a.cloudfunctions.net/recibirSolicitudLanding";

export type TipoSolicitud = "contacto" | "afiliacion";

export type ResultadoEnvio =
  | { ok: true }
  | { ok: false; motivo: "invalido" | "limite" | "red" };

/**
 * Envia una solicitud y traduce la respuesta a los tres desenlaces que la UI
 * sabe contar. El endpoint responde con un codigo generico a proposito (no
 * dice que campo fallo), asi que aqui tampoco se inventa un detalle que no
 * existe.
 */
export async function enviarSolicitud(
  tipo: TipoSolicitud,
  campos: Record<string, string>,
): Promise<ResultadoEnvio> {
  try {
    const res = await fetch(ENDPOINT_SOLICITUDES, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tipo, ...campos }),
    });

    if (res.ok) return { ok: true };
    if (res.status === 429) return { ok: false, motivo: "limite" };
    if (res.status === 400) return { ok: false, motivo: "invalido" };
    return { ok: false, motivo: "red" };
  } catch {
    // Sin red, con el endpoint caido o con el POST bloqueado por CORS: para
    // quien escribe es el mismo hecho —no se envio— y hay que decirselo, no
    // ensenarle una pantalla de exito.
    return { ok: false, motivo: "red" };
  }
}
