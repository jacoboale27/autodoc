"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import Image from "next/image";
import { motion } from "framer-motion";
import { useTheme } from "next-themes";
import { Link as LinkLocalizado, usePathname, useRouter } from "@/i18n/routing";
import { Moon, Sun, Languages, Menu, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from "react";
import { aparicion, useMovimientoReducido } from "@/lib/movimiento";

const WEB_APP_URL = "https://autodoc-6ef5a.web.app";

const ID_PANEL_MOVIL = "menu-movil";

// La hidratacion no necesita suscripcion: React compara el snapshot servidor/cliente.
const sinSuscripcion = () => () => {};

/// Las tres secciones de la home. Se declaran una vez y se pintan en los dos
/// sitios —barra de escritorio y panel movil— para que no puedan divergir: el
/// defecto que arregla UX-03 es justamente que uno de los dos no existia.
const SECCIONES = [
  { href: "/#features", clave: "navOwners" },
  { href: "/#workshops", clave: "navWorkshops" },
  { href: "/#testimonials", clave: "navTestimonials" },
] as const;

export default function Header() {
  const t = useTranslations();
  const { theme, setTheme } = useTheme();
  const mounted = useSyncExternalStore(sinSuscripcion, () => true, () => false);
  const [abierto, setAbierto] = useState(false);
  const router = useRouter();
  const pathname = usePathname();
  const reducido = useMovimientoReducido();
  const botonMenu = useRef<HTMLButtonElement>(null);
  const panel = useRef<HTMLDivElement>(null);

  const cerrar = useCallback((devolverFoco: boolean) => {
    setAbierto(false);
    if (devolverFoco) botonMenu.current?.focus();
  }, []);

  // Al abrir, el foco entra al panel. Sin esto el menu es inutil con teclado:
  // el boton se queda con el foco y el siguiente Tab se va al contenido de
  // detras, saltandose los enlaces que se acaban de mostrar.
  useEffect(() => {
    if (!abierto) return;
    panel.current?.querySelector<HTMLElement>("a, button")?.focus();
  }, [abierto]);

  // Escape cierra y devuelve el foco a donde estaba. Se escucha en el
  // documento y no en el panel porque el foco puede haber salido de el.
  useEffect(() => {
    if (!abierto) return;
    const alPulsar = (e: KeyboardEvent) => {
      if (e.key === "Escape") cerrar(true);
    };
    document.addEventListener("keydown", alPulsar);
    return () => document.removeEventListener("keydown", alPulsar);
  }, [abierto, cerrar]);

  const toggleLanguage = () => {
    const nextLocale = document.documentElement.lang === "es" ? "en" : "es";
    router.replace(pathname, { locale: nextLocale });
  };

  const toggleTheme = () => {
    setTheme(theme === "light" ? "dark" : "light");
  };

  return (
    <motion.header
      {...aparicion(reducido, { initial: { y: -100 }, animate: { y: 0 } })}
      className="fixed left-0 right-0 top-6 z-50 flex justify-center px-4 transition-all duration-300"
    >
      <div className="w-full max-w-5xl rounded-3xl md:rounded-full border border-slate-200 dark:border-slate-700/50 bg-white/90 dark:bg-[#111827]/80 px-6 py-3 shadow-lg backdrop-blur-md">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2">
            <Image
              src="/logo-icon.svg"
              alt="AutoDoc"
              width={32}
              height={32}
              className="h-8 w-8 rounded-lg shadow-[0_0_10px_rgba(82,44,129,0.5)] dark:shadow-[0_0_10px_rgba(56,189,248,0.5)]"
            />
            <span className="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
              {t("appName")}
            </span>
          </Link>

          {/* Navigation */}
          <nav className="hidden md:flex items-center gap-8">
            {SECCIONES.map((seccion) => (
              <LinkLocalizado
                key={seccion.href}
                href={seccion.href}
                className="text-sm font-medium text-slate-600 dark:text-slate-200 transition hover:text-[#522C81] dark:hover:text-sky-400"
              >
                {t(seccion.clave)}
              </LinkLocalizado>
            ))}
          </nav>

          {/* Actions & Toggles */}
          <div className="flex items-center gap-4">
            <div className="hidden md:flex items-center gap-2 border-r border-slate-300 dark:border-slate-700 pr-4">
              <button
                onClick={toggleLanguage}
                data-testid="cambiar-idioma"
                className="p-2 text-slate-600 dark:text-slate-300 hover:text-[#522C81] dark:hover:text-sky-400 transition"
                aria-label={t("navCambiarIdioma")}
              >
                <Languages className="w-5 h-5" />
              </button>
              {mounted && (
                <button
                  onClick={toggleTheme}
                  data-testid="cambiar-tema"
                  className="p-2 text-slate-600 dark:text-slate-300 hover:text-[#522C81] dark:hover:text-sky-400 transition"
                  aria-label={
                    theme === "dark" ? t("navTemaClaro") : t("navTemaOscuro")
                  }
                >
                  {theme === "dark" ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
                </button>
              )}
            </div>

            <Link
              href={`${WEB_APP_URL}/login`}
              target="_blank"
              className="hidden sm:block text-sm font-bold text-slate-900 dark:text-white transition hover:text-[#522C81] dark:hover:text-sky-400"
            >
              {t("navLogin")}
            </Link>
            {/* Un solo nodo interactivo: antes era `<Link><button>`, o sea un
                boton dentro de un ancla — HTML invalido, y un lector de
                pantalla lo anunciaba como enlace Y como boton. */}
            <Link
              href={`${WEB_APP_URL}/register`}
              target="_blank"
              className="rounded-full bg-[#522C81] px-3 py-2 text-xs sm:text-sm font-bold text-white transition hover:bg-[#3d2062] whitespace-nowrap"
            >
              {t("navTryFree")}
            </Link>

            <button
              ref={botonMenu}
              type="button"
              data-testid="menu-movil-boton"
              className="md:hidden p-2 text-slate-600 dark:text-slate-300 hover:text-[#522C81] dark:hover:text-sky-400 transition"
              aria-label={abierto ? t("navCerrarMenu") : t("navAbrirMenu")}
              aria-expanded={abierto}
              aria-controls={ID_PANEL_MOVIL}
              onClick={() => setAbierto((v) => !v)}
            >
              {abierto ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
          </div>
        </div>

        {/* Panel movil.
            Se desmonta al cerrar en vez de ocultarse con `hidden`: un panel
            escondido por CSS sigue siendo tabulable si alguien olvida el
            `inert`, y entonces el teclado se pierde en enlaces invisibles. */}
        {abierto && (
          <div
            ref={panel}
            id={ID_PANEL_MOVIL}
            className="md:hidden mt-4 flex flex-col gap-1 border-t border-slate-200 dark:border-slate-700/50 pt-4"
          >
            {SECCIONES.map((seccion) => (
              <LinkLocalizado
                key={seccion.href}
                href={seccion.href}
                onClick={() => cerrar(false)}
                className="rounded-lg px-2 py-3 text-base font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800"
              >
                {t(seccion.clave)}
              </LinkLocalizado>
            ))}
            {/* A estos anchos la barra esconde ambos CTA (`hidden sm:*`), asi
                que este panel es el UNICO sitio donde pueden aparecer. */}
            <Link
              href={`${WEB_APP_URL}/login`}
              target="_blank"
              onClick={() => cerrar(false)}
              className="rounded-lg px-2 py-3 text-base font-bold text-slate-900 dark:text-white hover:bg-slate-100 dark:hover:bg-slate-800"
            >
              {t("navLogin")}
            </Link>
            <div className="mt-2 flex items-center gap-2 border-t border-slate-200 dark:border-slate-700/50 pt-3">
              <button
                type="button"
                onClick={toggleLanguage}
                className="rounded-lg p-2 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800"
                aria-label={t("navCambiarIdioma")}
              >
                <Languages className="w-5 h-5" />
              </button>
              {mounted && (
                <button
                  type="button"
                  onClick={toggleTheme}
                  className="rounded-lg p-2 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800"
                  aria-label={
                    theme === "dark" ? t("navTemaClaro") : t("navTemaOscuro")
                  }
                >
                  {theme === "dark" ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
                </button>
              )}
            </div>
          </div>
        )}
      </div>
    </motion.header>
  );
}
