"use client";

import { useTranslations } from "next-intl";
import { motion, AnimatePresence } from "framer-motion";
import { useState } from "react";
import Image from "next/image";

export default function FeaturesGrid() {
  const t = useTranslations();
  const [activeIndex, setActiveIndex] = useState(0);

  const features = [
    {
      title: t("tabGarageTitle"),
      desc: t("tabGarageSubtitle"),
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" /></svg>
      )
    },
    {
      title: t("tabHistoryTitle"),
      desc: t("tabHistorySubtitle"),
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
      )
    },
    {
      title: t("tabAlertsTitle"),
      desc: t("tabAlertsSubtitle"),
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" /></svg>
      )
    },
    {
      title: t("tabSyncTitle"),
      desc: t("tabSyncSubtitle"),
      icon: (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>
      )
    }
  ];

  return (
    <section id="features" className="relative z-10 w-full bg-slate-100 dark:bg-[#0a0f1e] py-32 overflow-hidden transition-colors duration-300">
      <div className="mx-auto max-w-7xl px-6 lg:flex lg:gap-16 lg:items-center">
        
        {/* Left Column: Feature List */}
        <div className="lg:w-1/2">
          <div className="space-y-4">
            {features.map((feat, index) => {
              const isActive = index === activeIndex;
              return (
                <motion.div
                  key={index}
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => setActiveIndex(index)}
                  className={`cursor-pointer rounded-2xl p-6 transition-all duration-300 relative overflow-hidden ${
                    isActive 
                      ? "bg-white dark:bg-gradient-to-r dark:from-[#522C81]/60 dark:to-purple-800/20 shadow-md dark:shadow-none border border-transparent dark:border-purple-500/30" 
                      : "bg-white/60 dark:bg-[#111827] border border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700"
                  }`}
                >
                  {/* Cyan/Primary Active Border */}
                  {isActive && (
                    <motion.div 
                      layoutId="activeBorder"
                      className="absolute left-0 top-0 bottom-0 w-1.5 bg-[#81E6D9] dark:bg-sky-400 rounded-l-2xl"
                    />
                  )}
                  
                  <div className="flex items-start gap-4 ml-2">
                    <div className={`mt-1 flex-shrink-0 transition-colors ${isActive ? "text-[#522C81] dark:text-white" : "text-slate-400"}`}>
                      {feat.icon}
                    </div>
                    <div>
                      <h3 className={`text-xl font-bold transition-colors ${isActive ? "text-slate-900 dark:text-white" : "text-slate-600 dark:text-slate-200"}`}>
                        {feat.title}
                      </h3>
                      <p className={`mt-2 leading-relaxed transition-colors ${isActive ? "text-slate-600 dark:text-slate-200" : "text-slate-500"}`}>
                        {feat.desc}
                      </p>
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </div>
        </div>

        {/* Right Column: Visual Preview */}
        <div className="lg:w-1/2 mt-16 lg:mt-0 relative h-[600px]">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeIndex}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              transition={{ duration: 0.4 }}
              className="absolute inset-0 rounded-[2.5rem] overflow-hidden border border-slate-200 dark:border-slate-800 bg-white dark:bg-[#111827] shadow-xl dark:shadow-none"
            >
              {activeIndex === 0 && (
                <div className="relative w-full h-full">
                  <div 
                    className="absolute inset-0 bg-cover bg-center transition-transform duration-1000 hover:scale-105 opacity-80 dark:opacity-60"
                    style={{ backgroundImage: 'url(https://images.unsplash.com/photo-1592199564137-731e91904939?crop=entropy&cs=srgb&fm=jpg&ixid=M3w3NTAwNDR8MHwxfHNlYXJjaHwxfHxtb2Rlcm4lMjBsdXh1cnklMjBjYXIlMjBwYXJrZWQlMjBpbiUyMGElMjBtaW5pbWFsaXN0JTIwYnJpZ2h0JTIwc3R1ZGlvfGVufDB8fHx8MTc4Mjk0MjYxNnww&ixlib=rb-4.1.0&q=85)' }}
                  />
                  
                  {/* Overlay Widgets */}
                  <div className="absolute inset-0 flex items-center justify-center p-12">
                    <div className="grid grid-cols-2 gap-4 w-full max-w-md">
                      <div className="bg-white/80 dark:bg-[#0f172a]/60 backdrop-blur-md rounded-lg p-3 border border-slate-200 dark:border-sky-400/20 flex flex-col gap-1 shadow-sm">
                        <span className="text-[10px] text-[#522C81] dark:text-sky-400 font-bold uppercase">Modelo</span>
                        <span className="text-sm font-bold text-slate-900 dark:text-white">Porsche 911 Carrera</span>
                      </div>
                      <div className="bg-white/80 dark:bg-[#0f172a]/60 backdrop-blur-md rounded-lg p-3 border border-slate-200 dark:border-sky-400/20 flex flex-col gap-1 shadow-sm">
                        <span className="text-[10px] text-[#522C81] dark:text-sky-400 font-bold uppercase">Año</span>
                        <span className="text-sm font-bold text-slate-900 dark:text-white">2023</span>
                      </div>
                      <div className="bg-white/80 dark:bg-[#0f172a]/60 backdrop-blur-md rounded-lg p-3 border border-slate-200 dark:border-sky-400/20 col-span-2 flex items-center justify-between shadow-sm">
                        <div className="flex flex-col gap-1">
                          <span className="text-[10px] text-[#522C81] dark:text-sky-400 font-bold uppercase">Seguro SOAT</span>
                          <span className="text-sm font-bold text-slate-900 dark:text-white">Vigente hasta Dic 2026</span>
                        </div>
                        <svg className="w-6 h-6 text-[#81E6D9] dark:text-sky-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {activeIndex === 1 && (
                <div className="relative w-full h-full bg-slate-50/90 dark:bg-slate-900/50 flex flex-col p-12">
                  <div 
                    className="absolute inset-0 bg-cover bg-center opacity-10 dark:opacity-30"
                    style={{ backgroundImage: 'url(https://images.pexels.com/photos/8985913/pexels-photo-8985913.jpeg)' }}
                  />
                  <h4 className="text-2xl font-bold mb-8 relative z-10 text-slate-900 dark:text-white">{t("featuresTimelineTitle")}</h4>
                  <div className="space-y-6 relative z-10 max-w-sm">
                    <div className="flex gap-4 items-start">
                      <div className="w-3 h-3 rounded-full bg-[#81E6D9] dark:bg-sky-400 mt-1.5 shadow-[0_0_10px_rgba(129,230,217,0.8)] dark:shadow-[0_0_10px_rgba(56,189,248,0.8)]"></div>
                      <div>
                        <p className="text-xs text-[#522C81] dark:text-sky-400 font-bold">15 JUN 2026</p>
                        <p className="text-sm font-bold text-slate-900 dark:text-white">{t("featuresTimelineItemTitle")}</p>
                        <p className="text-[10px] text-slate-500 dark:text-slate-400">Taller Central Motor • 45,000 km</p>
                      </div>
                    </div>
                    <div className="flex gap-4 items-start opacity-60">
                      <div className="w-3 h-3 rounded-full bg-slate-400 dark:bg-slate-600 mt-1.5"></div>
                      <div>
                        <p className="text-xs text-slate-500 dark:text-slate-400">12 MAR 2026</p>
                        <p className="text-sm font-bold text-slate-900 dark:text-white">Mantenimiento Preventivo</p>
                        <p className="text-[10px] text-slate-500 dark:text-slate-400">AutoExpress • 42,300 km</p>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {activeIndex === 2 && (
                <div className="relative w-full h-full flex items-center justify-center">
                  <div 
                    className="absolute inset-0 bg-cover bg-center opacity-30 dark:opacity-50"
                    style={{ backgroundImage: 'url(https://images.pexels.com/photos/10924197/pexels-photo-10924197.jpeg)' }}
                  />
                  <div className="relative z-10 w-[80%] max-w-sm">
                    <div className="bg-white dark:bg-sky-400 p-6 rounded-2xl shadow-xl dark:shadow-[0_20px_50px_rgba(56,189,248,0.3)] transform -rotate-2 text-slate-900 dark:text-[#0f172a] border border-slate-100 dark:border-none">
                      <div className="flex items-center gap-4">
                        <svg className="w-10 h-10 text-[#FC8181] dark:text-inherit" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
                        <div>
                          <p className="font-black text-lg leading-tight">{t("featuresAlertTitle")}</p>
                          <p className="text-xs font-bold opacity-80 text-[#FC8181] dark:text-inherit">{t("featuresAlertDesc")}</p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {activeIndex === 3 && (
                <div className="w-full h-full p-12 flex flex-col justify-center gap-8 bg-white dark:bg-[#111827]">
                   <div className="flex items-center gap-12 justify-center">
                      <div className="flex flex-col items-center gap-3">
                        <div className="w-20 h-20 rounded-3xl bg-slate-50 dark:bg-[#0f172a] border border-slate-200 dark:border-sky-400/30 flex items-center justify-center text-4xl shadow-sm">
                          <svg className="w-10 h-10 text-[#522C81] dark:text-sky-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                        </div>
                        <span className="text-xs font-bold text-slate-500">TALLER</span>
                      </div>
                      <div className="flex-1 max-w-[120px] h-px bg-gradient-to-r from-[#81E6D9]/50 to-[#81E6D9]/50 dark:from-sky-400/50 dark:to-sky-400/50 relative">
                        <div className="absolute inset-0 flex items-center justify-center">
                          <svg className="w-5 h-5 text-[#81E6D9] dark:text-sky-400 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
                        </div>
                      </div>
                      <div className="flex flex-col items-center gap-3">
                        <div className="w-20 h-20 rounded-3xl bg-[#522C81] dark:bg-sky-400 flex items-center justify-center text-4xl shadow-md">
                          <svg className="w-10 h-10 text-white dark:text-[#0f172a]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" /></svg>
                        </div>
                        <span className="text-xs font-bold text-[#522C81] dark:text-sky-400">TU APP</span>
                      </div>
                   </div>
                   <div className="text-center mt-4">
                     <p className="text-xl font-bold mb-2 text-slate-900 dark:text-white">{t("featuresSyncTitle")}</p>
                     <p className="text-slate-500 dark:text-slate-400 text-sm max-w-xs mx-auto">{t("featuresSyncDesc")}</p>
                   </div>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        </div>

      </div>
    </section>
  );
}
