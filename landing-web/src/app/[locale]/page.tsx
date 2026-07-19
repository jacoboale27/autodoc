import Header from "@/components/ui/Header";
import HeroSection from "@/components/ui/HeroSection";
import ValuePropSection from "@/components/ui/ValuePropSection";
import FeaturesGrid from "@/components/ui/FeaturesGrid";
import WorkshopsSection from "@/components/ui/WorkshopsSection";
import Footer from "@/components/ui/Footer";
import { setRequestLocale } from 'next-intl/server';

export default async function Home({
  params
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <main className="relative min-h-screen bg-slate-50 text-slate-900 dark:bg-[#0f172a] dark:text-white selection:bg-sky-500/30">
      <Header />
      
      <HeroSection />
      
      <div className="relative z-10 bg-[#0f172a]">
        <FeaturesGrid />
        <ValuePropSection />
        <WorkshopsSection />
        <Footer />
      </div>
    </main>
  );
}
