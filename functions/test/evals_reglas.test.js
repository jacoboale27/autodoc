'use strict';

/**
 * Las reglas duras de los evals **detectan de verdad**.
 *
 * Los evals no son un gate: corren a mano contra el modelo real y su salida
 * es evidencia. Pero sus comprobaciones automaticas si tienen que estar
 * probadas, porque su modo de fallo es el peor de todos — decir «sin
 * violaciones de las reglas duras» cuando lo que pasa es que la expresion
 * regular no casa nunca. Eso convierte una corrida cara en un sello de
 * aprobacion vacio, que es peor que no tener evals.
 *
 * Cada caso alimenta prosa DELIBERADAMENTE mala y afirma que salta la regla
 * que le toca, y prosa buena afirmando que no salta ninguna.
 */

const assert = require('assert');

const {
  revisarRedaccion,
  numerosDe,
  numerosDelEnvelope,
  reglaMantenimientoEnDias,
  REDACCION,
} = require('../evals_asistente');

const CASO = {
  nombre: 'de prueba',
  envelope: {
    rol: 'propietario',
    ventana_dias: 30,
    items: [
      { tipo: 'soat', placa: 'ABC123', dias_restantes: -10 },
      { tipo: 'mantenimiento', placa: 'ABC123', nombre: 'Frenos', km_restantes: 200 },
    ],
  },
  vencidos: [10],
};

const BUENA =
  'Tu SOAT del ABC123 esta vencido hace 10 dias. Al mantenimiento de frenos ' +
  'le faltan 200 kilometros.';

