const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const seedCotizacion = async () => {
  await seed(env, async (s) => {
    await s.collection('cotizaciones').doc('c1').set({
      id_propietario: UIDS.owner1,
      id_mecanico: UIDS.taller1,
      id_taller: UIDS.taller1,
      items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
      estado: 'pendiente',
    });
    await s.collection('cotizaciones').doc('c1').collection('privado').doc('margen').set({ beneficios: [8] });
  });
};

describe('DATA-01: publicacion solo con contrato privado confirmado', () => {
  const draft = {
    id_propietario: UIDS.owner1,
    id_mecanico: UIDS.taller1,
    id_taller: UIDS.taller1,
    items: [{ material: 'Filtro', cantidad: 1, costo: 20 }],
    estado: 'draft',
  };

  test('no permite crear directamente ningun estado publicado', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    for (const estado of ['pendiente', 'aceptada', 'rechazada', 'finalizada']) {
      await assertFails(db.collection('cotizaciones').doc(estado).set({ ...draft, estado }));
    }
  });

  test('draft no se publica sin margen ni se acepta o finaliza aun con margen', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    const owner = await withRole(env, UIDS.owner1, 'Propietario');
    const ref = db.collection('cotizaciones').doc('draft');
    await assertSucceeds(ref.set(draft));
    await assertFails(ref.update({ estado: 'pendiente' }));
    await assertSucceeds(ref.collection('privado').doc('margen').set({ beneficios: [8] }));
    for (const estado of ['aceptada', 'rechazada', 'pendiente']) {
      await assertFails(owner.collection('cotizaciones').doc('draft').update({ estado }));
    }
    await assertFails(ref.update({ estado: 'finalizada' }));
    await assertSucceeds(ref.update({ estado: 'pendiente' }));
    await assertSucceeds(owner.collection('cotizaciones').doc('draft').update({ estado: 'aceptada' }));
  });

  test('rechaza margen invalido y permite limpiar el draft tras fallo privado', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    const ref = db.collection('cotizaciones').doc('draft');
    await assertSucceeds(ref.set(draft));
    for (const data of [{}, { beneficios: [] }, { beneficios: '8' }, { beneficios: [8], extra: true }]) {
      await assertFails(ref.collection('privado').doc('margen').set(data));
    }
    await assertFails(ref.update({ estado: 'pendiente' }));
    await assertSucceeds(ref.delete());
  });

  test('no permite borrar el contrato al publicar ni despues de publicar', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    const ref = db.collection('cotizaciones').doc('draft');
    const margen = ref.collection('privado').doc('margen');
    await assertSucceeds(ref.set(draft));
    await assertSucceeds(margen.set({ beneficios: [8] }));
    const batch = db.batch();
    batch.update(ref, { estado: 'pendiente' });
    batch.delete(margen);
    await assertFails(batch.commit());
    await assertSucceeds(ref.update({ estado: 'pendiente' }));
    await assertFails(margen.delete());
    await assertFails(margen.set({ beneficios: [] }));
    await assertFails(ref.delete());
    await assertFails(ref.update({ estado: 'draft' }));
  });

  test('no publica el margen y el padre juntos sin confirmacion previa', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    const ref = db.collection('cotizaciones').doc('draft');
    await assertSucceeds(ref.set(draft));
    const batch = db.batch();
    batch.set(ref.collection('privado').doc('margen'), { beneficios: [8] });
    batch.update(ref, { estado: 'pendiente' });
    await assertFails(batch.commit());
  });
});

describe('cotizaciones update (hallazgo H1: campo abierto permitia alterar precio/partes)', () => {
  test('el propietario SI puede aceptar (solo estado)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico SI puede finalizar (solo estado)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });

  test('el propietario NO puede alterar los items (precio) al aceptar', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({
        estado: 'aceptada',
        items: [{ material: 'Aceite', cantidad: 1, costo: 1 }],
      }),
    );
  });

  test('el mecanico NO puede reasignar id_propietario', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({
        id_propietario: UIDS.owner2,
      }),
    );
  });

  test('un tercero no vinculado NO puede actualizar la cotizacion', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });
});

describe('cotizaciones update (revision de rama completa, hallazgo C1: el mecanico se auto-emitia el gate del trigger)', () => {
  // Antes de esta ronda, `update` solo comprobaba QUIEN escribia, nunca QUE
  // valor de `estado` escribia cada uno. Un mecanico podia aceptar su propia
  // cotizacion sobre un vehiculo ajeno y con eso disparar el unico requisito
  // que `onCotizacionAceptada` exige para abrir un ticket de `reparaciones`.
  test('el mecanico NO puede auto-aceptar su propia cotizacion', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico NO puede auto-rechazar la cotizacion tampoco (solo el propietario resuelve pendiente/aceptada/rechazada)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'rechazada' }),
    );
  });

  test('el propietario SI puede aceptar la cotizacion (camino legitimo)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });

  test('el mecanico SI puede marcar finalizada (camino legitimo)', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });

  test('el propietario NO puede marcar finalizada', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });
});

