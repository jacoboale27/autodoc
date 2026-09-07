'use strict';

/**
 * ROLE-01 — logica pura del script de migracion de `usuarios.rol` a
 * vocabulario canonico. Separada de `migrate_rol_usuario.js` (que hace el
 * I/O contra Firestore) para poder probarla sin admin SDK ni emulador,
 * igual que `migracion.test.js` prueba `esMigracion()` en aislamiento.
 *
 * El vocabulario canonico es exactamente el que exige `firestore.rules` y
 * `lib/core/utils/role_utils.dart` (appRoleOf, tras ROLE-01): 'Propietario',
 * 'Mecanico', 'Taller', 'Administrador', 'Superusuario'. Cualquier otra
 * variante (caja, acentos, sinonimos historicos como 'Usuario') es candidata
 * a migracion; un valor que no se reconoce por ningun sinonimo se reporta
 * para revision manual, nunca se adivina.
 */

const assert = require('assert');
const {
  ROLES_CANONICOS,
  normalizar,
  rolCanonicoSugerido,
  resumenMigracion,
} = require('../src/rolMigracion');

describe('rolMigracion / normalizar', () => {
  it('minusculas, sin espacios y sin acentos', () => {
    assert.strictEqual(normalizar('  Mecánico  '), 'mecanico');
    assert.strictEqual(normalizar('ADMINISTRADOR'), 'administrador');
  });

  it('null o undefined se normalizan a cadena vacia', () => {
    assert.strictEqual(normalizar(null), '');
    assert.strictEqual(normalizar(undefined), '');
  });
});

describe('rolMigracion / rolCanonicoSugerido', () => {
  it('un rol ya canonico no sugiere cambio (null)', () => {
    for (const rol of ROLES_CANONICOS) {
      assert.strictEqual(rolCanonicoSugerido(rol), null, rol);
    }
  });

  it('variantes de caja/acento de Mecanico migran a "Mecanico"', () => {
    for (const rol of ['mecanico', 'MECANICO', 'Mecánico', 'mecánico', ' Mecanico ']) {
      assert.strictEqual(rolCanonicoSugerido(rol), 'Mecanico', rol);
    }
  });

  it('variantes de caja de Taller migran a "Taller"', () => {
    for (const rol of ['taller', 'TALLER', ' Taller']) {
      assert.strictEqual(rolCanonicoSugerido(rol), 'Taller', rol);
    }
  });

  it('variantes de caja/acento de Administrador migran a "Administrador"', () => {
    for (const rol of ['administrador', 'ADMINISTRADOR', 'Administrador ']) {
      assert.strictEqual(rolCanonicoSugerido(rol), 'Administrador', rol);
    }
  });

  it('"admin" (alias que firestore.rules SI tolera) tambien migra a "Administrador"', () => {
    // 'admin' no rompe nada hoy (isAdmin() lo acepta), pero el plan de
    // remediacion fija un vocabulario UNICO de 5 valores y 'admin' no es
    // uno de ellos: se consolida iguen que cualquier otra variante.
    assert.strictEqual(rolCanonicoSugerido('admin'), 'Administrador');
    assert.strictEqual(rolCanonicoSugerido('ADMIN'), 'Administrador');
  });

  it('variantes de caja/acento de Superusuario migran a "Superusuario"', () => {
    for (const rol of ['superusuario', 'SUPERUSUARIO', 'Súperusuario']) {
      assert.strictEqual(rolCanonicoSugerido(rol), 'Superusuario', rol);
    }
  });

  it('sinonimos historicos de Propietario migran a "Propietario"', () => {
    for (const rol of ['usuario', 'Usuario', 'USUARIO', 'propietario', 'PROPIETARIO']) {
      assert.strictEqual(rolCanonicoSugerido(rol), 'Propietario', rol);
    }
  });

  it('un rol vacio, nulo o desconocido no sugiere nada (revision manual)', () => {
    for (const rol of [null, undefined, '', '   ', 'inventado', 'cliente']) {
      assert.strictEqual(rolCanonicoSugerido(rol), null, String(rol));
    }
  });
});

describe('rolMigracion / resumenMigracion', () => {
  it('cuenta canonicos, migrables (agrupados por variante -> destino) y desconocidos', () => {
    const docs = [
      { id: 'a', rol: 'Propietario' }, // ya canonico
      { id: 'b', rol: 'mecanico' }, // migrable -> Mecanico
      { id: 'c', rol: 'MECANICO' }, // migrable -> Mecanico
      { id: 'd', rol: 'Taller' }, // ya canonico
      { id: 'e', rol: 'admin' }, // migrable -> Administrador
      { id: 'f', rol: 'rol-random' }, // desconocido
      { id: 'g', rol: null }, // desconocido
    ];

    const resumen = resumenMigracion(docs);

    assert.strictEqual(resumen.totalDocumentos, 7);
    assert.strictEqual(resumen.yaCanonicos.length, 2);
    assert.deepStrictEqual(
      resumen.yaCanonicos.map((d) => d.id).sort(),
      ['a', 'd'],
    );

    assert.strictEqual(resumen.migrables.length, 3);
    const porId = Object.fromEntries(resumen.migrables.map((m) => [m.id, m]));
    assert.strictEqual(porId.b.rolActual, 'mecanico');
    assert.strictEqual(porId.b.rolCanonico, 'Mecanico');
    assert.strictEqual(porId.c.rolCanonico, 'Mecanico');
    assert.strictEqual(porId.e.rolCanonico, 'Administrador');

    assert.strictEqual(resumen.desconocidos.length, 2);
    assert.deepStrictEqual(
      resumen.desconocidos.map((d) => d.id).sort(),
      ['f', 'g'],
    );

    // Conteo por variante -> destino, para el reporte legible del dry-run.
    assert.strictEqual(resumen.conteoPorVariante['mecanico -> Mecanico'], 2);
    assert.strictEqual(resumen.conteoPorVariante['admin -> Administrador'], 1);
  });

  it('una coleccion vacia no revienta', () => {
    const resumen = resumenMigracion([]);
    assert.strictEqual(resumen.totalDocumentos, 0);
    assert.strictEqual(resumen.yaCanonicos.length, 0);
    assert.strictEqual(resumen.migrables.length, 0);
    assert.strictEqual(resumen.desconocidos.length, 0);
  });
});