describe('evals / las reglas duras detectan', () => {
  it('la prosa correcta no dispara ninguna regla', () => {
    // Sin esto, unas reglas que saltaran SIEMPRE tambien pasarian los casos
    // negativos de abajo, y no se podria distinguir una de otra.
    assert.deepStrictEqual(revisarRedaccion(CASO, BUENA), []);
  });

  it('caza una fecha de calendario', () => {
    // El envelope no lleva ninguna fecha, asi que cualquiera que aparezca se
    // la invento el modelo — y una fecha de vencimiento inventada es de los
    // peores datos que este producto puede dar.
    const conFecha = BUENA + ' Vence el 12 de octubre.';
    const fallos = revisarRedaccion(CASO, conFecha);
    assert.ok(
      fallos.some((f) => /FECHA INVENTADA/.test(f)),
      'no detecto la fecha: ' + JSON.stringify(fallos)
    );
  });

  it('caza las otras dos formas de escribir una fecha', () => {
    ['El 2026-10-12 vence.', 'Vence el 12/10/2026.'].forEach((texto) => {
      const fallos = revisarRedaccion(CASO, BUENA + ' ' + texto);
      assert.ok(
        fallos.some((f) => /FECHA INVENTADA/.test(f)),
        'no detecto "' + texto + '"'
      );
    });
  });

  it('caza el mantenimiento expresado en dias', () => {
    // La regla dura del §1.3: el mantenimiento viaja en kilometros. Decirlo
    // en dias es inventar una prediccion de uso que nadie calculo.
    const enDias = 'Tu SOAT esta vencido hace 10 dias. El mantenimiento de frenos vence en 15 dias.';
    const fallos = revisarRedaccion(CASO, enDias);
    assert.ok(
      fallos.some((f) => /MANTENIMIENTO EN DIAS/.test(f)),
      'no detecto los dias: ' + JSON.stringify(fallos)
    );
  });

  it('caza un numero que no esta en el envelope', () => {
    const inventado = BUENA + ' Ademas te quedan 7 revisiones.';
    const fallos = revisarRedaccion(CASO, inventado);
    assert.ok(
      fallos.some((f) => /NUMEROS QUE NO ESTAN/.test(f) && /7/.test(f)),
      'no detecto el 7: ' + JSON.stringify(fallos)
    );
  });

  it('caza que lo vencido se cuente como si quedara tiempo', () => {
    // `dias_restantes: -10` es «vencido hace 10», nunca «te quedan 10». Es el
    // error mas facil de cometer y el mas caro: deja a alguien conduciendo
    // sin SOAT creyendo que va sobrado.
    const alReves = 'A tu SOAT del ABC123 le quedan 10 dias. Frenos: 200 kilometros.';
    const fallos = revisarRedaccion(CASO, alReves);
    assert.ok(
      fallos.some((f) => /NO DICE QUE ESTA VENCIDO/.test(f)),
      'no detecto la inversion: ' + JSON.stringify(fallos)
    );
  });

  it('una cita expresada en dias NO es un mantenimiento en dias', () => {
    // Regresion de la primera corrida contra el modelo real (2026-09-20). La
    // prosa de abajo es la que devolvio Gemini, y es CORRECTA: la cita va en
    // dias porque una cita es una fecha, y el mantenimiento va en kilometros.
    // La regla saltaba igual, porque su lista fija de palabras llevaba
    // «aceite» y la cita era de Aceite.
    //
    // Una regla dura con falsos positivos se desactiva sola: la siguiente
    // corrida se lee por encima y la violacion de verdad pasa de largo.
    const caso = REDACCION[0];
    const real =
      'Tu SOAT con placa ABC123 está vencido hace 10 días y la tarjeta vence ' +
      'en 3 días. Tienes una cita para servicio de Aceite programada en 2 ' +
      'días a las 14:00. El mantenimiento de frenos está próximo a 200 ' +
      'kilómetros.';

    assert.deepStrictEqual(revisarRedaccion(caso, real), []);
  });

  it('la regla se arma con los nombres del envelope, no con una lista fija', () => {
    // Lo que hace que el caso de arriba pase no es una excepcion escrita a
    // mano para esa frase: es que «aceite» no es un mantenimiento de ESTE
    // envelope. Si lo fuera, la regla tiene que volver a mirarlo.
    const soloFrenos = reglaMantenimientoEnDias(REDACCION[0].envelope);
    assert.ok(!soloFrenos.test('cita de Aceite en 2 dias'), 'sigue mirando una palabra ajena');
    assert.ok(soloFrenos.test('frenos en 15 dias'), 'dejo de mirar su propio mantenimiento');

    const conAceite = reglaMantenimientoEnDias({
      items: [{ tipo: 'mantenimiento', nombre: 'Aceite', km_restantes: 500 }],
    });
    assert.ok(conAceite.test('el aceite vence en 15 dias'), 'no armo la regla con Aceite');
  });

  it('sin mantenimiento en el envelope no hay regla que aplicar', () => {
    assert.strictEqual(
      reglaMantenimientoEnDias({ items: [{ tipo: 'soat', dias_restantes: 3 }] }),
      null
    );
  });

  it('caza un nombre de documento inventado', () => {
    // Prosa REAL de la corrida del 2026-09-21. El envelope dice `tipo:
    // 'tarjeta'` a secas y el modelo lo alargo a «tarjeta de operacion», que
    // es el documento de los vehiculos de SERVICIO PUBLICO — un particular no
    // tiene uno. La app llama a ese campo «Tarjeta de Circulacion».
    //
    // Ninguna regla anterior podia verlo: no es un numero, ni una fecha, ni
    // dias en vez de kilometros. Es un dato legal equivocado dentro de prosa
    // impecable, y solo salio leyendo a mano.
    const real =
      'Tienes el SOAT del vehiculo ABC123 vencido hace 10 dias y la tarjeta ' +
      'de operacion vence en 3 dias. El mantenimiento de frenos esta proximo ' +
      'al faltar 200 kilometros.';
    const fallos = revisarRedaccion(CASO, real);
    assert.ok(
      fallos.some((f) => /NOMBRE DE DOCUMENTO INVENTADO/.test(f)),
      'no detecto el documento: ' + JSON.stringify(fallos)
    );
  });

  it('«tarjeta» a secas NO dispara la regla del documento', () => {
    // Sin esto, la regla saltaria en toda respuesta que mencione la tarjeta y
    // se volveria ruido. Lo que esta prohibido es ALARGARLA, no nombrarla.
    const bien = BUENA + ' La tarjeta de circulacion vence en 3 dias.';
    const fallos = revisarRedaccion(CASO, bien);
    assert.ok(
      !fallos.some((f) => /NOMBRE DE DOCUMENTO INVENTADO/.test(f)),
      'salto sobre el nombre correcto: ' + JSON.stringify(fallos)
    );
  });

  it('caza la regla del prompt filtrada a la prosa', () => {
    // La otra cosa que destapo la corrida: el modelo explico su propia
    // instruccion en CUATRO de los seis envelopes, incluido uno sin ningun
    // mantenimiento. Es la regla del sistema saliendo hacia la persona como si
    // fuera un dato suyo.
    const sinKm = {
      nombre: 'solo soat',
      envelope: {
        rol: 'propietario',
        ventana_dias: 30,
        items: [{ tipo: 'soat', placa: 'ABC123', dias_restantes: 7 }],
      },
    };
    const real =
      'Te quedan 7 dias para renovar el SOAT de tu vehiculo. Recuerda que el ' +
      'mantenimiento preventivo siempre debe medirse en kilometros.';
    const fallos = revisarRedaccion(sinKm, real);
    assert.ok(
      fallos.some((f) => /REGLA DEL PROMPT FILTRADA/.test(f)),
      'no detecto la regla filtrada: ' + JSON.stringify(fallos)
    );
  });

  it('decir que el kilometraje no cuadra NO es filtrar la regla', () => {
    // El falso positivo que tuvo la primera version de esta regla, que miraba
    // «se mencionan kilometros y el envelope no trae ninguno». En el envelope
    // del kilometraje inconsistente, decirlo es EXACTAMENTE lo que el prompt
    // manda — y la frase real de la corrida lo dice bien.
    const inconsistente = {
      nombre: 'inconsistente',
      envelope: {
        rol: 'propietario',
        ventana_dias: 30,
        items: [{ tipo: 'mantenimiento', placa: 'XYZ789', nombre: 'Aceite', inconsistente: true }],
      },
    };
    const bien =
      'El mantenimiento de Aceite para tu vehiculo XYZ789 presenta un ' +
      'kilometraje registrado que no cuadra, por lo que conviene actualizarlo.';
    const fallos = revisarRedaccion(inconsistente, bien);
    assert.deepStrictEqual(
      fallos,
      [],
      'salto sobre la frase que el prompt pide literalmente: ' + JSON.stringify(fallos)
    );
  });

  it('con mantenimiento en el envelope, hablar de kilometros es lo CORRECTO', () => {
    // La red que hace util a la regla de arriba. `BUENA` dice «200
    // kilometros» y debe seguir sin disparar nada: una regla que grita sobre
    // prosa buena se desactiva sola, que es la leccion que pago el falso
    // positivo de la primera corrida.
    const fallos = revisarRedaccion(CASO, BUENA);
    assert.ok(
      !fallos.some((f) => /REGLA DEL PROMPT FILTRADA/.test(f)),
      'salto sobre kilometros legitimos: ' + JSON.stringify(fallos)
    );
  });

  it('un numero escrito CON LETRAS tambien cuenta', () => {
    // El agujero que salio leyendo la segunda corrida. `numerosDe` solo miraba
    // digitos, asi que «te quedan diez dias» sobre un envelope que dice 3 se
    // saltaba entera la comprobacion de numeros inventados — la que mas vale,
    // porque un numero que no esta en el JSON es un dato inventado sobre el
    // coche de alguien.
    const conLetras = BUENA + ' Ademas te quedan siete revisiones.';
    const fallos = revisarRedaccion(CASO, conLetras);
    assert.ok(
      fallos.some((f) => /NUMEROS QUE NO ESTAN/.test(f) && /7/.test(f)),
      'no detecto el «siete»: ' + JSON.stringify(fallos)
    );
  });

  it('en los dos idiomas', () => {
    assert.deepStrictEqual(numerosDe('Expires in thirty days'), [30]);
    assert.deepStrictEqual(numerosDe('faltan doscientos kilometros'), [200]);
  });

  it('las tildes no esconden un numeral', () => {
    // La normalizacion se aplica antes de buscar, asi que «dieciséis» cuenta
    // igual que «dieciseis». Sin eso, la regla se saltaria con un acento.
    assert.deepStrictEqual(numerosDe('quedan dieciséis días'), [16]);
  });

  it('«un» y «una» NO cuentan como el numero 1', () => {
    // Deliberado: en los dos idiomas son articulos antes que numerales, y
    // mapearlos marcaria «un vehiculo» como el 1 en toda respuesta. Se pierde
    // «vence en un dia» a cambio de que la regla no sea ruido — que es como
    // una comprobacion se desactiva sin desactivarse.
    assert.deepStrictEqual(numerosDe('Tienes un compromiso con una placa'), []);
    assert.deepStrictEqual(numerosDe('You have a commitment and one plate'), []);
  });

  it('las horas y las placas NO cuentan como numeros inventados', () => {
    // Si contaran, toda redaccion con una cita saltaria y las reglas se
    // volverian ruido que nadie mira — que es como una comprobacion se
    // desactiva de hecho sin desactivarse de derecho.
    assert.deepStrictEqual(numerosDe('Cita a las 14:00 del ABC123'), []);
  });

  it('el envelope autoriza sus propios numeros, con el vencido en positivo', () => {
    const permitidos = numerosDelEnvelope(CASO.envelope);
    [30, 2, -10, 10, 200].forEach((n) =>
      assert.ok(permitidos.has(n), 'el envelope deberia autorizar ' + n)
    );
    assert.ok(!permitidos.has(7), 'autorizo un numero que no esta en el envelope');
  });
});
