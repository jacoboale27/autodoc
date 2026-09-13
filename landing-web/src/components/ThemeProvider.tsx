"use client";

import { ThemeProvider as NextThemesProvider } from "next-themes";
import { MotionConfig } from "framer-motion";

/// Envuelve tambien el `MotionConfig` porque el layout es un componente de
/// servidor y `MotionConfig` necesita cliente. Este es el unico punto por el
/// que pasa toda la landing.
///
/// `reducedMotion="user"` es la red de seguridad, no el arreglo: desactiva las
/// animaciones de transform y de layout que se nos escapen —un `whileHover`
/// nuevo, por ejemplo— pero **deja vivas las de opacidad a proposito**, porque
/// un fundido no provoca mareo. El revelado por scroll de las secciones se
/// desactiva aparte, en cada componente, con `aparicion()` de
/// `@/lib/movimiento`.
export function ThemeProvider({
  children,
  ...props
}: React.ComponentProps<typeof NextThemesProvider>) {
  return (
    <NextThemesProvider {...props}>
      <MotionConfig reducedMotion="user">{children}</MotionConfig>
    </NextThemesProvider>
  );
}
