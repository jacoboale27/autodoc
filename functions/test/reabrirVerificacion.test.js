'use strict';

/**
 * Cobertura de la re-revision: cuando un taller YA aprobado cambia datos que
 * un humano habia contrastado, su expediente vuelve solo a la cola.
 *
 * Sin esto, verificar era un sello de un solo uso: pasabas la revision con un
 * nombre y una direccion reales, y despues los cambiabas por cualquier otra
 * cosa sin que nadie volviera a mirarlo. Y tenia que vivir en una Cloud
 * Function, no en la app: si lo disparara la pantalla de ajustes, bastaria
 * con escribir en Firestore por otra via para esquivarlo.
 *
 * Se testea contra un doble de Firestore en vez de contra el emulador porque
 * lo que hay que fijar es la maquina de estados —de que origen se reabre y de
 * cuales no—, no el transporte. El emulador ya cubre las reglas en test_rules/.
 */

const assert = require('assert');

const {
  camposDeIdentidadCambiados,
  construirReapertura,
  reabrirSiCambioLaIdentidad,
} = require('../src/reabrirVerificacion');

/** Doc minimo de un taller aprobado. */
function taller(extra) {
  return Object.assign(
    {
      nombre_completo: 'Taller El Buen Motor',
      telefono: '7777-7777',
      especialidad: 'Frenos',
      departamento: 'San Salvador',
      municipio: 'Soyapango',
      latitud: 13.69,
      longitud: -89.19,
      estado: 'activo',
      rol: 'Taller',
    },
    extra
  );
}

/**
 * Doble de Firestore con lo justo: un doc de `verificaciones` y una
 * transaccion que lee y escribe sobre el.
 */
function fakeDb(expediente) {
  const estado = { doc: expediente ? Object.assign({}, expediente) : null };
  const escrituras = [];

  const ref = { __id: 'ref' };
  const db = {
    collection: (nombre) => ({
      doc: () => {
        assert.strictEqual(nombre, 'verificaciones');
        return ref;
      },
    }),
    runTransaction: (fn) =>
      fn({
        get: async () => ({
          exists: estado.doc !== null,
          data: () => estado.doc,
        }),
        set: (destino, datos, opciones) => {
          assert.strictEqual(destino, ref);
          escrituras.push({ datos, opciones });
          estado.doc = Object.assign({}, estado.doc, datos);
        },
      }),
  };

  return { db, escrituras, estado };
}

const SELLO = new Date('2026-08-27T10:00:00Z');

const reabrir = (fake, antes, despues) =>
  reabrirSiCambioLaIdentidad(fake.db, 'taller-1', antes, despues, SELLO);

describe('camposDeIdentidadCambiados', () => {
  it('no ve cambio donde no lo hay', () => {
    assert.deepStrictEqual(camposDeIdentidadCambiados(taller(), taller()), []);
  });

  it('detecta cada campo que el administrador tuvo que verificar', () => {
    const casos = [
      [{ nombre_completo: 'Otro Taller' }, 'Nombre del taller'],
      [{ telefono: '2222-2222' }, 'Teléfono de contacto'],
      [{ especialidad: 'Motor' }, 'Especialidad'],
      [{ departamento: 'La Libertad' }, 'Departamento'],
      [{ municipio: 'Santa Tecla' }, 'Municipio'],
      [{ latitud: 14.0 }, 'Ubicación en el mapa'],
      [{ longitud: -88.0 }, 'Ubicación en el mapa'],
      [{ direccion: 'Otra calle' }, 'Dirección'],
    ];

    for (const [cambio, etiqueta] of casos) {
      assert.deepStrictEqual(
        camposDeIdentidadCambiados(taller(), taller(cambio)),
        [etiqueta],
        `cambiar ${JSON.stringify(cambio)} deberia reabrir por «${etiqueta}»`
      );
    }
  });

  it('mover el pin del mapa cuenta como UN cambio, no como dos', () => {
    // latitud y longitud comparten etiqueta: media ubicacion no situa nada.
    assert.deepStrictEqual(
      camposDeIdentidadCambiados(taller(), taller({ latitud: 14, longitud: -88 })),
      ['Ubicación en el mapa']
    );
  });

  it('no reabre por reseñas ni por el propio estado de la cuenta', () => {
    // `calificacion_promedio` y `total_resenias` los escribe el sistema cada
    // vez que un cliente valora: incluirlos convertiria cada reseña en una
    // re-revision. Y `estado` es lo que escribe la propia resolucion del
    // expediente, asi que reabrir por el seria un ciclo aprobar -> reabrir.
    const despues = taller({
      calificacion_promedio: 4.8,
      total_resenias: 31,
      estado: 'rechazado',
      fcm_token: 'otro-token',
      correo: 'nuevo@example.com',
    });

    assert.deepStrictEqual(camposDeIdentidadCambiados(taller(), despues), []);
  });

  it('no reabre por cambiar el escaparate comercial', () => {
    // Decision consciente: logo y galeria se tocan a menudo y no son lo que se
    // contrasto contra el NIT. La contrapartida esta anotada como limitacion
    // en reabrirVerificacion.js (un logo puede suplantar una franquicia).
    const despues = taller({
      galeria: ['logo.png', 'local-1.jpg'],
      foto_perfil_url: 'https://firebasestorage.googleapis.com/v0/b/b/o/x',
    });

    assert.deepStrictEqual(camposDeIdentidadCambiados(taller(), despues), []);
  });

  it('ausente, null y cadena vacia son el mismo hecho', () => {
    // Un set(merge:false) que deja de escribir una clave opcional no es una
    // edicion del taller, y no debe mandarlo a la cola.
    assert.deepStrictEqual(
      camposDeIdentidadCambiados({ telefono: null }, {}),
      []
    );
    assert.deepStrictEqual(
      camposDeIdentidadCambiados({ telefono: '' }, { telefono: null }),
      []
    );
  });

  it('un espacio de mas no es un cambio, pero un nombre distinto si', () => {
    assert.deepStrictEqual(
      camposDeIdentidadCambiados(
        { nombre_completo: 'Taller Z' },
        { nombre_completo: '  Taller Z  ' }
      ),
      []
    );
    assert.deepStrictEqual(
      camposDeIdentidadCambiados(
        { nombre_completo: 'Taller Z' },
        { nombre_completo: 'Taller Bosch Autorizado' }
      ),
      ['Nombre del taller']
    );
  });

  it('rellenar un campo que estaba vacio tambien cuenta', () => {
    assert.deepStrictEqual(
      camposDeIdentidadCambiados({}, { direccion: 'Calle 1' }),
      ['Dirección']
    );
  });
});

