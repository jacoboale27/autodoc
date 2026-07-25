"use client";

import { motion } from "framer-motion";
import { useTranslations } from "next-intl";
import { useEffect, useState } from "react";
import { MapPin, Star, ShieldCheck, Calendar, FileSpreadsheet, CheckCircle2, AlertCircle } from "lucide-react";

interface Workshop {
  id: string;
  name: string;
  specialty: string;
  location: string;
  rating: number;
}

export default function WorkshopsSection() {
  const t = useTranslations();
  const [workshops, setWorkshops] = useState<Workshop[]>([]);
  const [loading, setLoading] = useState(true);

  // Form State
  const [formName, setFormName] = useState("");
  const [formRep, setFormRep] = useState("");
  const [formEmail, setFormEmail] = useState("");
  const [formPhone, setFormPhone] = useState("");
  const [formLocation, setFormLocation] = useState("");
  const [formSpecialty, setFormSpecialty] = useState("Mecánica General");

  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");

  useEffect(() => {
    async function fetchWorkshops() {
      try {
        const response = await fetch(
          "https://firestore.googleapis.com/v1/projects/autodoc-6ef5a/databases/(default)/documents/talleres"
        );
        const data = await response.json();
        
        if (data.documents) {
          const parsed = data.documents
            .map((doc: any) => {
              const fields = doc.fields;
              const id = doc.name.split("/").pop();
              const estado = fields?.estado?.stringValue || 'aprobado';
              if (estado !== 'aprobado') return null;

              return {
                id,
                name: fields?.nombre?.stringValue || "Taller Mecánico",
                specialty: fields?.especialidad?.stringValue || "Mecánica General",
                location: fields?.ubicacion_municipio?.stringValue || "Ciudad",
                rating: fields?.calificacion_promedio?.doubleValue || fields?.calificacion_promedio?.integerValue || 5.0,
              };
            })
            .filter(Boolean);
          
          setWorkshops(parsed.slice(0, 3));
        }
      } catch (e) {
        console.error("Error fetching workshops", e);
      } finally {
        setLoading(false);
      }
    }

    fetchWorkshops();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage("");

    if (!formName.trim() || !formEmail.trim() || !formPhone.trim() || !formLocation.trim()) {
      setErrorMessage("Por favor completa todos los campos requeridos.");
      return;
    }

    setSubmitting(true);

    try {
      const payload = {
        fields: {
          nombre: { stringValue: formName.trim() },
          representante: { stringValue: formRep.trim() },
          correo: { stringValue: formEmail.trim() },
          telefono: { stringValue: formPhone.trim() },
          ubicacion_municipio: { stringValue: formLocation.trim() },
          especialidad: { stringValue: formSpecialty },
          estado: { stringValue: "pendiente" },
          origen: { stringValue: "landing_web" },
          fecha_solicitud: { timestampValue: new Date().toISOString() },
        },
      };

      const res = await fetch(
        "https://firestore.googleapis.com/v1/projects/autodoc-6ef5a/databases/(default)/documents/talleres",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }
      );

      if (!res.ok) {
        throw new Error("Error al guardar en Firestore");
      }

      setSubmitted(true);
    } catch (err) {
      console.error("Error submitting workshop application", err);
      setErrorMessage("Ocurrió un error al enviar la solicitud. Intenta nuevamente.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <section id="workshops" className="relative z-10 py-24 bg-white dark:bg-slate-900 border-t border-slate-200 dark:border-slate-800">
      <div className="mx-auto max-w-7xl px-6 lg:px-8">
        
        {/* Dynamic Workshops Grid */}
        <div className="mb-20">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-center mb-12"
          >
            <h2 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white sm:text-4xl mb-4">
              Talleres Destacados
            </h2>
            <p className="text-lg text-slate-600 dark:text-slate-300">
              Encuentra los mejores talleres certificados cerca de ti.
            </p>
          </motion.div>

          {loading ? (
            <div className="flex justify-center items-center h-32">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#522C81]"></div>
            </div>
          ) : workshops.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
              {workshops.map((workshop, idx) => (
                <motion.div
                  key={workshop.id}
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: idx * 0.1 }}
                  className="bg-slate-50 dark:bg-slate-800 rounded-2xl p-6 border border-slate-200 dark:border-slate-700 shadow-sm hover:shadow-md transition-shadow"
                >
                  <h3 className="text-xl font-bold text-slate-900 dark:text-white mb-2">{workshop.name}</h3>
                  <p className="text-sm text-slate-500 dark:text-slate-400 mb-4 font-medium">{workshop.specialty}</p>
                  
                  <div className="flex items-center justify-between text-sm">
                    <div className="flex items-center text-slate-600 dark:text-slate-300">
                      <MapPin className="w-4 h-4 mr-1 text-[#522C81] dark:text-purple-400" />
                      {workshop.location}
                    </div>
                    <div className="flex items-center text-amber-500 font-bold">
                      <Star className="w-4 h-4 mr-1 fill-current" />
                      {workshop.rating.toFixed(1)}
                    </div>
                  </div>
                </motion.div>
              ))}
            </div>
          ) : (
            <p className="text-center text-slate-500">No hay talleres disponibles en este momento.</p>
          )}
        </div>

        {/* Benefits Grid for Workshops */}
        <div className="mb-20">
          <div className="text-center max-w-3xl mx-auto mb-12">
            <h2 className="text-3xl font-extrabold text-slate-900 dark:text-white sm:text-4xl mb-4">
              {t("workshopTitle")}
            </h2>
            <p className="text-lg text-slate-600 dark:text-slate-300">
              {t("workshopSubtitle")}
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="bg-slate-50 dark:bg-slate-800/80 p-8 rounded-2xl border border-slate-200 dark:border-slate-700">
              <div className="w-12 h-12 rounded-xl bg-purple-500/10 text-purple-500 flex items-center justify-center mb-6">
                <ShieldCheck className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold text-slate-900 dark:text-white mb-2">{t("benefitVerified")}</h3>
              <p className="text-slate-600 dark:text-slate-400 text-sm">{t("benefitVerifiedDesc")}</p>
            </div>

            <div className="bg-slate-50 dark:bg-slate-800/80 p-8 rounded-2xl border border-slate-200 dark:border-slate-700">
              <div className="w-12 h-12 rounded-xl bg-sky-500/10 text-sky-500 flex items-center justify-center mb-6">
                <Calendar className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold text-slate-900 dark:text-white mb-2">{t("benefitAppointments")}</h3>
              <p className="text-slate-600 dark:text-slate-400 text-sm">{t("benefitAppointmentsDesc")}</p>
            </div>

            <div className="bg-slate-50 dark:bg-slate-800/80 p-8 rounded-2xl border border-slate-200 dark:border-slate-700">
              <div className="w-12 h-12 rounded-xl bg-emerald-500/10 text-emerald-500 flex items-center justify-center mb-6">
                <FileSpreadsheet className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold text-slate-900 dark:text-white mb-2">{t("benefitHistory")}</h3>
              <p className="text-slate-600 dark:text-slate-400 text-sm">{t("benefitHistoryDesc")}</p>
            </div>
          </div>
        </div>

        {/* Affiliation Registration Form Section */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8 }}
          className="mx-auto max-w-3xl bg-slate-50 dark:bg-slate-800/60 rounded-3xl p-8 sm:p-12 border border-slate-200 dark:border-slate-700 shadow-xl"
        >
          <div className="text-center mb-8">
            <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white sm:text-3xl mb-2">
              {t("formTitle")}
            </h3>
            <p className="text-slate-600 dark:text-slate-300 text-sm">
              Completa el formulario y un administrador validará tu información para otorgarte el sello de Taller Verificado.
            </p>
          </div>

          {submitted ? (
            <div className="text-center py-8">
              <CheckCircle2 className="w-16 h-16 text-emerald-500 mx-auto mb-4" />
              <h4 className="text-2xl font-bold text-slate-900 dark:text-white mb-2">{t("formSuccessTitle")}</h4>
              <p className="text-slate-600 dark:text-slate-300">{t("formSuccessDesc")}</p>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-6">
              {errorMessage && (
                <div className="flex items-center space-x-2 text-rose-500 bg-rose-500/10 border border-rose-500/20 p-4 rounded-xl text-sm">
                  <AlertCircle className="w-5 h-5 flex-shrink-0" />
                  <span>{errorMessage}</span>
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
                    {t("formWorkshopName")} *
                  </label>
                  <input
                    type="text"
                    required
                    value={formName}
                    onChange={(e) => setFormName(e.target.value)}
                    placeholder="e.g. AutoFix San Salvador"
                    className="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#522C81]"
                  />
                </div>

                <div>
                  <label className="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
                    {t("formRepName")}
                  </label>
                  <input
                    type="text"
                    value={formRep}
                    onChange={(e) => setFormRep(e.target.value)}
                    placeholder="e.g. Ing. Roberto Gómez"
                    className="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#522C81]"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
                    {t("formEmail")} *
                  </label>
                  <input
                    type="email"
                    required
                    value={formEmail}
                    onChange={(e) => setFormEmail(e.target.value)}
                    placeholder="contacto@taller.com"
                    className="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#522C81]"
                  />
                </div>

                <div>
                  <label className="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
                    {t("formPhone")} *
                  </label>
                  <input
                    type="tel"
                    required
                    value={formPhone}
                    onChange={(e) => setFormPhone(e.target.value)}
                    placeholder="e.g. +503 7777-8888"
                    className="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#522C81]"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
                    {t("formLocation")} *
                  </label>
                  <input
                    type="text"
                    required
                    value={formLocation}
                    onChange={(e) => setFormLocation(e.target.value)}
                    placeholder="San Salvador"
                    className="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#522C81]"
                  />
                </div>

                <div>
                  <label className="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
                    {t("formSpecialty")}
                  </label>
                  <select
                    value={formSpecialty}
                    onChange={(e) => setFormSpecialty(e.target.value)}
                    className="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#522C81]"
                  >
                    <option value="Mecánica General">Mecánica General</option>
                    <option value="Motor y Transmisión">Motor y Transmisión</option>
                    <option value="Frenos y Suspensión">Frenos y Suspensión</option>
                    <option value="Sistema Eléctrico">Sistema Eléctrico</option>
                    <option value="Enderezado y Pintura">Enderezado y Pintura</option>
                  </select>
                </div>
              </div>

              <button
                type="submit"
                disabled={submitting}
                className="w-full py-4 rounded-xl bg-[#522C81] hover:bg-[#3d2062] text-white font-bold text-lg shadow-lg transition-all disabled:opacity-50"
              >
                {submitting ? t("formSubmitting") : t("formSubmit")}
              </button>
            </form>
          )}
        </motion.div>
      </div>
    </section>
  );
}
