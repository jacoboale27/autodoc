// Destinos externos de la landing, en un solo sitio.
//
// UX-01: el badge de la App Store apuntaba a
// `https://apps.apple.com/app/id123456789` — un id de ejemplo. El enlace no
// lleva a ninguna ficha: promete una descarga que no existe. Mientras no haya
// ficha publica, el badge no se muestra; el dia que la haya, se pone la URL
// aqui y vuelve a aparecer en el hero y en el pie a la vez.
export const APP_STORE_URL: string | null = null;

// El id coincide con el applicationId real de la app Android
// (android/app/build.gradle.kts), asi que este enlace tiene destino.
export const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=com.autodoc.app";

// La web app desplegada en el hosting `app` (ver firebase.json).
export const WEB_APP_URL = "https://autodoc-6ef5a.web.app";
