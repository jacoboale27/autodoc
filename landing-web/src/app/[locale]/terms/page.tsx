import { useTranslations } from "next-intl";
import Header from "@/components/ui/Header";
import Footer from "@/components/ui/Footer";

export default function TermsPage() {
  const t = useTranslations();

  return (
    <main className="relative min-h-screen bg-slate-50 text-slate-900 dark:bg-[#0f172a] dark:text-white">
      <Header />
      <div className="pt-32 pb-24 max-w-4xl mx-auto px-6">
        <h1 className="text-4xl font-bold mb-8">Términos y Condiciones</h1>
        <div className="prose dark:prose-invert max-w-none">
          <p>Última actualización: 19 de Julio, 2026</p>
          <h2>1. Aceptación de los términos</h2>
          <p>
            Al acceder y usar la aplicación AutoDoc, usted acepta estar sujeto a estos términos y condiciones.
          </p>
          <h2>2. Uso del servicio</h2>
          <p>
            Usted acepta utilizar el servicio solo con fines lícitos y de una manera que no infrinja los derechos, 
            ni restrinja o inhiba el uso y disfrute de este servicio por parte de terceros.
          </p>
          <h2>3. Cuentas de usuario</h2>
          <p>
            Usted es responsable de salvaguardar la contraseña que utiliza para acceder al servicio y de 
            cualquier actividad o acción bajo su contraseña.
          </p>
          <h2>4. Terminación</h2>
          <p>
            Podemos terminar o suspender su cuenta inmediatamente, sin previo aviso o responsabilidad, 
            por cualquier motivo, incluyendo sin limitación si usted incumple los Términos.
          </p>
        </div>
      </div>
      <Footer />
    </main>
  );
}