describe('cotizaciones/privado/margen (hallazgo H2: el beneficio no debe ser legible por el propietario)', () => {
  const seedMargen = async () => {
    await seed(env, async (s) => {
      await s.collection('cotizaciones').doc('c1').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'pendiente',
      });
      await s.collection('cotizaciones').doc('c1').collection('privado').doc('margen').set({
        beneficios: [8],
      });
    });
  };

  test('el mecanico dueño SI puede leer su margen', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('el propietario NO puede leer el margen del mecanico', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.owner1, 'Propietario');
    await assertFails(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('un tercero no vinculado NO puede leer el margen', async () => {
    await seedMargen();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').collection('privado').doc('margen').get(),
    );
  });

  test('el mecanico SI puede crear la cotizacion y su margen privado en tres pasos (flujo real de ChatRepository.crearCotizacion)', async () => {
    // FIX 1 (Ronda 2): `create` ahora exige que id_propietario sea el dueño
    // REAL de id_vehiculo (getVehicleOwner), asi que este fixture necesita
    // un vehiculo de verdad en vez de solo los ids sueltos que bastaban antes.
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-c2').set({
        id_propietario: UIDS.owner1,
        placa: 'DEF456',
      });
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c2').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_vehiculo: 'v-c2',
        id_taller: UIDS.taller1,
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'draft',
      }),
    );
    await assertSucceeds(
      db.collection('cotizaciones').doc('c2').collection('privado').doc('margen').set({
        beneficios: [8],
      }),
    );
    await assertSucceeds(
      db.collection('cotizaciones').doc('c2').update({ estado: 'pendiente' }),
    );
  });

  // Residual encontrado en la re-revision de la revision de rama: acotar el
  // `update` por rol y valor no sirve de nada si el `create` deja elegir el
  // estado inicial. Crear ya en 'aceptada' no dispara `onCotizacionAceptada`
  // (es un onUpdate), pero deja escrito un consentimiento del propietario que
  // el propietario nunca dio. Cuando existia el callable de apertura manual
  // (`iniciarReparacionPorVehiculo`, retirado en FUNC-02) eso bastaba para
  // abrir un ticket; el dato sigue siendo la prueba de consentimiento en el
  // resto de la app, asi que fijar el estado inicial en 'draft' sigue siendo
  // lo que impide fabricarla.
  test('el mecanico NO puede crear la cotizacion ya en estado aceptada', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c3').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'v-ajeno',
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'aceptada',
      }),
    );
  });

  // Flujo real: un cliente contacta a un taller desde el DIRECTORIO
  // (workshop_directory_screen.dart:1209), que NO pasa idVehiculo. Esa
  // conversacion no tiene vehiculo, asi que CotizacionModel.toMap() omite
  // la clave 'id_vehiculo' por completo (cotizacion_model.dart:111). Si la
  // regla hace getVehicleOwner() sobre un campo inexistente, revienta con
  // "property is undefined" y DENIEGA — rompiendo la via mas comun de
  // cotizar. No hay riesgo en permitirlo: sin id_vehiculo no se puede
  // encadenar el ataque (existeCotizacionAceptada busca por vehiculo), y
  // aceptar sigue exigiendo ser el id_propietario nombrado.
  test('el mecanico SI puede cotizar en un chat SIN vehiculo (contacto desde el directorio)', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c5').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        items: [{ material: 'Diagnostico', cantidad: 1, costo: 15 }],
        estado: 'draft',
      }),
    );
  });

  // NOTA DE HONESTIDAD (senalada al re-revisar): este test es de
  // DOCUMENTACION, no un detector de regresion. Un error de evaluacion
  // tambien llega al cliente como `permission-denied`, asi que este caso
  // pasaba igual ANTES del guarda con exists() y seguiria pasando si se
  // revirtiera. La API de rules-unit-testing no distingue "denegado" de
  // "reventado". Se conserva porque fija la intencion; no se conserva como
  // prueba de que el guarda sigue ahi.
  //
  // El dueño puede borrar su vehiculo y la conversacion conserva el
  // id_vehiculo. Denegar esta bien; denegar POR ERROR DE EVALUACION no: el
  // mensaje no explica nada y la regla deja de poder razonarse.
  test('cotizar sobre un vehiculo que ya no existe deniega limpiamente', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c6').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        id_vehiculo: 'vehiculo-borrado',
        items: [],
        estado: 'draft',
      }),
    );
  });

  test('el mecanico NO puede crear la cotizacion ya en estado finalizada', async () => {
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c4').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.taller1,
        id_taller: UIDS.taller1,
        items: [],
        estado: 'finalizada',
      }),
    );
  });
});

