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
  
  return {
    title: {
      template: '%s | AutoDoc',
      default: isEn ? 'AutoDoc - Your Smart Virtual Garage' : 'AutoDoc - Tu Garaje Virtual Inteligente',
    },
    description: isEn 
      ? 'Manage your vehicle documents, maintenance history, and connect with certified workshops.' 
      : 'Gestiona tus documentos vehiculares, historial de mantenimiento y conecta con talleres certificados.',
    openGraph: {
      type: 'website',
      locale: isEn ? 'en_US' : 'es_ES',
      url: 'https://autodoc-6ef5a.web.app',
      title: 'AutoDoc',
      description: isEn 
        ? 'Your Smart Virtual Garage' 
        : 'Tu Garaje Virtual Inteligente',
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

  return (
    <html
      lang={locale}
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
      suppressHydrationWarning
    >
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
