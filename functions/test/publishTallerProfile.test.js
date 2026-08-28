'use strict';

/**
 * Cobertura de la proyeccion `usuarios/{uid}` -> `talleres/{uid}` que hace
 * publishTallerProfile.
 *
 * Bug que motiva este archivo: CAMPOS_PUBLICOS listaba `foto_url`, pero
 * `UserModel.toMap()` (lib/core/models/user_model.dart:131) escribe la foto
 * bajo `foto_perfil_url`. Como la proyeccion copia campo a campo con
 * `if (data[campo] !== undefined)`, la clave nunca casaba y la foto del
 * taller JAMAS llegaba al directorio publico.
 *
 * Se testea `construirPerfilPublico`, extraida como funcion pura del handler
 * del trigger: toda la logica de proyeccion vive ahi y se puede ejercitar sin
 * montar el SDK de Admin (ver la nota de empleados.test.js sobre por que
 * stubbear `admin.firestore` es hostil). El `GeoPoint` se inyecta por el
 * mismo motivo: leer `admin.firestore` dispara `ensureApp()`.
 */

const assert = require('assert');

const { construirPerfilPublico } = require('../src/publishTallerProfile');

/** Doble de `admin.firestore.GeoPoint`, suficiente para aserciones. */
class FakeGeoPoint {
  constructor(latitude, longitude) {
    this.latitude = latitude;
    this.longitude = longitude;
  }
}

const opciones = { GeoPoint: FakeGeoPoint };

/** Doc minimo de `usuarios/{uid}` para un taller, tal y como lo escribe UserModel.toMap(). */
function usuarioTaller(extra) {
  return Object.assign(
    {
      nombre_completo: 'Taller El Buen Motor',
      correo: 'taller@example.com',
      rol: 'Taller',
      estado: 'aprobado',
    },
    extra
  );
}

describe('publishTallerProfile / construirPerfilPublico', () => {
  describe('foto del taller', () => {
    it('proyecta foto_perfil_url, que es la clave que escribe UserModel.toMap()', () => {
      const perfil = construirPerfilPublico(
        'uid-1',
        usuarioTaller({ foto_perfil_url: 'https://cdn/taller.jpg' }),
        opciones
      );

      assert.strictEqual(
        perfil.foto_perfil_url,
        'https://cdn/taller.jpg',
        'la foto escrita por la app debe llegar al directorio publico'
      );
    });

    it('sigue proyectando foto_url para docs heredados', () => {
      const perfil = construirPerfilPublico(
        'uid-1',
        usuarioTaller({ foto_url: 'https://cdn/legacy.jpg' }),
        opciones
      );

      assert.strictEqual(perfil.foto_url, 'https://cdn/legacy.jpg');
    });

    it('no inventa la clave cuando el taller no tiene foto', () => {
      const perfil = construirPerfilPublico('uid-1', usuarioTaller(), opciones);

      assert.ok(!('foto_perfil_url' in perfil));
      assert.ok(!('foto_url' in perfil));
    });
  });

  describe('campos base', () => {
    it('usa nombre_completo cuando no hay nombre publico', () => {
      const perfil = construirPerfilPublico('uid-1', usuarioTaller(), opciones);

      assert.strictEqual(perfil.id_taller, 'uid-1');
      assert.strictEqual(perfil.nombre, 'Taller El Buen Motor');
      assert.strictEqual(perfil.especialidad, 'General');
      assert.strictEqual(perfil.calificacion_promedio, 0);
      assert.strictEqual(perfil.total_resenias, 0);
    });

    it('cae a estado pendiente cuando el doc no lo trae', () => {
      const sinEstado = usuarioTaller();
      delete sinEstado.estado;

      const perfil = construirPerfilPublico('uid-1', sinEstado, opciones);

      assert.strictEqual(perfil.estado, 'pendiente');
    });

    it('no filtra campos privados del doc de usuario', () => {
      const perfil = construirPerfilPublico(
        'uid-1',
        usuarioTaller({ correo: 'privado@example.com', fcm_token: 'tok' }),
        opciones
      );

      assert.ok(!('correo' in perfil), 'el correo no es un campo publico');
      assert.ok(!('fcm_token' in perfil), 'el token FCM no es un campo publico');
    });
  });

  describe('ubicacion', () => {
    it('construye un GeoPoint con lat/lng numericos', () => {
      const perfil = construirPerfilPublico(
        'uid-1',
        usuarioTaller({ latitud: 13.69, longitud: -89.19 }),
        opciones
      );

      assert.ok(perfil.ubicacion instanceof FakeGeoPoint);
      assert.strictEqual(perfil.ubicacion.latitude, 13.69);
      assert.strictEqual(perfil.ubicacion.longitude, -89.19);
    });

    it('omite la ubicacion si falta una de las dos coordenadas', () => {
      const perfil = construirPerfilPublico(
        'uid-1',
        usuarioTaller({ latitud: 13.69 }),
        opciones
      );

      assert.ok(!('ubicacion' in perfil));
    });
  });
});

describe('galeria comercial', () => {
  it('proyecta la galeria al documento publico', () => {
    const perfil = construirPerfilPublico('t1', {
      nombre_completo: 'Taller Z',
      galeria: ['logo.jpg', 'local-1.webp'],
    }, opciones);

    assert.deepStrictEqual(perfil.galeria, ['logo.jpg', 'local-1.webp']);
  });

  it('un taller sin galeria no estrena el campo', () => {
    const perfil = construirPerfilPublico('t1', { nombre_completo: 'Taller Z' }, opciones);
    assert.ok(!('galeria' in perfil));
  });

  it('la galeria viaja como nombres de archivo, nunca como URLs', () => {
    // Es la garantia estructural de la fase 3: lo que cruza al documento de
    // lectura anonima son nombres de un whitelist, y la ruta se reconstruye en
    // el cliente a partir del uid. Si algun dia esto empezara a llevar URLs,
    // volveria a existir el vector de cosecha de IP de cada visitante.
    const perfil = construirPerfilPublico('t1', {
      nombre_completo: 'Taller Z',
      galeria: ['logo.jpg'],
    }, opciones);

    for (const entrada of perfil.galeria) {
      assert.ok(!String(entrada).includes('://'), `«${entrada}» parece una URL`);
    }
  });
});
