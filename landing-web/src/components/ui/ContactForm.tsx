"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { AlertCircle, CheckCircle2 } from "lucide-react";
import { enviarSolicitud } from "@/lib/solicitudes";

/**
 * Formulario de contacto de la landing.
 *
 * Sustituye a un `<form action="#">` que recargaba la pagina y no enviaba
 * nada: los tres estados que hay aqui —enviando, enviado, fallo— no existian,
 * asi que quien escribia no tenia forma de saber que su mensaje no habia
 * salido de la pantalla.
 *
 * Si el envio falla se ofrece el `mailto:` como salida, en vez de dejar a la
 * persona con un error y ningun camino.
 */
export default function ContactForm({ correoSoporte }: { correoSoporte: string }) {
  const t = useTranslations();

  const [nombre, setNombre] = useState("");
  const [correo, setCorreo] = useState("");
  const [mensaje, setMensaje] = useState("");
  // Campo trampa: oculto para las personas, tentador para un bot. El endpoint
  // responde exito sin guardar nada cuando llega relleno.
  const [sitioWeb, setSitioWeb] = useState("");

  const [enviando, setEnviando] = useState(false);
  const [enviado, setEnviado] = useState(false);
  const [error, setError] = useState("");

  const manejarEnvio = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (!nombre.trim() || !correo.trim() || !mensaje.trim()) {
      setError(t("contactErrorRequired"));
      return;
    }
    // Misma comprobacion laxa que el endpoint: aqui solo se adelanta el aviso
    // para no gastar un viaje de ida y vuelta.
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo.trim())) {
      setError(t("contactErrorEmail"));
      return;
    }

    setEnviando(true);
    const r = await enviarSolicitud("contacto", {
      nombre: nombre.trim(),
      correo: correo.trim(),
      mensaje: mensaje.trim(),
      sitio_web: sitioWeb,
    });
    setEnviando(false);

    if (r.ok) {
      setEnviado(true);
      return;
    }
    if (r.motivo === "limite") {
      setError(t("contactErrorRate"));
      return;
    }
    if (r.motivo === "invalido") {
      setError(t("contactErrorRequired"));
      return;
    }
    setError(t("contactErrorGeneric", { correo: correoSoporte }));
  };

  if (enviado) {
    return (
      <div
        className="text-center py-10 px-6 rounded-2xl border border-emerald-500/30 bg-emerald-500/5"
        role="status"
        data-testid="contacto-exito"
      >
        <CheckCircle2 className="w-14 h-14 text-emerald-500 mx-auto mb-4" aria-hidden="true" />
        <h3 className="text-xl font-bold mb-2">{t("contactSuccessTitle")}</h3>
        <p className="text-slate-600 dark:text-slate-300 mb-6">{t("contactSuccessDesc")}</p>
        <button
          type="button"
          onClick={() => {
            setEnviado(false);
            setNombre("");
            setCorreo("");
            setMensaje("");
          }}
          className="text-[#522C81] dark:text-purple-300 font-semibold underline underline-offset-4"
        >
          {t("contactSendAnother")}
        </button>
      </div>
    );
  }

  return (
    <form className="space-y-4" onSubmit={manejarEnvio} noValidate data-testid="contacto-form">
      {error && (
        <div
          className="flex items-start gap-2 text-rose-600 dark:text-rose-400 bg-rose-500/10 border border-rose-500/20 p-4 rounded-xl text-sm"
          role="alert"
          data-testid="contacto-error"
        >
          <AlertCircle className="w-5 h-5 flex-shrink-0" aria-hidden="true" />
          <span>{error}</span>
        </div>
      )}

      <div>
        <label htmlFor="contacto-nombre" className="block text-sm font-medium mb-1">
          {t("contactName")}
        </label>
        <input
          type="text"
          id="contacto-nombre"
          name="nombre"
          required
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          placeholder={t("contactNamePlaceholder")}
          className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-[#522C81] outline-none"
        />
      </div>

      <div>
        <label htmlFor="contacto-correo" className="block text-sm font-medium mb-1">
          {t("contactEmail")}
        </label>
        <input
          type="email"
          id="contacto-correo"
          name="correo"
          required
          value={correo}
          onChange={(e) => setCorreo(e.target.value)}
          placeholder={t("contactEmailPlaceholder")}
          className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-[#522C81] outline-none"
        />
      </div>

      <div>
        <label htmlFor="contacto-mensaje" className="block text-sm font-medium mb-1">
          {t("contactMessage")}
        </label>
        <textarea
          id="contacto-mensaje"
          name="mensaje"
          rows={4}
          required
          value={mensaje}
          onChange={(e) => setMensaje(e.target.value)}
          placeholder={t("contactMessagePlaceholder")}
          className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 focus:ring-2 focus:ring-[#522C81] outline-none resize-none"
        />
      </div>

      {/* Honeypot. `aria-hidden` + tabIndex -1 lo sacan del recorrido de
          teclado y del lector de pantalla; se posiciona fuera de la vista en
          lugar de con display:none porque hay bots que ignoran los campos
          ocultos por CSS. */}
      <div className="absolute left-[-9999px] top-auto w-px h-px overflow-hidden" aria-hidden="true">
        <label htmlFor="contacto-sitio-web">No rellenar</label>
        <input
          type="text"
          id="contacto-sitio-web"
          name="sitio_web"
          tabIndex={-1}
          autoComplete="off"
          value={sitioWeb}
          onChange={(e) => setSitioWeb(e.target.value)}
        />
      </div>

      <button
        type="submit"
        disabled={enviando}
        className="w-full bg-[#522C81] text-white font-bold py-3 px-4 rounded-lg hover:bg-[#3d2062] transition-colors disabled:opacity-60"
      >
        {enviando ? t("contactSubmitting") : t("contactSubmit")}
      </button>

      <p className="text-xs text-center text-slate-500 dark:text-slate-400">
        {t("contactPreferEmail")}{" "}
        <a
          href={`mailto:${correoSoporte}`}
          className="underline underline-offset-2 hover:text-[#522C81] dark:hover:text-purple-300"
        >
          {correoSoporte}
        </a>
      </p>
    </form>
  );
}
