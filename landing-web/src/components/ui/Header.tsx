"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import { motion } from "framer-motion";
import { useTheme } from "next-themes";
import { usePathname, useRouter } from "@/i18n/routing";
import { Moon, Sun, Languages } from "lucide-react";
import { useEffect, useState } from "react";

export default function Header() {
  const t = useTranslations();
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    setMounted(true);
  }, []);

  const toggleLanguage = () => {
    // Determine current locale based on pathname (if possible) or default logic
    // Since we don't have access to current locale directly from useTranslations easily without a hook, 
    // we can use document.documentElement.lang or let next-intl handle it
    const nextLocale = document.documentElement.lang === "es" ? "en" : "es";
    router.replace(pathname, { locale: nextLocale });
  };

  const toggleTheme = () => {
    setTheme(theme === "light" ? "dark" : "light");
  };

  return (
    <motion.header
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      className="fixed left-0 right-0 top-6 z-50 flex justify-center px-4 transition-all duration-300"
    >
      <div className="flex w-full max-w-5xl items-center justify-between rounded-full border border-slate-200 dark:border-slate-700/50 bg-white/90 dark:bg-[#111827]/80 px-6 py-3 shadow-lg backdrop-blur-md">
        {/* Logo */}
        <div className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-[#522C81] dark:bg-sky-500 shadow-[0_0_10px_rgba(82,44,129,0.5)] dark:shadow-[0_0_10px_rgba(56,189,248,0.5)]">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              strokeWidth={2}
              stroke="currentColor"
              className="h-5 w-5 text-white"
            >
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
            </svg>
          </div>
          <span className="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
            {t("appName")}
          </span>
        </div>

        {/* Navigation */}
        <nav className="hidden md:flex items-center gap-8">
          <Link href="#platform" className="text-sm font-medium text-slate-600 dark:text-slate-200 transition hover:text-[#522C81] dark:hover:text-sky-400">
            {t("navPlatform")}
          </Link>
          <Link href="#owners" className="text-sm font-medium text-slate-600 dark:text-slate-200 transition hover:text-[#522C81] dark:hover:text-sky-400">
            {t("navOwners")}
          </Link>
          <Link href="#workshops" className="text-sm font-medium text-slate-600 dark:text-slate-200 transition hover:text-[#522C81] dark:hover:text-sky-400">
            {t("navWorkshops")}
          </Link>
        </nav>

        {/* Actions & Toggles */}
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2 border-r border-slate-300 dark:border-slate-700 pr-4">
            <button
              onClick={toggleLanguage}
              className="p-2 text-slate-600 dark:text-slate-300 hover:text-[#522C81] dark:hover:text-sky-400 transition"
              aria-label="Toggle language"
            >
              <Languages className="w-5 h-5" />
            </button>
            {mounted && (
              <button
                onClick={toggleTheme}
                className="p-2 text-slate-600 dark:text-slate-300 hover:text-[#522C81] dark:hover:text-sky-400 transition"
                aria-label="Toggle theme"
              >
                {theme === "dark" ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
              </button>
            )}
          </div>
          
          <Link href="https://autodoc-6ef5a.web.app/login" target="_blank" className="hidden sm:block text-sm font-bold text-slate-900 dark:text-white transition hover:text-[#522C81] dark:hover:text-sky-400">
            {t("navLogin")}
          </Link>
          <Link href="https://autodoc-6ef5a.web.app/register" target="_blank">
            <button className="rounded-full bg-[#522C81] dark:bg-transparent dark:border-none px-4 py-2 text-sm font-bold text-white transition hover:bg-[#3d2062] dark:hover:text-sky-400">
              {t("navTryFree")}
            </button>
          </Link>
        </div>
      </div>
    </motion.header>
  );
}
