# Corrección del crash de la landing por calificaciones

## Objetivo

Restaurar la carga completa de `autodoc.agency` eliminando el `TypeError` provocado por
`rating.toFixed` y retirar Vercel Analytics, cuya ruta de ingesta no existe en Firebase
Hosting.

## Causa confirmada

La API REST de Firestore representa `integerValue` y `doubleValue` como cadenas. La landing
asigna esa cadena a `Workshop.rating`, aunque la interfaz declara un `number`, y después llama
`toFixed(1)`. Cuando existe al menos un taller aprobado con calificación, React lanza una
excepción durante el render y Next.js sustituye la página por su pantalla de error.

Separadamente, el componente `Analytics` de Vercel solicita `/_vercel/insights/script.js`.
Firebase Hosting no implementa esa ruta, por lo que devuelve 404. Este 404 no causa el crash,
pero la integración no aporta telemetría funcional en el alojamiento actual.

## Diseño

1. Extraer una función pequeña y pura que reciba los campos REST de una calificación,
   convierta `doubleValue` o `integerValue` con `Number` y devuelva `5` cuando el campo falte,
   no sea numérico o no sea finito.
2. Usar el resultado normalizado al construir cada `Workshop`, manteniendo `rating` como
   `number` en todo el componente.
3. Eliminar el import y el render de `Analytics`, retirar `@vercel/analytics` de las
   dependencias y actualizar el lockfile con el gestor ya usado por la landing.
4. No cambiar estilos, textos, formularios, consultas, reglas ni datos de producción.

## Pruebas y verificación

- Una prueba unitaria debe reproducir `integerValue: "5"` y `doubleValue: "4.5"`, además de
  comprobar el fallback para valores ausentes o inválidos.
- La prueba se ejecutará primero en rojo antes de crear la función de producción.
- Se ejecutarán la prueba enfocada, el lint y el build estático de Next.js.
- La salida construida se servirá localmente y se abrirá con navegador automatizado,
  interceptando la lectura REST con un fixture que conserve el formato de Firestore. La página
  debe renderizar la calificación y no registrar ni `rating.toFixed` ni solicitudes a
  `/_vercel/insights/script.js`.

## Entrega

El cambio quedará en la rama `fix/landing-crash`, creada desde `integracion/ola-1`. La política
del repositorio prohíbe desplegar a producción desde una sesión de agente, por lo que se dejará
el artefacto verificado y el comando limitado al target `landing` para que el propietario lo
ejecute conscientemente.
