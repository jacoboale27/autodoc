import createNextIntlPlugin from 'next-intl/plugin';
import type { NextConfig } from "next";

const withNextIntl = createNextIntlPlugin();

const nextConfig: NextConfig = {
  output: "export",
  images: {
    unoptimized: true,
  },
  // Sin esto, Next infiere la raiz del workspace subiendo directorios en
  // busca de lockfiles y puede toparse con uno ajeno al proyecto (p. ej. uno
  // en el perfil de Windows del usuario) antes de encontrar el de
  // `landing-web`. `next.config.ts` se compila con soporte de `__dirname`
  // aunque el archivo use sintaxis ESM.
  turbopack: {
    root: __dirname,
  },
};

export default withNextIntl(nextConfig);
