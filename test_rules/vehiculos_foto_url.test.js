// `vehiculos.foto_url` solo puede apuntar a nuestro propio Storage.
//
// Hasta el 2026-09-17 la app rellenaba este campo sola con enlaces raspados
// de Google Imagenes (VehicleImageService, retirado). Dos problemas a la vez:
// fotos de terceros sin licencia pintadas como el coche de la persona, y una
// fuga de IP/User-Agent de cada visitante hacia el servidor ajeno — el campo
// lo lee el taller vinculado, sus empleados, aquel con quien se comparta el
// vehiculo y, por la vista publica, quien reciba un pase de historial.
//
// Es el mismo argumento que `fotosBajoServicio` en /resenias (FUNC-01).

const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { makeEnv, seed, withRole, UIDS } = require('./helpers');

let env;
beforeAll(async () => { env = await makeEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const NUESTRA =
  'https://firebasestorage.googleapis.com/v0/b/autodoc.appspot.com/o/' +
  'vehiculos%2Fv1%2Ffotos%2Fabc.jpg?alt=media&token=x';
const AJENA = 'https://cdn.imagin.studio/getimage?make=toyota&model=hilux';

const base = (extra = {}) => ({
  id_vehiculo: 'v1',
  id_propietario: UIDS.owner1,
  placa: 'P-v1',
  marca: 'TOYOTA',
  modelo: 'HILUX',
  anio: 2023,
  talleres_vinculados: [],
  shared_with: [],
  ...extra,
});

const sembrarConFoto = (foto) => async (s) => {
  await s.collection('vehiculos').doc('v1').set(base({ foto_url: foto }));
};

describe('vehiculos.foto_url', () => {
  describe('create', () => {
    test('sin foto_url se puede crear', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await assertSucceeds(db.collection('vehiculos').doc('v1').set(base()));
    });

    test('con una URL de NUESTRO Storage se puede crear', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await assertSucceeds(
        db.collection('vehiculos').doc('v1').set(base({ foto_url: NUESTRA })),
      );
    });

    test('con un enlace a un servidor ajeno NO se puede crear', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await assertFails(
        db.collection('vehiculos').doc('v1').set(base({ foto_url: AJENA })),
      );
    });

    // Nuestro bucket pero la carpeta de OTRO vehiculo: sigue sin ser suya, y
    // dejarla pasar convertiria la regla en "cualquier cosa en firebasestorage".
    test('una URL de nuestro Storage pero de otro vehiculo NO vale', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await assertFails(
        db
          .collection('vehiculos')
          .doc('v1')
          .set(base({ foto_url: NUESTRA.replace('v1', 'v9') })),
      );
    });
  });

  describe('update', () => {
    test('no se puede cambiar a un enlace ajeno', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await seed(env, sembrarConFoto(null));
      await assertFails(
        db.collection('vehiculos').doc('v1').update({ foto_url: AJENA }),
      );
    });

    test('si se puede cambiar a una URL de nuestro Storage', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await seed(env, sembrarConFoto(null));
      await assertSucceeds(
        db.collection('vehiculos').doc('v1').update({ foto_url: NUESTRA }),
      );
    });

    // El caso que decide si la regla es correcta o solo severa. Produccion
    // esta llena de vehiculos con el enlace raspado ya guardado; si la regla
    // validara SIEMPRE (y no solo cuando `foto_url` cambia), esos vehiculos
    // quedarian ineditables: ni el kilometraje, ni el color, ni revocarle el
    // acceso a un taller. Seria cambiar una fuga por una averia.
    test('un vehiculo con enlace heredado se sigue pudiendo editar', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await seed(env, sembrarConFoto(AJENA));
      await assertSucceeds(
        db.collection('vehiculos').doc('v1').update({ kilometraje_actual: 51000 }),
      );
    });

    test('y se le puede QUITAR el enlace heredado', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await seed(env, sembrarConFoto(AJENA));
      await assertSucceeds(
        db.collection('vehiculos').doc('v1').update({ foto_url: '' }),
      );
    });

    // La secuencia que demuestra que NO hay tautologia de campo ausente. El
    // guard mira `affectedKeys()`, no `.get(campo, derivado)`, asi que borrar
    // el campo no abre una ventana para reescribirlo libre despues: el
    // segundo update vuelve a tocar `foto_url` y vuelve a validarse.
    // Es el defecto que GAPS-02 encontro en `abierto`, comprobado aqui en vez
    // de supuesto.
    test('borrar foto_url NO abre una ventana para reescribirla ajena', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await seed(env, sembrarConFoto(AJENA));
      await assertSucceeds(
        db
          .collection('vehiculos')
          .doc('v1')
          .update({ foto_url: require('firebase/firestore').deleteField() }),
      );
      await assertFails(
        db.collection('vehiculos').doc('v1').update({ foto_url: AJENA }),
      );
    });

    // El gate de revision encontro que la validacion estaba DENTRO de la rama
    // del propietario, asi que el `|| isAdmin()` del final la esquivaba
    // entera. /resenias ya la tenia fuera; esta es la asimetria cerrada.
    test('un admin TAMPOCO puede plantar un enlace ajeno', async () => {
      const db = await withRole(env, UIDS.admin, 'Administrador');
      await seed(env, sembrarConFoto(null));
      await assertFails(
        db.collection('vehiculos').doc('v1').update({ foto_url: AJENA }),
      );
    });

    // El caso que rompe si la validacion se saca de la disyuncion MAL: un
    // mecanico reportando kilometraje sobre un vehiculo con enlace heredado.
    // `hasOnly(['kilometraje_actual'])` deja `foto_url` fuera de
    // `affectedKeys()`, asi que el guard pasa por su primera clausula.
    test('un mecanico vinculado sigue pudiendo reportar km con foto heredada', async () => {
      const db = await withRole(env, UIDS.taller1, 'Taller');
      await seed(env, async (s) => {
        await s
          .collection('vehiculos')
          .doc('v1')
          .set(base({ foto_url: AJENA, talleres_vinculados: [UIDS.taller1] }));
      });
      await assertSucceeds(
        db.collection('vehiculos').doc('v1').update({ kilometraje_actual: 51000 }),
      );
    });
  });

  // La galeria `vehiculos/{id}/fotos/{fotoId}` guarda `{url, timestamp}`, y
  // esa `url` la elige el cliente igual que `foto_url`. Sus lectores son los
  // MISMOS (puedeVerVehiculo), asi que sin filtro el agujero seguia abierto
  // por la puerta de al lado: bastaba escribir el documento SIN subir nada a
  // Storage. Lo levanto el gate de revision.
  describe('galeria vehiculos/{id}/fotos', () => {
    const FOTO_NUESTRA =
      'https://firebasestorage.googleapis.com/v0/b/autodoc.appspot.com/o/' +
      'vehiculos%2Fv1%2Ffotos%2Fabc.jpg?alt=media&token=x';

    const sembrarVehiculo = async (s) => {
      await s.collection('vehiculos').doc('v1').set(base());
    };

    test('el dueño puede añadir una foto que esta en nuestro Storage', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await seed(env, sembrarVehiculo);
      await assertSucceeds(
        db
          .collection('vehiculos')
          .doc('v1')
          .collection('fotos')
          .doc('f1')
          .set({ url: FOTO_NUESTRA, timestamp: new Date() }),
      );
    });

    test('el dueño NO puede apuntar a un servidor propio sin subir nada', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await seed(env, sembrarVehiculo);
      await assertFails(
        db
          .collection('vehiculos')
          .doc('v1')
          .collection('fotos')
          .doc('f1')
          .set({ url: 'https://servidor-propio/pixel.jpg', timestamp: new Date() }),
      );
    });

    // El delete va en su propio `allow` porque en un borrado
    // `request.resource` es null: agruparlo con create/update denegaria todo
    // borrado. Este test es lo que impide que esa separacion se pierda.
    test('el dueño sigue pudiendo BORRAR una foto', async () => {
      const db = await withRole(env, UIDS.owner1, 'Propietario');
      await seed(env, async (s) => {
        await sembrarVehiculo(s);
        await s
          .collection('vehiculos')
          .doc('v1')
          .collection('fotos')
          .doc('f1')
          .set({ url: FOTO_NUESTRA, timestamp: new Date() });
      });
      await assertSucceeds(
        db.collection('vehiculos').doc('v1').collection('fotos').doc('f1').delete(),
      );
    });
  });
});
