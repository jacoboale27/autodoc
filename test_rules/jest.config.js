// El timeout por defecto de Jest son 5000 ms, y ese presupuesto lo consume el
// `beforeAll` de cada archivo: `makeEnv()` levanta el entorno de
// rules-unit-testing, lee firestore.rules y storage.rules del disco y los
// carga en los emuladores. En frio eso pasa de 5 s con facilidad, y cuando
// pasa no falla un test — falla el hook, asi que `env` se queda `undefined` y
// el archivo entero cae con 'Cannot read properties of undefined (reading
// cleanup)', un mensaje que no apunta a la causa por ningun lado.
//
// Es la misma enfermedad que QA-02 diagnostico en Mocha (el require sincrono
// del entrypoint venciendo el timeout de 2000 ms en frio) y se cierra igual:
// dando margen, no reduciendo trabajo. Aqui vive en la config compartida a
// proposito, para que un archivo de test nuevo no herede la intermitencia por
// olvidarse de declarar su propio timeout.
module.exports = {
  testEnvironment: 'node',
  testTimeout: 30000,
};