// Ronda 2 (FIX 1): hasta aqui, `create` solo comprobaba `id_mecanico ==
// auth.uid` y `estado == 'pendiente'`. NADA ataba `id_propietario`,
// `id_vehiculo` o `id_taller` a la realidad. Un reviewer PROBO contra el
// emulador que un mecanico podia crear
// {id_mecanico: self, id_propietario: SELF, id_vehiculo: <vehiculo ajeno>,
// estado: 'pendiente'} y luego, con la rama DEL PROPIETARIO de `update` (ya
// blindada por rol+valor), aceptarsela el mismo — dos escrituras hasta
// 'aceptada' — una prueba de consentimiento del propietario fabricada sin el.
// (En su dia era ademas lo que buscaba el gate del callable de apertura
// manual, retirado en FUNC-02.)
describe('cotizaciones create (FIX 1: ataque de auto-aceptacion en dos escrituras)', () => {
  const seedVehiculoAjeno = async () =>
    seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-victima').set({
        id_propietario: UIDS.owner1,
        placa: 'XYZ999',
        talleres_vinculados: [],
      });
    });

  test('ATAQUE: el mecanico NO puede crear una cotizacion nombrandose a si mismo id_propietario sobre el vehiculo de otro', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('ataque1').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.taller1, // se nombra a si mismo, no al dueño real
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1,
        items: [],
        estado: 'draft',
      }),
    );
  });

  test('ATAQUE (variante): id_propietario apunta a un tercero cualquiera, no al dueño real del vehiculo', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('ataque2').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.owner2, // no es el dueño real (owner1)
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1,
        items: [],
        estado: 'draft',
      }),
    );
  });

  test('ATAQUE: un mecanico NO puede crear en nombre de un taller ajeno (actuaPorTaller falla)', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('ataque3').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.owner1, // dueño real, para aislar el chequeo de taller
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller2, // taller ajeno
        items: [],
        estado: 'draft',
      }),
    );
  });

  test('LEGITIMO: el mecanico crea la cotizacion sobre su propio vehiculo del dueño real', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('legitimo1').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.owner1,
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1,
        items: [],
        estado: 'draft',
      }),
    );
  });

  test('LEGITIMO: un EMPLEADO del taller crea la cotizacion en nombre del taller dueño (actuaPorTaller)', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.empleado1, 'Mecanico', {
      id_taller_propietario: UIDS.taller1,
    });
    await assertSucceeds(
      db.collection('cotizaciones').doc('legitimo2').set({
        id_mecanico: UIDS.empleado1,
        id_propietario: UIDS.owner1,
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1, // uid del DUEÑO, no del empleado
        items: [],
        estado: 'draft',
      }),
    );
  });

  test('LEGITIMO: cotizacion con reserva asociada (reserva_chat_card/reserva_detail_screen), mismo dueño real', async () => {
    await seedVehiculoAjeno();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('legitimo3').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.owner1,
        id_vehiculo: 'v-victima',
        id_taller: UIDS.taller1,
        id_reserva: 'r1',
        items: [],
        estado: 'draft',
      }),
    );
  });

  test('ATAQUE: el mecanico no puede ser su propio propietario aunque de casualidad sea dueño de su propio vehiculo', async () => {
    await seed(env, async (s) => {
      await s.collection('vehiculos').doc('v-propio').set({
        id_propietario: UIDS.taller1,
        placa: 'ABC111',
        talleres_vinculados: [],
      });
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('ataque4').set({
        id_mecanico: UIDS.taller1,
        id_propietario: UIDS.taller1,
        id_vehiculo: 'v-propio',
        id_taller: UIDS.taller1,
        items: [],
        estado: 'draft',
      }),
    );
  });
});

