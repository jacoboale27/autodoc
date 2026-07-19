import { useTranslations } from "next-intl";
import Header from "@/components/ui/Header";
import Footer from "@/components/ui/Footer";

export default function PrivacyPage() {
  const t = useTranslations();

  return (
    <main className="relative min-h-screen bg-slate-50 text-slate-900 dark:bg-[#0f172a] dark:text-white">
      <Header />
      <div className="pt-32 pb-24 max-w-4xl mx-auto px-6">
        <h1 className="text-4xl font-bold mb-8">Política de Privacidad</h1>
        <div className="prose dark:prose-invert max-w-none">
          <p>Última actualización: 19 de Julio, 2026</p>
          <h2>1. Información que recopilamos</h2>
          <p>
            Recopilamos información personal que usted nos proporciona al registrarse en nuestra plataforma, 
            como su nombre, correo electrónico y datos de sus vehículos.
          </p>
          <h2>2. Uso de la información</h2>
          <p>
            Utilizamos su información para proveer, mantener y mejorar nuestros servicios, procesar sus solicitudes, 
            enviar notificaciones relacionadas con sus mantenimientos y comunicarnos con usted.
          </p>
          <h2>3. Compartir información</h2>
          <p>
            No vendemos ni compartimos su información personal con terceros, excepto cuando sea necesario 
            para proveer el servicio (ej. compartir datos básicos con un taller cuando solicita una cotización).
          </p>
          <h2>4. Seguridad</h2>
          <p>
            Tomamos medidas razonables para ayudar a proteger la información personal contra pérdida, 
            robo, uso indebido, acceso no autorizado, divulgación, alteración y destrucción.
          </p>
        </div>
      </div>
      <Footer />
    </main>
  );
}
