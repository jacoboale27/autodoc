import { getTranslations } from "next-intl/server";
import { setRequestLocale } from 'next-intl/server';
import Header from "@/components/ui/Header";
import Footer from "@/components/ui/Footer";
import { Mail, Phone, MapPin } from "lucide-react";
import { motion } from "framer-motion";

export default async function ContactPage({
  params
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations();

  return (
    <main className="relative min-h-screen bg-slate-50 text-slate-900 dark:bg-[#0f172a] dark:text-white">
      <Header />
      <div className="pt-32 pb-24 max-w-4xl mx-auto px-6">
        <h1 className="text-4xl font-bold mb-4 text-center">Contáctanos</h1>
        <p className="text-center text-slate-600 dark:text-slate-400 mb-12">
          Estamos aquí para ayudarte. Si tienes preguntas, sugerencias o necesitas soporte, no dudes en escribirnos.
        </p>

        <div className="grid md:grid-cols-2 gap-12">
          <div>
            <h2 className="text-2xl font-bold mb-6">Información de Contacto</h2>
            <div className="space-y-6">
              <div className="flex items-center gap-4">
                <div className="bg-[#522C81]/10 p-3 rounded-full text-[#522C81] dark:text-purple-400">
                  <Mail size={24} />
                </div>
                <div>
                  <p className="font-medium">Correo Electrónico</p>
                  <a href="mailto:soporte@autodoc.app" className="text-slate-600 dark:text-slate-400 hover:text-[#522C81] dark:hover:text-purple-400">
                    soporte@autodoc.app
                  </a>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="bg-[#522C81]/10 p-3 rounded-full text-[#522C81] dark:text-purple-400">
                  <Phone size={24} />
                </div>
                <div>
                  <p className="font-medium">Teléfono</p>
                  <p className="text-slate-600 dark:text-slate-400">+503 2222-3333</p>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="bg-[#522C81]/10 p-3 rounded-full text-[#522C81] dark:text-purple-400">
                  <MapPin size={24} />
                </div>
                <div>
                  <p className="font-medium">Oficinas</p>
                  <p className="text-slate-600 dark:text-slate-400">San Salvador, El Salvador</p>
                </div>
              </div>
            </div>
          </div>

          <div>
            <form className="space-y-4" action="#">
              <div>
                <label htmlFor="name" className="block text-sm font-medium mb-1">Nombre</label>
                <input
                  type="text"
                  id="name"
                  className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-[#522C81] outline-none"
                  placeholder="Tu nombre completo"
                />
              </div>
              <div>
                <label htmlFor="email" className="block text-sm font-medium mb-1">Correo Electrónico</label>
                <input
                  type="email"
                  id="email"
                  className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-[#522C81] outline-none"
                  placeholder="tu@correo.com"
                />
              </div>
              <div>
                <label htmlFor="message" className="block text-sm font-medium mb-1">Mensaje</label>
                <textarea
                  id="message"
                  rows={4}
                  className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-[#522C81] outline-none resize-none"
                  placeholder="¿En qué te podemos ayudar?"
                ></textarea>
              </div>
              <button
                type="submit"
                className="w-full bg-[#522C81] text-white font-bold py-3 px-4 rounded-lg hover:bg-[#3d2062] transition-colors"
              >
                Enviar Mensaje
              </button>
            </form>
          </div>
        </div>
      </div>
      <Footer />
    </main>
  );
}
