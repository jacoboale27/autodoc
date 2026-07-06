"use client";

import { useTranslations } from "next-intl";
import { motion } from "framer-motion";

export default function ValuePropSection() {
  const t = useTranslations();

  return (
    <section id="owners" className="relative z-10 w-full bg-white dark:bg-[#0f172a] py-24 transition-colors duration-300">
      <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-16 px-6 lg:flex-row">
        {/* Text Content */}
        <motion.div
          initial={{ opacity: 0, x: -50 }}
          whileInView={{ opacity: 1, x: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.8 }}
          className="flex-1"
        >
          <h2 className="mb-6 text-4xl font-extrabold text-slate-900 dark:text-white sm:text-5xl lg:text-6xl">
            {t("valuePropTitle")}
          </h2>
          <p className="mb-10 text-lg leading-relaxed text-slate-600 dark:text-slate-300 sm:text-xl">
            {t("valuePropSubtitle")}
          </p>
          
          <div className="flex gap-12">
            <div>
              <p className="text-3xl font-black text-[#522C81] dark:text-sky-400">98%</p>
              <p className="mt-1 text-sm font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">
                {t("statSatisfaction")}
              </p>
            </div>
            <div>
              <p className="text-3xl font-black text-[#522C81] dark:text-sky-400">+500</p>
              <p className="mt-1 text-sm font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">
                {t("statWorkshops")}
              </p>
            </div>
          </div>
        </motion.div>

        {/* Visual Content */}
        <motion.div
          initial={{ opacity: 0, x: 50 }}
          whileInView={{ opacity: 1, x: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.8, delay: 0.2 }}
          className="relative flex-1"
        >
          <div className="relative h-[400px] w-full overflow-hidden rounded-[2.5rem] border border-slate-200 dark:border-slate-800 lg:h-[600px] shadow-2xl dark:shadow-none">
            {/* The unsplash image from Flutter value_prop_section.dart */}
            <div 
              className="absolute inset-0 bg-cover bg-center"
              style={{ backgroundImage: 'url(https://images.unsplash.com/photo-1649769069590-268b0b994462)' }}
            />
            {/* Overlay gradient */}
            <div className="absolute inset-0 bg-gradient-to-t from-white via-transparent to-transparent opacity-80 dark:from-[#0f172a]" />
          </div>
          
          {/* Decorative Glow */}
          <div className="absolute -inset-4 -z-10 rounded-[3rem] bg-[#522C81]/10 dark:bg-sky-500/20 blur-3xl" />
        </motion.div>
      </div>
    </section>
  );
}