describe('construirReapertura', () => {
  it('devuelve el expediente a la cola SIN dueño', () => {
    // 'listo_para_revision' y no 'en_revision': un expediente reabierto no lo
    // esta mirando nadie todavia, y saltarse el paso de tomar el caso es lo
    // que permitiria que dos administradores lo resolvieran a la vez.
    const parche = construirReapertura('t1', ['Dirección'], SELLO);

    assert.strictEqual(parche.estado_verificacion, 'listo_para_revision');
    assert.strictEqual(parche.id_taller, 't1');
  });

  it('deja escrito que mirar', () => {
    const parche = construirReapertura('t1', ['Dirección', 'Municipio'], SELLO);

    assert.deepStrictEqual(parche.reapertura.campos, ['Dirección', 'Municipio']);
    assert.strictEqual(parche.reapertura.fecha, SELLO);
  });

  it('no toca quien aprobo la version anterior', () => {
    // `revisado_por` y `fecha_revision` son el rastro de la ultima decision
    // humana, y es justo lo que el siguiente revisor quiere ver.
    const parche = construirReapertura('t1', ['Dirección'], SELLO);

    assert.ok(!('revisado_por' in parche));
    assert.ok(!('fecha_revision' in parche));
    assert.ok(!('documentos' in parche));
  });

  it('reordena la cola por la fecha de reapertura', () => {
    // La bandeja ordena por fecha_envio para atender primero a quien lleva
    // mas esperando. Si un expediente reabierto conservara su envio original
    // —de hace meses— se colaria siempre en cabeza, por delante de talleres
    // que todavia no pueden operar.
    assert.strictEqual(construirReapertura('t1', ['x'], SELLO).fecha_envio, SELLO);
  });
});

describe('reabrirSiCambioLaIdentidad', () => {
  it('reabre un expediente aprobado y escribe por que', async () => {
    const fake = fakeDb({ estado_verificacion: 'aprobada', revisado_por: 'admin-1' });

    const campos = await reabrir(fake, taller(), taller({ direccion: 'Otra calle' }));

    assert.deepStrictEqual(campos, ['Dirección']);
    assert.strictEqual(fake.escrituras.length, 1);
    assert.strictEqual(fake.escrituras[0].datos.estado_verificacion, 'listo_para_revision');
    assert.deepStrictEqual(fake.escrituras[0].opciones, { merge: true });
    // merge:true y no un set entero: el expediente lleva la evidencia subida
    // por el taller, y perderla dejaria al administrador sin nada que mirar.
    assert.strictEqual(fake.estado.doc.revisado_por, 'admin-1');
  });

  it('no escribe nada si no cambio ningun dato verificado', async () => {
    const fake = fakeDb({ estado_verificacion: 'aprobada' });

    const campos = await reabrir(fake, taller(), taller({ total_resenias: 9 }));

    assert.strictEqual(campos, null);
    assert.strictEqual(fake.escrituras.length, 0);
  });

  it('no toca un expediente que aun no ha sido aprobado', async () => {
    // Forzar aqui seria sacar de la cola a un taller a medio rellenar, o
    // pisarle el caso a un administrador que lo tiene abierto.
    for (const estado of ['perfil_incompleto', 'listo_para_revision', 'en_revision', 'rechazada']) {
      const fake = fakeDb({ estado_verificacion: estado });

      const campos = await reabrir(fake, taller(), taller({ municipio: 'Otro' }));

      assert.strictEqual(campos, null, `no deberia reabrir desde ${estado}`);
      assert.strictEqual(fake.escrituras.length, 0);
    }
  });

  it('un taller sin expediente no estrena uno', async () => {
    // Talleres aprobados por la via antigua (AdminService.aprobarTaller, que
    // solo escribe usuarios.estado) no tienen documento en verificaciones.
    // Crearselo aqui los meteria a todos en la bandeja en su primera edicion.
    const fake = fakeDb(null);

    const campos = await reabrir(fake, taller(), taller({ telefono: '2222-2222' }));

    assert.strictEqual(campos, null);
    assert.strictEqual(fake.escrituras.length, 0);
  });

  it('editar dos veces seguidas no encola dos veces', async () => {
    // La segunda edicion encuentra el expediente ya en 'listo_para_revision'.
    const fake = fakeDb({ estado_verificacion: 'aprobada' });

    await reabrir(fake, taller(), taller({ municipio: 'Otro' }));
    const segunda = await reabrir(
      fake,
      taller({ municipio: 'Otro' }),
      taller({ municipio: 'Un tercero' })
    );

    assert.strictEqual(segunda, null);
    assert.strictEqual(fake.escrituras.length, 1);
  });
});