describe('cotizaciones: la cotizacion es del TALLER, no del operario (ronda 4)', () => {
  // En un taller con empleados, quien redacta la cotizacion y quien cierra el
  // servicio casi nunca son la misma persona. Las reglas trataban la
  // cotizacion como propiedad del uid que la escribio, y eso rompia los dos
  // extremos del flujo: el resto del taller no podia LEERLA (la ficha publica
  // del vehiculo les decia que no habia cotizacion aceptada) ni marcarla
  // 'finalizada' al cerrar el servicio.

  test('un EMPLEADO del taller puede leer la cotizacion que escribio el dueño', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.empleado1, 'Mecanico', {
      id_taller_propietario: UIDS.taller1,
    });
    await assertSucceeds(db.collection('cotizaciones').doc('c1').get());
  });

  test('un mecanico de OTRO taller sigue sin poder leerla', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.empleado2, 'Mecanico', {
      id_taller_propietario: UIDS.taller2,
    });
    await assertFails(db.collection('cotizaciones').doc('c1').get());
  });

  test('el DUEÑO puede finalizar la cotizacion que redacto su empleado', async () => {
    // Espejo del caso real: InitiateServiceScreen marca 'finalizada' con el
    // uid de quien cierra el servicio. Con la regla vieja
    // (`id_mecanico == auth.uid`) esto moria en permission-denied DESPUES de
    // haber registrado ya el servicio, y el ticket nunca llegaba a
    // 'listo_para_entrega'.
    await seed(env, async (s) => {
      await s.collection('cotizaciones').doc('c2').set({
        id_propietario: UIDS.owner1,
        id_mecanico: UIDS.empleado1,
        id_taller: UIDS.taller1,
        items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
        estado: 'aceptada',
      });
      await s.collection('cotizaciones').doc('c2').collection('privado').doc('margen').set({ beneficios: [8] });
    });
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertSucceeds(
      db.collection('cotizaciones').doc('c2').update({ estado: 'finalizada' }),
    );
  });

  test('un mecanico de otro taller NO puede finalizarla', async () => {
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller2, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'finalizada' }),
    );
  });

  test('el taller sigue sin poder ACEPTAR su propia cotizacion (invariante A1)', async () => {
    // El ensanche de arriba no puede abrir la puerta que la Ronda 2 cerro:
    // quien propone no resuelve.
    await seedCotizacion();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones').doc('c1').update({ estado: 'aceptada' }),
    );
  });
});

// Observaciones del 2026-09-19 (captura 7): «No se pudo comprobar si el
// cliente aprobo una cotizacion para este vehiculo». InitiateServiceScreen
// preguntaba por las cotizaciones aceptadas del coche solo con `id_vehiculo`
// + `estado`. Las reglas no filtran: rechazan la consulta ENTERA si no pueden
// demostrar que todo lo que devolveria es legible, y esa consulta podria
// devolver cotizaciones de otros talleres. Fallaba siempre, con o sin indice.
describe('cotizaciones: las consultas de lista del taller (2026-09-19)', () => {
  const seedAceptadas = async () => {
    await seed(env, async (s) => {
      for (const [id, taller] of [['a1', UIDS.taller1], ['a2', UIDS.taller2]]) {
        await s.collection('cotizaciones').doc(id).set({
          id_propietario: UIDS.owner1,
          id_mecanico: taller,
          id_taller: taller,
          id_vehiculo: 'v1',
          items: [{ material: 'Aceite', cantidad: 1, costo: 20 }],
          estado: 'aceptada',
          fecha: new Date('2026-09-18T10:00:00Z'),
        });
      }
    });
  };

  test('la consulta de antes (sin id_taller) se rechaza: era la captura 7', async () => {
    await seedAceptadas();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones')
        .where('id_vehiculo', '==', 'v1')
        .where('estado', '==', 'aceptada')
        .get(),
    );
  });

  test('filtrando por su id_taller, el taller SI puede listar las aceptadas del coche', async () => {
    await seedAceptadas();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    const snap = await assertSucceeds(
      db.collection('cotizaciones')
        .where('id_vehiculo', '==', 'v1')
        .where('id_taller', '==', UIDS.taller1)
        .where('estado', '==', 'aceptada')
        .get(),
    );
    expect(snap.docs.map((d) => d.id)).toEqual(['a1']);
  });

  test('un EMPLEADO lista las del taller con el id_taller del dueño', async () => {
    await seedAceptadas();
    const db = await withRole(env, UIDS.empleado1, 'Taller', {
      id_taller_propietario: UIDS.taller1,
    });
    await assertSucceeds(
      db.collection('cotizaciones')
        .where('id_vehiculo', '==', 'v1')
        .where('id_taller', '==', UIDS.taller1)
        .where('estado', '==', 'aceptada')
        .get(),
    );
  });

  test('nadie lista las de un taller ajeno, aunque filtre por su id', async () => {
    await seedAceptadas();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    await assertFails(
      db.collection('cotizaciones')
        .where('id_vehiculo', '==', 'v1')
        .where('id_taller', '==', UIDS.taller2)
        .get(),
    );
  });

  test('"Mis Servicios": el taller lista todas las suyas ordenadas por fecha', async () => {
    await seedAceptadas();
    const db = await withRole(env, UIDS.taller1, 'Taller');
    const snap = await assertSucceeds(
      db.collection('cotizaciones')
        .where('id_taller', '==', UIDS.taller1)
        .orderBy('fecha', 'desc')
        .limit(200)
        .get(),
    );
    expect(snap.docs.map((d) => d.id)).toEqual(['a1']);
  });
});
