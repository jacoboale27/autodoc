'use strict';

const { test, expect } = require('@playwright/test');
const {
  ACTORES,
  VEHICULOS,
  iniciarSesion,
  cerrarSesion,
  leerDoc,
  escribirDoc,
  borrarDoc,
} = require('./helpers');

// Matriz multirol de QA-01, ejercida a traves del bundle real de la app y
// contra los emuladores.
//
// Por que se pregunta a Firestore y no se miran botones: un guard de UI que
// esconde una opcion no prueba nada. La API sigue ahi y un atacante con esa
// sesion la llama directamente — de hecho es exactamente lo que hace este
// spec. Lo que se mide aqui es la barrera real, que son las reglas, con la
// sesion que la app establecio de verdad.
//
// Cada denegacion va emparejada con la operacion equivalente que SI se
// permite. Sin ese par, un rojo no distingue "las reglas protegen esto" de
// "la ruta estaba mal escrita y nadie puede leerla".

async function entrar(page, actor) {
  await page.goto('/');
  await iniciarSesion(page, actor);
}

test.describe('vehiculos: quien ve el coche de quien', () => {
  test('el propietario A lee su vehiculo', async ({ page }) => {
    await entrar(page, ACTORES.propietarioA);
    const r = await leerDoc(page, `vehiculos/${VEHICULOS.deA}`);
    expect(r.permitido).toBe(true);
    expect(r.datos.placa).toBe('E2E-AAA');
  });

  test('el propietario B NO lee el vehiculo de A', async ({ page }) => {
    await entrar(page, ACTORES.propietarioB);
    const r = await leerDoc(page, `vehiculos/${VEHICULOS.deA}`);
    expect(r.permitido).toBe(false);
  });

  test('el propietario A NO lee el vehiculo de B', async ({ page }) => {
    await entrar(page, ACTORES.propietarioA);
    const r = await leerDoc(page, `vehiculos/${VEHICULOS.deB}`);
    expect(r.permitido).toBe(false);
  });

  test('el taller A, vinculado, SI lee el vehiculo de A', async ({ page }) => {
    await entrar(page, ACTORES.tallerA);
    const r = await leerDoc(page, `vehiculos/${VEHICULOS.deA}`);
    expect(r.permitido).toBe(true);
  });

  test('el taller B, pendiente de aprobacion, NO lee el vehiculo de A', async ({ page }) => {
    // isMecanico() exige estado en ['aprobado','activo']. Un taller pendiente
    // inicia sesion perfectamente pero no accede a datos: el bloqueo del
    // enrutador no basta, la API es alcanzable directamente.
    await entrar(page, ACTORES.tallerB);
    const r = await leerDoc(page, `vehiculos/${VEHICULOS.deA}`);
    expect(r.permitido).toBe(false);
  });

  test('el administrador SI lee cualquier vehiculo', async ({ page }) => {
    await entrar(page, ACTORES.admin);
    const r = await leerDoc(page, `vehiculos/${VEHICULOS.deA}`);
    expect(r.permitido).toBe(true);
  });
});

test.describe('vehiculos: los invariantes que se cerraron en esta tarea', () => {
  test('el propietario NO puede regalar su vehiculo reescribiendo id_propietario', async ({ page }) => {
    await entrar(page, ACTORES.propietarioA);
    const r = await escribirDoc(page, `vehiculos/${VEHICULOS.deA}`, {
      id_propietario: ACTORES.propietarioB.uid,
    });
    expect(r.permitido).toBe(false);
  });

  test('el propietario NO puede vaciar talleres_conocidos para volver al estado walk-in', async ({ page }) => {
    await entrar(page, ACTORES.propietarioA);
    const r = await escribirDoc(page, `vehiculos/${VEHICULOS.deA}`, {
      talleres_conocidos: [],
      talleres_vinculados: [],
    });
    expect(r.permitido).toBe(false);
  });

  test('el propietario SI puede editar los datos de su vehiculo', async ({ page }) => {
    await entrar(page, ACTORES.propietarioA);
    const r = await escribirDoc(page, `vehiculos/${VEHICULOS.deA}`, {
      kilometraje_actual: 46000,
    });
    expect(r.permitido).toBe(true);

    // Releer: que la regla autorice el write no prueba que el dato quedara.
    const leido = await leerDoc(page, `vehiculos/${VEHICULOS.deA}`);
    expect(leido.datos.kilometraje_actual).toBe(46000);
  });
});

test.describe('usuarios: la frontera Administrador / Superusuario', () => {
  test('un propietario NO lee el perfil de otro', async ({ page }) => {
    await entrar(page, ACTORES.propietarioA);
    const r = await leerDoc(page, `usuarios/${ACTORES.propietarioB.uid}`);
    expect(r.permitido).toBe(false);
  });

  test('un propietario SI lee el suyo', async ({ page }) => {
    await entrar(page, ACTORES.propietarioA);
    const r = await leerDoc(page, `usuarios/${ACTORES.propietarioA.uid}`);
    expect(r.permitido).toBe(true);
    expect(r.datos.rol).toBe('Propietario');
  });

  test('un Administrador NO puede repartir el rol de Administrador', async ({ page }) => {
    await entrar(page, ACTORES.admin);
    const r = await escribirDoc(page, `usuarios/${ACTORES.propietarioB.uid}`, {
      rol: 'Administrador',
    });
    expect(r.permitido).toBe(false);
  });

  test('un Administrador NO puede borrar una cuenta', async ({ page }) => {
    await entrar(page, ACTORES.admin);
    const r = await borrarDoc(page, `usuarios/${ACTORES.desechable.uid}`);
    expect(r.permitido).toBe(false);
  });

  // El par del test anterior: misma operacion, mismo documento, otro rol. Es
  // lo que demuestra que quien decide es el rol y no otra puerta.
  test('el Superusuario SI puede borrar esa misma cuenta', async ({ page }) => {
    await entrar(page, ACTORES.superusuario);
    const r = await borrarDoc(page, `usuarios/${ACTORES.desechable.uid}`);
    expect(r.permitido).toBe(true);
  });
});

test.describe('sesion', () => {
  test('tras cerrar sesion se pierde el acceso a los datos', async ({ page }) => {
    await entrar(page, ACTORES.propietarioA);
    expect((await leerDoc(page, `vehiculos/${VEHICULOS.deA}`)).permitido).toBe(true);

    await cerrarSesion(page);

    const r = await leerDoc(page, `vehiculos/${VEHICULOS.deA}`);
    expect(r.permitido).toBe(false);
  });
});
