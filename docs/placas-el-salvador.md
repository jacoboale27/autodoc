# Placas vehiculares de El Salvador

Investigación hecha el 2026-08-31 para corregir el validador de placas de
AutoDoc, que solo aceptaba la forma `P###-###` y rechazaba placas legítimas de
cinco caracteres.

## Cómo funciona el sistema

El Viceministerio de Transporte (VMT) asigna a cada vehículo una placa formada
por **una o más letras iniciales que identifican el tipo de vehículo**, seguidas
de un **número correlativo**. La numeración de cada clase de placa es
correlativa y los rangos los establece el Ministerio.

### Prefijos por tipo de vehículo

Existen unos 19 tipos de placa. Los que aparecen en el buscador público del
registro de vehículos son:

`P`, `A`, `AB`, `C`, `M`, `MB`, `N`, `O`, `R`, `RE`, `MI`, `CD`, `CC`, `PR`,
`CR`, `SP`, `D`

De los confirmados: **`P` = particular**, `A` = alquiler, `AB` = autobús,
`C` = camión/carga, `M` = motocicleta, `CD` = cuerpo diplomático,
`CC` = cuerpo consular.

> **AutoDoc cubre hoy cuatro tipos:** `P` particular, `M` moto, `C` carga y
> `A` alquiler. Se eligen con un selector en el formulario de registro.

### El correlativo: esquema de 2011 (numérico)

Desde 2011 la estructura de la placa reservó **seis espacios**, con numeración
puramente decimal, lo que daba cabida a **999,999** vehículos por tipo.

Lo importante para el validador: **el correlativo no se rellena con ceros a la
izquierda**. El buscador oficial del registro de vehículos lo dice de forma
explícita:

> "Digite el numero de placa sin guiones (Ejemplo: P123456). Debe incluir el
> tipo de placa de su vehículo (Ejemplo: P). **No colocar ceros a la
> izquierda.**"

Por eso circulan placas de **cinco caracteres** (`P 12 345`, correlativo
12,345), de cuatro (`P 1 234`), etc., además de las de seis. El agrupamiento
visual separa siempre **los tres últimos** caracteres, así que lo que varía es
el tamaño del primer grupo.

### El correlativo: esquema alfanumérico de 2021 (hexadecimal)

En agosto de 2021 el parque de vehículos **particulares** superó el millón, y el
sistema decimal de seis cifras se agotó. El VMT empezó entonces a entregar
placas alfanuméricas **solo a vehículos de primera matrícula**, añadiendo las
letras **`A`–`F`** (numeración hexadecimal) al correlativo. Con eso el esquema
da para más de **4 millones** de placas por tipo. La primera placa emitida fue
**`P 001 00A`** — nótese que ahí el primer grupo **sí** va rellenado a tres
posiciones.

