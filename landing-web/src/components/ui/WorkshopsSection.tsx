"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useEffect, useState } from "react";
import { MapPin, Star } from "lucide-react";

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
              // Only include approved workshops if 'estado' field exists and is 'aprobado'
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
          
          setWorkshops(parsed.slice(0, 3)); // Show top 3
        }
      } catch (e) {
        console.error("Error fetching workshops", e);
      } finally {
        setLoading(false);
      }
    }

    fetchWorkshops();
  }, []);

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

        {/* CTA Section */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8 }}
          className="mx-auto max-w-3xl text-center bg-slate-50 dark:bg-slate-800/50 rounded-3xl p-12 border border-slate-200 dark:border-slate-800"
        >
          <h2 className="text-2xl font-extrabold tracking-tight text-slate-900 dark:text-white sm:text-3xl mb-4">
            ¿Eres un taller mecánico?
          </h2>
          <p className="text-lg text-slate-600 dark:text-slate-300 mb-8">
            Únete a AutoDoc para gestionar tu taller de manera eficiente y conectar con más clientes. Digitaliza tus servicios y mejora tu reputación.
          </p>
          <div className="flex justify-center gap-4">
            <Link href="https://autodoc-6ef5a.web.app/login" passHref target="_blank">
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="rounded-xl bg-[#522C81] px-8 py-4 font-bold text-white shadow-lg transition-all hover:bg-[#3d2062] hover:shadow-xl"
              >
                Regístrate ahora
              </motion.button>
            </Link>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
