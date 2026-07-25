"use client";

import { useTranslations } from "next-intl";

export default function TestimonialsSection() {
  const t = useTranslations();

  return (
    <section id="testimonials" className="py-24 bg-slate-900/50 border-t border-slate-800/80">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Metric Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-16">
          <div className="bg-slate-800/40 backdrop-blur-sm border border-slate-700/50 rounded-2xl p-8 text-center hover:border-sky-500/40 transition-colors">
            <div className="text-4xl font-extrabold text-sky-400 mb-2">{t("statSatisfaction")}</div>
            <p className="text-slate-400 text-sm">{t("statSatisfactionSub")}</p>
          </div>
          <div className="bg-slate-800/40 backdrop-blur-sm border border-slate-700/50 rounded-2xl p-8 text-center hover:border-emerald-500/40 transition-colors">
            <div className="text-4xl font-extrabold text-emerald-400 mb-2">{t("statWorkshops")}</div>
            <p className="text-slate-400 text-sm">{t("statWorkshopsSub")}</p>
          </div>
          <div className="bg-slate-800/40 backdrop-blur-sm border border-slate-700/50 rounded-2xl p-8 text-center hover:border-indigo-500/40 transition-colors">
            <div className="text-4xl font-extrabold text-indigo-400 mb-2">{t("statServices")}</div>
            <p className="text-slate-400 text-sm">{t("statServicesSub")}</p>
          </div>
        </div>

        {/* Testimonials Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <h2 className="text-3xl font-extrabold text-white sm:text-4xl">
            {t("testimonialsTitle")}
          </h2>
        </div>

        {/* Testimonial Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="bg-slate-800/60 border border-slate-700 rounded-2xl p-8 shadow-xl flex flex-col justify-between hover:border-slate-600 transition-colors">
            <p className="text-slate-300 text-lg italic mb-6">"{t("testimonial1Quote")}"</p>
            <div className="flex items-center space-x-4">
              <div className="w-12 h-12 rounded-full bg-sky-500/20 text-sky-400 flex items-center font-bold justify-center text-lg border border-sky-500/30">
                CM
              </div>
              <div>
                <h4 className="text-white font-bold">{t("testimonial1Author")}</h4>
                <p className="text-slate-400 text-sm">{t("testimonial1Role")}</p>
              </div>
            </div>
          </div>

          <div className="bg-slate-800/60 border border-slate-700 rounded-2xl p-8 shadow-xl flex flex-col justify-between hover:border-slate-600 transition-colors">
            <p className="text-slate-300 text-lg italic mb-6">"{t("testimonial2Quote")}"</p>
            <div className="flex items-center space-x-4">
              <div className="w-12 h-12 rounded-full bg-emerald-500/20 text-emerald-400 flex items-center font-bold justify-center text-lg border border-emerald-500/30">
                TA
              </div>
              <div>
                <h4 className="text-white font-bold">{t("testimonial2Author")}</h4>
                <p className="text-slate-400 text-sm">{t("testimonial2Role")}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
