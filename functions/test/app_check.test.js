'use strict';

/**
 * SEC-04 — enforcement de App Check en las Cloud Functions.
 *
 * El cliente ya firma: `lib/main.dart:183` activa App Check con reCAPTCHA
 * Enterprise en web, Play Integrity en Android y DeviceCheck en iOS. **Nadie
 * comprobaba la firma.** Habia cliente firmando y ningun servidor verificando,
 * que es exactamente el estado en el que App Check no protege de nada.
 *
 * Y no era un descuido menor: este repo usa Cloud Functions **v1**, donde el
 * enforcement de App Check **no tiene interruptor de consola**. Para Firestore
 * y Storage basta con activarlo en la consola de Firebase; para las Functions
 * v1 hay que mirar `context.app` en el codigo, funcion por funcion. El propio
 * runbook ya lo decia (`docs/RUNBOOK.md`), y lo dejaba como deuda: activar App
 * Check en la consola daba una falsa sensacion de cobertura, porque los 12
 * callables seguian aceptando cualquier llamada.
 *
 * **Por que el modo por defecto es `monitor` y no `enforce`.** Un cliente sin
 * token no es solo un atacante: es tambien un build web al que le falto
 * RECAPTCHA_SITE_KEY, un movil con Play Integrity caido, o una version vieja
 * en cache. Encender el rechazo de golpe expulsa a usuarios legitimos y el
 * sintoma —llamadas que fallan sin patron— es dificil de atribuir. El runbook
 * exige dos fases (monitorizacion, y enforcement solo si el porcentaje de
 * tokens validos supera el 98 %), asi que el codigo tiene que poder estar en
 * la primera. `APP_CHECK_ENFORCEMENT=enforce` es lo que cierra la puerta, y es
 * un paso de runbook, no un valor por defecto.
 */

const assert = require('assert');

const {
  MODO_POR_DEFECTO,
  modoDeEnforcement,
  exigirAppCheck,
} = require('../src/appCheck');

const conApp = { app: { appId: '1:123:web:abc' }, auth: { uid: 'u1' } };
const sinApp = { auth: { uid: 'u1' } };

describe('appCheck / modoDeEnforcement', () => {
  it('sin configurar, monitoriza en vez de rechazar', () => {
    assert.strictEqual(modoDeEnforcement({}), 'monitor');
    assert.strictEqual(MODO_POR_DEFECTO, 'monitor');
  });

  it('lee el modo de la variable de entorno', () => {
    assert.strictEqual(modoDeEnforcement({ APP_CHECK_ENFORCEMENT: 'enforce' }), 'enforce');
    assert.strictEqual(modoDeEnforcement({ APP_CHECK_ENFORCEMENT: 'off' }), 'off');
  });

  it('un valor desconocido cae a monitor, no a off ni a enforce', () => {
    // Caer a `off` seria inseguro en silencio; caer a `enforce` por una errata
    // de configuracion dejaria la app entera fuera. Monitor es el unico valor
    // que ni abre la puerta ni tira a nadie.
    assert.strictEqual(modoDeEnforcement({ APP_CHECK_ENFORCEMENT: 'Enforce ' }), 'enforce');
    assert.strictEqual(modoDeEnforcement({ APP_CHECK_ENFORCEMENT: 'sí' }), 'monitor');
    assert.strictEqual(modoDeEnforcement({ APP_CHECK_ENFORCEMENT: '' }), 'monitor');
  });
});

describe('appCheck / exigirAppCheck', () => {
  it('en enforce, una llamada sin token de App Check se rechaza', () => {
    assert.throws(
      () => exigirAppCheck(sinApp, 'buscarVehiculoPorPlaca', { modo: 'enforce' }),
      (e) => {
        assert.strictEqual(e.code, 'failed-precondition');
        return true;
      }
    );
  });

  it('en enforce, una llamada con token pasa', () => {
    assert.doesNotThrow(() =>
      exigirAppCheck(conApp, 'buscarVehiculoPorPlaca', { modo: 'enforce' })
    );
  });

  it('en monitor NO rechaza, pero deja constancia', () => {
    const avisos = [];
    assert.doesNotThrow(() =>
      exigirAppCheck(sinApp, 'buscarVehiculoPorPlaca', {
        modo: 'monitor',
        registrar: (m) => avisos.push(m),
      })
    );
    assert.strictEqual(avisos.length, 1);
    assert.ok(avisos[0].includes('buscarVehiculoPorPlaca'));
  });

  it('en monitor, una llamada CON token no genera ruido', () => {
    const avisos = [];
    exigirAppCheck(conApp, 'buscarVehiculoPorPlaca', {
      modo: 'monitor',
      registrar: (m) => avisos.push(m),
    });
    assert.deepStrictEqual(avisos, []);
  });

  it('en off no rechaza ni registra', () => {
    const avisos = [];
    assert.doesNotThrow(() =>
      exigirAppCheck(sinApp, 'x', { modo: 'off', registrar: (m) => avisos.push(m) })
    );
    assert.deepStrictEqual(avisos, []);
  });

  it('el mensaje de rechazo no dice al cliente como saltarselo', () => {
    // Un mensaje que explique que falta el token de App Check, o que nombre la
    // variable de configuracion, le esta diciendo al atacante exactamente
    // contra que esta chocando.
    try {
      exigirAppCheck(sinApp, 'superUserCreateAccount', { modo: 'enforce' });
      assert.fail('deberia haber rechazado');
    } catch (e) {
      const texto = `${e.message} ${e.details || ''}`.toLowerCase();
      assert.ok(!texto.includes('app_check_enforcement'), 'filtra el nombre de la variable');
      assert.ok(!texto.includes('recaptcha'), 'filtra el proveedor');
      assert.ok(!texto.includes('context.app'), 'filtra el mecanismo');
    }
  });

  it('un contexto sin `app` y uno con `app` nulo se tratan igual', () => {
    assert.throws(() => exigirAppCheck({ app: null }, 'x', { modo: 'enforce' }));
    assert.throws(() => exigirAppCheck({}, 'x', { modo: 'enforce' }));
  });
});
