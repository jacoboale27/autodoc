import { getTranslations, setRequestLocale } from "next-intl/server";
import Header from "@/components/ui/Header";
import Footer from "@/components/ui/Footer";
import ContactForm from "@/components/ui/ContactForm";
import { Mail, Phone, MapPin } from "lucide-react";

// Correo real de soporte, tambien la salida alternativa si el envio falla.
const CORREO_SOPORTE = "soporte@autodoc.app";

export default async function ContactPage({
  params,
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
        <h1 className="text-4xl font-bold mb-4 text-center">{t("contactTitle")}</h1>
        <p className="text-center text-slate-600 dark:text-slate-400 mb-12">
          {t("contactSubtitle")}
        </p>

        <div className="grid md:grid-cols-2 gap-12">
          <div>
            <h2 className="text-2xl font-bold mb-6">{t("contactInfoTitle")}</h2>
            <div className="space-y-6">
              <div className="flex items-center gap-4">
                <div className="bg-[#522C81]/10 p-3 rounded-full text-[#522C81] dark:text-purple-400">
                  <Mail size={24} aria-hidden="true" />
                </div>
                <div>
                  <p className="font-medium">{t("contactEmailLabel")}</p>
                  <a
                    href={`mailto:${CORREO_SOPORTE}`}
                    className="text-slate-600 dark:text-slate-400 hover:text-[#522C81] dark:hover:text-purple-400"
                  >
                    {CORREO_SOPORTE}
                  </a>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="bg-[#522C81]/10 p-3 rounded-full text-[#522C81] dark:text-purple-400">
                  <Phone size={24} aria-hidden="true" />
                </div>
                <div>
                  <p className="font-medium">{t("contactPhoneLabel")}</p>
                  {/* Enlace `tel:`, no texto muerto: en movil el numero se
                      marca desde aqui, que es donde se lee. */}
                  <a
                    href="tel:+50322223333"
                    className="text-slate-600 dark:text-slate-400 hover:text-[#522C81] dark:hover:text-purple-400"
                  >
                    +503 2222-3333
                  </a>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="bg-[#522C81]/10 p-3 rounded-full text-[#522C81] dark:text-purple-400">
                  <MapPin size={24} aria-hidden="true" />
                </div>
                <div>
                  <p className="font-medium">{t("contactOfficesLabel")}</p>
                  <p className="text-slate-600 dark:text-slate-400">{t("contactOfficesValue")}</p>
                </div>
              </div>
            </div>
          </div>

          <div>
            <h2 className="text-2xl font-bold mb-6">{t("contactFormTitle")}</h2>
            <ContactForm correoSoporte={CORREO_SOPORTE} />
          </div>
        </div>
      </div>
      <Footer />
    </main>
  );
}
