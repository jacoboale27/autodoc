"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";

export default function Footer() {
  const t = useTranslations();

  return (
    <footer className="relative z-10 border-t border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-[#0a0f1e] pt-16 pb-8 transition-colors duration-300">
      <div className="mx-auto max-w-7xl px-6">
        <div className="grid grid-cols-1 gap-12 md:grid-cols-4 lg:gap-8">
          {/* Brand */}
          <div className="col-span-1 md:col-span-2">
            <div className="mb-4 flex items-center gap-2">
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
            <p className="max-w-xs text-slate-500 dark:text-slate-400">
              {t("footerDesc")}
            </p>
          </div>

          {/* Links */}
          <div>
            <h4 className="mb-6 font-bold text-slate-900 dark:text-white">{t("navPlatform")}</h4>
            <ul className="space-y-4 text-sm text-slate-500 dark:text-slate-400">
              <li><Link href="#owners" className="hover:text-[#522C81] dark:hover:text-sky-400">{t("footerOwners")}</Link></li>
              <li><Link href="#workshops" className="hover:text-[#522C81] dark:hover:text-sky-400">{t("footerWorkshops")}</Link></li>
            </ul>
          </div>

          <div>
            <h4 className="mb-6 font-bold text-slate-900 dark:text-white">Descarga la App</h4>
            <div className="flex flex-col gap-3">
              <a href="#" className="inline-block">
                <img src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg" alt="Download on the App Store" className="h-10" />
              </a>
              <a href="#" className="inline-block">
                <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" alt="Get it on Google Play" className="h-10" />
              </a>
            </div>
          </div>
        </div>

        <div className="mt-16 flex flex-col items-center justify-between border-t border-slate-200 dark:border-slate-800 pt-8 sm:flex-row text-sm text-slate-500">
          <p>{t("footerCopyright")}</p>
          <div className="mt-4 flex gap-4 sm:mt-0">
            <a href="https://autodoc.app/privacidad" target="_blank" rel="noopener noreferrer" className="hover:text-slate-900 dark:hover:text-white">Privacidad</a>
            <a href="https://autodoc.app/terminos" target="_blank" rel="noopener noreferrer" className="hover:text-slate-900 dark:hover:text-white">Términos</a>
          </div>
        </div>
      </div>
    </footer>
  );
}