La cobertura de prensa describe las letras como limitadas a los tres últimos
espacios ("los primeros tres números van del 01 al 999, los tres últimos del
00A al FFF"). **En la práctica no es así:** hay placas en circulación con letra
también en el correlativo, así que AutoDoc acepta hexadecimal en las seis
posiciones.

Los vehículos con placa del esquema numérico anterior **no cambian de placa**;
el esquema nuevo aplica únicamente a primeras matrículas. Es decir, ambos
esquemas conviven en la calle.

## Regla que implementa AutoDoc

`lib/core/utils/plate_formatter.dart`:

```
^[PMCA][0-9A-F]{1,3}-[0-9A-F]{3}$
```

- Letra del tipo de vehículo: `P`, `M`, `C` o `A`. En el registro la elige el
  usuario con un selector; el formateador la antepone sola.
- Correlativo de **4 a 6 caracteres hexadecimales**, sin obligar a rellenar
  con ceros.
- El guion "flota" desde la derecha: siempre separa los tres últimos
  caracteres. Al teclear se ve `P1` → `P12` → `P123` → `P1-234` → `P12-345`
  → `P123-456`.

Decisiones que conviene no perder de vista:

- **`A` y `C` son a la vez prefijo y dígito hexadecimal.** Por eso el prefijo
  se recorta *una sola vez* por posición, nunca filtrando caracteres: si no,
  una placa de alquiler `AA12-345` (correlativo `A12345`) perdería una `A`.
  Por lo mismo existe `componerPlaca(tipo, correlativo)`, que recibe el
  correlativo ya sin prefijo y no intenta adivinarlo — es lo que usa el
  selector de tipo al recomponer la placa.
- **En la búsqueda del mecánico y en el escaneo QR nadie elige tipo.**
  `normalizarPlaca` toma el tipo de la primera letra del texto y asume
  particular si no reconoce ninguna. Con `A` y `C` la lectura es ambigua y se
  resuelve **a favor del prefijo**, porque quien busca teclea la placa tal
  como está estampada, con su letra delante.
- **Los prefijos de dos letras quedan fuera de alcance y son ambiguos.** Una
  placa de autobús `AB12-345` es indistinguible de una de alquiler con
  correlativo `B12345`, así que el validador la acepta. Se prefiere colar una
  placa rara antes que rechazar una legítima.
- **Los ceros a la izquierda se respetan tal cual, ni se rellenan ni se
  recortan.** `P001-00A` y `P1-00A` se guardan como placas distintas, porque
  en el esquema alfanumérico el cero forma parte de lo estampado. La app
  guarda exactamente lo que el dueño lee en su vehículo, y la búsqueda del
  mecánico normaliza igual por ambos lados, así que la comparación exacta en
  Firestore sigue funcionando.
- **El tipo no se guarda como campo aparte.** Es la primera letra de `placa`,
  que ya se persiste completa. Así no hay dos datos que puedan divergir ni
  migración de esquema.

`functions/migrate_vehiculos.js` replica `normalizarPlaca` en JavaScript. Si se
toca una, hay que tocar la otra.

## Datos heredados: reporte de ceros iniciales

El script de migración **no puede** distinguir un `P012-345` legítimo (esquema
alfanumérico) de uno que alguien rellenó a mano para esquivar el validador
viejo, que exigía seis caracteres. Reescribirlos a ciegas corrompería los
legítimos, así que el script **solo los reporta**:

```
Placas cuyo correlativo empieza por 0 (N) — revisar a mano:
  [cero] <idVehiculo>  placa=P012-345  propietario=<uid>
```

La corrección de los que resulten ser apaños se hace a mano.

## Pendientes / decisiones de producto

1. **Quedan tipos sin cubrir.** De los ~19 que existen, AutoDoc registra
   cuatro. Faltan autobús (`AB`), diplomático (`CD`), consular (`CC`) y el
   resto; los de dos letras además chocan con la ambigüedad descrita arriba.
2. **No está confirmado que los cuatro tipos compartan la misma forma de
   correlativo.** Se aplica la misma regla permisiva a todos, a falta de
   fuentes sobre motos, carga y alquiler. La única referencia histórica
   encontrada para motos es el formato de 1976 `M-1-234`.
3. **Correlativos de 3 caracteres o menos** (`P123`, `P42`) no se aceptan: el
   patrón exige al menos 4 caracteres tras la letra. No se encontró evidencia
   de cómo se imprimen esos correlativos tan bajos.

## Fuentes

- [Así son las placas alfanuméricas que ha comenzado a entregar el VMT — El Salvador.com](https://historico.elsalvador.com/historico/871878/placas-alfanumericas-comienza-entregar-vmt.html)
- [Placas alfanuméricas permitirán matricular hasta cuatro millones de vehículos — Diario El Mundo](https://diario.elmundo.sv/nacionales/placas-alfanumericas-permitiran-matricular-hasta-cuatro-millones-de-vehiculos)
- [Gobierno implementa sistema de placas alfanuméricas para vehículos de primera matrícula — Presidencia de la República](https://www.presidencia.gob.sv/gobierno-del-presidente-nayib-bukele-implementa-sistema-de-placas-alfanumericas-para-vehiculos-de-primera-matricula/)
- [Gobierno recuerda que la entrega de placas alfanuméricas es solo para vehículos de primera matrícula — Presidencia de la República](https://www.presidencia.gob.sv/gobierno-recuerda-que-la-entrega-de-placas-alfanumericas-es-solo-para-los-vehiculos-de-primera-matricula-no-hay-un-cambio-generalizado/)
- [VMT comienza a entregar placas alfanuméricas — La Prensa Gráfica](https://www.laprensagrafica.com/elsalvador/VMT-comienza-a-entregar-placas-alfanumericas--20210823-0053.html)
- [Placas — Consulta y trámite de vehículos en El Salvador (formato de consulta y lista de tipos de placa)](https://registrovehiculos.com/el-salvador/placas.htm)
- [En El Salvador existen 19 tipos de placas — La Prensa Gráfica](https://www.tiktok.com/@laprensagrafica/video/7372662132296453381?lang=es)
