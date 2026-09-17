#!/usr/bin/env bash
#
# Configura en GitHub los secretos que el job `release_apk` necesita y que hoy
# no existen. Se ejecuta UNA vez, desde la raiz del repo, con `gh` ya
# autenticado.
#
#   bash scripts/configurar_secretos_android.sh
#
# Por que un script y no una lista de comandos para copiar y pegar: los valores
# salen de `.env` y de `android/key.properties`, que estan en .gitignore y no
# deben pasar por el portapapeles, por una transcripcion ni por el historial del
# shell. Aqui viajan de fichero a `gh secret set` por stdin y no se imprimen
# nunca — el script solo dice el NOMBRE de cada secreto que escribe.
#
# Es idempotente: `gh secret set` sobrescribe si el secreto ya existe.

set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE=".env"
KEY_PROPS="android/key.properties"
GS_JSON="android/app/google-services.json"

fallo=0
for f in "$ENV_FILE" "$KEY_PROPS" "$GS_JSON"; do
  if [ ! -f "$f" ]; then
    echo "FALTA: $f"
    fallo=1
  fi
done
[ "$fallo" -eq 0 ] || { echo "Aborta: faltan ficheros de origen."; exit 1; }

# Lee una clave de un fichero tipo `CLAVE=valor`. Se usa para .env y para
# key.properties, que comparten formato.
leer() {
  local fichero="$1" clave="$2"
  sed -n "s/^${clave}=//p" "$fichero" | head -1 | tr -d '\r'
}

# Escribe un secreto sin que su valor toque la salida.
poner() {
  local nombre="$1" valor="$2"
  if [ -z "$valor" ]; then
    echo "  OMITIDO  $nombre  (vacio en el fichero de origen)"
    return
  fi
  printf '%s' "$valor" | gh secret set "$nombre"
  echo "  puesto   $nombre"
}

echo "== Secretos que salen de $ENV_FILE =="
for clave in \
  FIREBASE_ANDROID_API_KEY \
  FIREBASE_APP_ID_ANDROID \
  FIREBASE_DATABASE_URL \
  FIREBASE_MEASUREMENT_ID \
  GOOGLE_MAPS_API_KEY_ANDROID \
  RECAPTCHA_SITE_KEY \
  VEHICLE_IMAGE_API_KEY; do
  poner "$clave" "$(leer "$ENV_FILE" "$clave")"
done

echo
echo "== Secretos de firma, que salen de $KEY_PROPS =="
poner ANDROID_KEY_ALIAS "$(leer "$KEY_PROPS" keyAlias)"
poner ANDROID_KEYSTORE_PASSWORD "$(leer "$KEY_PROPS" storePassword)"
poner ANDROID_KEY_PASSWORD "$(leer "$KEY_PROPS" keyPassword)"

echo
echo "== Ficheros binarios en base64 =="

# La keystore. `storeFile` puede ser absoluta (lo habitual, porque la keystore
# vive FUERA del repo a proposito) o relativa a android/.
STORE="$(leer "$KEY_PROPS" storeFile)"
if [ ! -f "$STORE" ]; then
  if [ -f "android/$STORE" ]; then
    STORE="android/$STORE"
  else
    echo "  ERROR    no se encuentra la keystore: $STORE"
    exit 1
  fi
fi
# base64 -w0: en UNA sola linea, sin saltos, que es lo que el workflow espera
# al hacer `base64 -d`. Con saltos el decode falla y el job muere firmando.
poner ANDROID_KEYSTORE_BASE64 "$(base64 -w0 "$STORE")"
poner GOOGLE_SERVICES_JSON_BASE64 "$(base64 -w0 "$GS_JSON")"

echo
echo "Listo. Comprueba con:  gh secret list"
echo
echo "RECUERDA: google-services.json esta en .gitignore (linea 59), asi que"
echo "este secreto es la UNICA copia que ve el CI. Si vuelves a bajarlo de"
echo "Firebase —por ejemplo tras registrar el SHA-1 de Play App Signing—,"
echo "hay que volver a correr este script o el CI seguira con el viejo."
