"use client";

import { useReducedMotion, type MotionProps } from "framer-motion";

/// UX-03: `prefers-reduced-motion` en la landing.
///
/// La landing tenia 29 elementos animados con framer-motion y ninguna guarda:
/// ni `useReducedMotion`, ni `MotionConfig`, ni una `@media` en `globals.css`.
/// Lo peor no era la entrada de la cabecera sino los dos mockups del hero, que
/// flotan con `repeat: Infinity`: movimiento continuo e indefinido es
/// exactamente el disparador de nauseas que la preferencia existe para evitar.
///
/// Hacen falta las DOS capas que hay aqui, y no son intercambiables:
///
///   - `<MotionConfig reducedMotion="user">` en el layout cubre lo que se nos
///     escape (un `whileHover` nuevo, por ejemplo), pero **solo desactiva
///     transform y layout: la opacidad la sigue animando a proposito**, porque
///     un fundido no marea. Eso deja vivo el problema de verdad de esta
///     landing: las secciones de abajo arrancan en `opacity: 0` y solo se
///     revelan con `whileInView`. Quien pide movimiento reducido se queda
///     mirando huecos en blanco hasta que hace scroll.
///   - Por eso [aparicion] neutraliza la animacion de entrada ENTERA cuando la
///     preferencia esta activa, dejando el elemento ya en su estado final.
export function useMovimientoReducido(): boolean {
  return useReducedMotion() === true;
}

/// El estado de reposo: visible, sin desplazar y a tamano natural.
///
/// Se enumera explicitamente porque hay que ESCRIBIRLO, no solo dejar de
/// animar. Se cubren las cuatro propiedades que anima esta landing.
const REPOSO = { opacity: 1, x: 0, y: 0, scale: 1 } as const;

/// Props de animacion que se neutralizan si se pidio movimiento reducido.
///
/// **Quitar las props de animacion no basta, y creerlo deja la landing peor
/// que antes.** La landing es un export estatico: framer-motion escribe el
/// valor de `initial` como estilo inline dentro del HTML generado, para que no
/// haya parpadeo. En el servidor `useReducedMotion()` no puede saber nada, asi
/// que ese HTML sale SIEMPRE con `opacity:0;transform:translateY(20px)` metido
/// en el atributo `style`. Al hidratar, si nos limitamos a retirar las props
/// no queda nadie que anime esos estilos y el elemento se queda congelado
/// donde lo dejo el servidor: **invisible para siempre**, justo para la
/// persona que pidio que las cosas se movieran menos.
///
/// Se midio en el navegador, no se dedujo. Devolviendo `{}`, y tambien
/// devolviendo solo `{initial: false}`, el titulo de talleres seguia en
/// `opacity: 0` y la cabecera en `matrix(1, 0, 0, 1, 0, -100)` pasados dos
/// segundos y medio. `initial: false` por si solo significa "no animes desde
/// el principio", no "borra lo que ya hay escrito".
///
/// Por eso el reducido lleva destino: `initial: false` para no animar la
/// entrada y `animate: REPOSO` para que framer PISE el estilo inline heredado
/// del servidor. `duration: 0` remata: se llega ahi sin recorrido.
export function aparicion(reducido: boolean, props: MotionProps): MotionProps {
  return reducido
    ? { initial: false, animate: REPOSO, transition: { duration: 0 } }
    : props;
}
