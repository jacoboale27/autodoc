import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "../globals.css";
import { NextIntlClientProvider } from "next-intl";
import { getMessages, setRequestLocale } from "next-intl/server";
import { notFound } from "next/navigation";
import { routing } from "@/i18n/routing";
import { ThemeProvider } from "@/components/ThemeProvider";
import { Analytics } from "@vercel/analytics/react";

export const dynamicParams = false;

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export async function generateMetadata({
  params
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const isEn = locale === 'en';
  const baseUrl = 'https://autodoc-landing-6ef5a.web.app';
  
  return {
    metadataBase: new URL(baseUrl),
    title: {
      template: '%s | AutoDoc',
      default: isEn ? 'AutoDoc - Your Smart Virtual Garage & Vehicle History' : 'AutoDoc - Tu Garaje Virtual Inteligente e Historial Vehicular',
    },
    description: isEn 
      ? 'Manage your vehicle documents, smart SOAT alerts, maintenance history, and connect with certified workshops.' 
      : 'Gestiona tus documentos vehiculares, alertas inteligentes de SOAT, historial de mantenimiento y conecta con talleres certificados.',
    keywords: isEn
      ? ['AutoDoc', 'Virtual Garage', 'Vehicle Maintenance', 'SOAT Alert', 'Auto Workshop', 'Car History']
      : ['AutoDoc', 'Garaje Virtual', 'Mantenimiento Vehicular', 'Alerta SOAT', 'Taller Mecánico', 'Historial Automotriz'],
    alternates: {
      canonical: `${baseUrl}/${locale}`,
      languages: {
        'es': `${baseUrl}/es`,
        'en': `${baseUrl}/en`,
        'x-default': `${baseUrl}/es`,
      },
    },
    openGraph: {
      type: 'website',
      locale: isEn ? 'en_US' : 'es_ES',
      url: `${baseUrl}/${locale}`,
      title: 'AutoDoc - Smart Virtual Garage',
      description: isEn 
        ? 'Your Smart Virtual Garage and Certified Maintenance Record.' 
        : 'Tu Garaje Virtual Inteligente e Historial de Mantenimiento Certificado.',
      siteName: 'AutoDoc',
    },
    twitter: {
      card: 'summary_large_image',
      title: 'AutoDoc',
      description: isEn ? 'Your Smart Virtual Garage' : 'Tu Garaje Virtual Inteligente',
    }
  };
}

export default async function RootLayout({
  children,
  params
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!routing.locales.includes(locale as any)) {
    notFound();
  }
  
  setRequestLocale(locale);

  const messages = await getMessages();

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    'name': 'AutoDoc',
    'applicationCategory': 'UtilitiesApplication',
    'operatingSystem': 'Web, Android, iOS',
    'offers': {
      '@type': 'Offer',
      'price': '0',
      'priceCurrency': 'USD'
    },
    'description': locale === 'en'
      ? 'AutoDoc is a virtual garage platform that centralizes vehicle documents, maintenance history, SOAT alerts, and connects car owners with verified workshops.'
      : 'AutoDoc es una plataforma de garaje virtual que centraliza documentos de vehículos, historial de mantenimiento, alertas de SOAT y conecta propietarios con talleres verificados.',
    'url': `https://autodoc-landing-6ef5a.web.app/${locale}`,
  };

  return (
    <html
      lang={locale}
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-slate-50 text-slate-900 dark:bg-[#0f172a] dark:text-white min-h-screen`}
      >
        <NextIntlClientProvider messages={messages}>
          <ThemeProvider
            attribute="class"
            defaultTheme="system"
            enableSystem
            disableTransitionOnChange
          >
            {children}
          </ThemeProvider>
        </NextIntlClientProvider>
        <Analytics />
      </body>
    </html>
  );
}
