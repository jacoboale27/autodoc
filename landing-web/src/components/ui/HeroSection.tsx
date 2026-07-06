"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import Image from "next/image";
import { useTranslations } from "next-intl";

export default function HeroSection() {
  const t = useTranslations();

  return (
    <div className="relative z-10 mx-auto max-w-7xl px-6 pt-36 pb-24 sm:pt-48 lg:flex lg:items-center lg:gap-x-10 lg:px-8">
      {/* Left Column: Text Content */}
      <motion.div
        initial={{ opacity: 0, x: -50 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.8, delay: 0.2 }}
        className="mx-auto max-w-2xl lg:mx-0 lg:flex-auto"
      >
        <div className="mb-6 flex">
          <div className="rounded-full border border-[#522C81]/30 dark:border-slate-600 bg-[#522C81]/10 dark:bg-transparent px-4 py-1.5 text-xs font-bold tracking-[0.15em] text-[#522C81] dark:text-white">
            {t("heroBadge")}
          </div>
        </div>

        <h1 className="mb-6 text-5xl font-extrabold tracking-tight text-slate-900 dark:text-white sm:text-7xl leading-tight">
          {t("heroTitle").split('\n').map((line, i) => (
            <span key={i}>
              {line}
              {i === 0 && <br />}
            </span>
          ))}
        </h1>

        <p className="mb-10 text-lg text-slate-600 dark:text-slate-300 sm:text-xl max-w-xl">
          {t("heroSubtitle")}
        </p>
        
        <div className="flex flex-col items-start space-y-4 sm:flex-row sm:items-center sm:space-x-8 sm:space-y-0">
          <Link href="https://autodoc-6ef5a.web.app/login" passHref target="_blank">
            <motion.button
              whileHover={{ scale: 1.05, x: 5 }}
              whileTap={{ scale: 0.95 }}
              className="flex items-center gap-2 text-lg font-bold text-[#522C81] dark:text-white transition-all hover:text-[#3d2062] dark:hover:text-sky-400"
            >
              {t("heroStartGarage")} <span>→</span>
            </motion.button>
          </Link>
          
          <Link href="#features">
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="rounded-xl border border-slate-300 dark:border-slate-600 bg-white/50 dark:bg-transparent px-6 py-3 font-semibold text-slate-700 dark:text-white backdrop-blur-md transition-all hover:bg-slate-100 dark:hover:bg-slate-800 shadow-sm dark:shadow-none"
            >
              {t("heroViewDirectory")}
            </motion.button>
          </Link>
        </div>
      </motion.div>

      {/* Right Column: Mockups */}
      <motion.div
        initial={{ opacity: 0, x: 50 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.8, delay: 0.4 }}
        className="relative mt-16 sm:mt-24 lg:mt-0 lg:flex-shrink-0 lg:flex-grow h-[600px] hidden md:block"
      >
        {/* Back Phone (Dashboard) */}
        <motion.div
          animate={{ y: [0, -10, 0] }}
          transition={{ repeat: Infinity, duration: 6, ease: "easeInOut" }}
          className="absolute right-0 top-10 w-72 rotate-[12deg] overflow-hidden rounded-[2.5rem] border-8 border-slate-200 dark:border-slate-900 bg-white dark:bg-slate-900 shadow-xl dark:shadow-2xl"
        >
          <div className="relative aspect-[9/19.5] w-full">
            <Image
              src="/assets/dashboard.jpg"
              alt="Dashboard App"
              fill
              className="object-cover"
              priority
            />
          </div>
        </motion.div>

        {/* Front Phone (Directory) */}
        <motion.div
          animate={{ y: [0, 15, 0] }}
          transition={{ repeat: Infinity, duration: 5, ease: "easeInOut", delay: 1 }}
          className="absolute right-32 top-32 w-72 -rotate-[5deg] overflow-hidden rounded-[2.5rem] border-8 border-slate-200 dark:border-slate-900 bg-white dark:bg-slate-900 shadow-2xl z-10"
        >
          <div className="relative aspect-[9/19.5] w-full">
            <Image
              src="/assets/dashboard.jpg"
              alt="Dashboard App"
              fill
              className="object-cover"
              priority
            />
          </div>
        </motion.div>
      </motion.div>
    </div>
  );
}
