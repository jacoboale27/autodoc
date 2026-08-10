"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import Image from "next/image";

export default function Footer() {
  const t = useTranslations();

  return (
    <footer className="relative z-10 border-t border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-[#0a0f1e] pt-16 pb-8 transition-colors duration-300">
      <div className="mx-auto max-w-7xl px-6">
        <div className="grid grid-cols-1 gap-12 md:grid-cols-4 lg:gap-8">
          {/* Brand */}
          <div className="col-span-1 md:col-span-2">
            <div className="mb-4 flex items-center gap-2">
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
            </div>
            <p className="max-w-xs text-slate-500 dark:text-slate-400 text-sm">
              {t("footerDesc")}
            </p>
          </div>

          {/* Links */}
          <div>
            <h4 className="mb-6 font-bold text-slate-900 dark:text-white">{t("navPlatform")}</h4>
            <ul className="space-y-4 text-sm text-slate-500 dark:text-slate-400">
              <li><Link href="#features" className="hover:text-[#522C81] dark:hover:text-sky-400">{t("footerOwners")}</Link></li>
              <li><Link href="#workshops" className="hover:text-[#522C81] dark:hover:text-sky-400">{t("footerWorkshops")}</Link></li>
              <li><Link href="#testimonials" className="hover:text-[#522C81] dark:hover:text-sky-400">{t("navTestimonials")}</Link></li>
            </ul>
          </div>

          <div>
            <h4 className="mb-6 font-bold text-slate-900 dark:text-white">{t("downloadApp")}</h4>
            <div className="flex flex-col gap-3">
              <Link href="https://apps.apple.com/app/id123456789" target="_blank" className="inline-block hover:opacity-80 transition-opacity">
                <Image src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg" alt="Download on the App Store" width={120} height={40} className="h-10 w-auto" />
              </Link>
              <Link href="https://play.google.com/store/apps/details?id=com.autodoc.app" target="_blank" className="inline-block hover:opacity-80 transition-opacity">
                <Image src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" alt="Get it on Google Play" width={135} height={40} className="h-10 w-auto" />
              </Link>
            </div>
          </div>
        </div>

        <div className="mt-16 flex flex-col items-center justify-between border-t border-slate-200 dark:border-slate-800 pt-8 sm:flex-row text-sm text-slate-500">
          <p>{t("footerCopyright")}</p>
          <div className="mt-4 flex gap-6 sm:mt-0">
            <a href="mailto:soporte@autodoc.app" className="hover:text-slate-900 dark:hover:text-white">{t("footerContact")}</a>
            <a href="https://autodoc.app/privacidad" target="_blank" rel="noopener noreferrer" className="hover:text-slate-900 dark:hover:text-white">{t("footerPrivacy")}</a>
            <a href="https://autodoc.app/terminos" target="_blank" rel="noopener noreferrer" className="hover:text-slate-900 dark:hover:text-white">{t("footerTerms")}</a>
          </div>
        </div>
      </div>
    </footer>
  );
}
