"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import Image from "next/image";
import { useTranslations } from "next-intl";
import { APP_STORE_URL, PLAY_STORE_URL, WEB_APP_URL } from "@/lib/enlaces";
import { aparicion, useMovimientoReducido } from "@/lib/movimiento";

export default function HeroSection() {
  const t = useTranslations();
  const reducido = useMovimientoReducido();

  const scrollToWorkshops = () => {
    const el = document.getElementById("workshops");
    if (el) {
      // `smooth` es movimiento aunque no lo parezca: bajo la preferencia se
      // salta al destino en vez de recorrer la pagina entera.
      el.scrollIntoView({ behavior: reducido ? "auto" : "smooth" });
    }
  };

  return (
    <div className="relative z-10 mx-auto max-w-7xl px-6 pt-36 pb-24 sm:pt-48 lg:flex lg:items-center lg:gap-x-10 lg:px-8">
      {/* Left Column: Text Content */}
      <motion.div
        {...aparicion(reducido, {
          initial: { opacity: 0, x: -50 },
          animate: { opacity: 1, x: 0 },
          transition: { duration: 0.8, delay: 0.2 },
        })}
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
        
        {/* Dual CTAs & App Badges */}
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-4">
            {/* Era `<Link><motion.button>`: un boton dentro de un ancla, que
                el modelo de contenido de <a> prohibe. Ahora es un solo nodo. */}
            <motion.a
              href={`${WEB_APP_URL}/login`}
              target="_blank"
              rel="noopener noreferrer"
              {...aparicion(reducido, {
                whileHover: { scale: 1.05 },
                whileTap: { scale: 0.95 },
              })}
              className="w-full sm:w-auto rounded-xl bg-[#522C81] px-8 py-4 font-bold text-white shadow-lg transition-all hover:bg-[#3d2062] hover:shadow-xl text-center"
            >
              {t("heroStartGarage")}
            </motion.a>

            <motion.button
              type="button"
              {...aparicion(reducido, {
                whileHover: { scale: 1.05 },
                whileTap: { scale: 0.95 },
              })}
              onClick={scrollToWorkshops}
              className="w-full sm:w-auto rounded-xl border-2 border-[#522C81] dark:border-purple-400 px-8 py-4 font-bold text-[#522C81] dark:text-purple-300 hover:bg-[#522C81]/10 dark:hover:bg-purple-900/30 transition-all text-center"
            >
              {t("heroAffiliateWorkshop")}
            </motion.button>
          </div>

          <div className="flex items-center gap-3 pt-2">
            <Link href={PLAY_STORE_URL} target="_blank" className="hover:opacity-80 transition-opacity">
              <Image 
                src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" 
                alt="Get it on Google Play" 
                width={135} 
                height={40} 
                className="h-[40px] w-auto"
              />
            </Link>
            {/* Badge de iOS: solo cuando exista ficha publica. Ver lib/enlaces.ts. */}
            {APP_STORE_URL && (
              <Link href={APP_STORE_URL} target="_blank" className="hover:opacity-80 transition-opacity">
                <Image
                  src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg"
                  alt="Download on the App Store"
                  width={120}
                  height={40}
                  className="h-[40px] w-auto"
                />
              </Link>
            )}
          </div>
        </div>
      </motion.div>

      {/* Right Column: Mockups */}
      <motion.div
        {...aparicion(reducido, {
          initial: { opacity: 0, x: 50 },
          animate: { opacity: 1, x: 0 },
          transition: { duration: 0.8, delay: 0.4 },
        })}
        className="relative mt-16 sm:mt-24 lg:mt-0 lg:flex-shrink-0 lg:flex-grow h-[600px] hidden md:block"
      >
        {/* Back Phone (Directory) */}
        {/* Flotaba con `repeat: Infinity`. Movimiento continuo e indefinido es
            el caso que la preferencia existe para evitar, asi que aqui no se
            acorta: se retira. */}
        <motion.div
          {...aparicion(reducido, {
            animate: { y: [0, -10, 0] },
            transition: { repeat: Infinity, duration: 6, ease: "easeInOut" },
          })}
          className="absolute right-0 top-10 w-72 rotate-[12deg] overflow-hidden rounded-[2.5rem] border-8 border-slate-200 dark:border-slate-900 bg-white dark:bg-slate-900 shadow-xl dark:shadow-2xl"
        >
          <div className="relative aspect-[9/19.5] w-full">
            <Image
              src="/assets/directory.jpg"
              alt="Directory App"
              fill
              className="object-cover"
              priority
            />
          </div>
        </motion.div>

        {/* Front Phone (Dashboard) */}
        <motion.div
          {...aparicion(reducido, {
            animate: { y: [0, 15, 0] },
            transition: {
              repeat: Infinity,
              duration: 5,
              ease: "easeInOut",
              delay: 1,
            },
          })}
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
