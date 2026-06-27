"use client";

import { Footer } from "@/components/Footer";
import { Navbar } from "@/components/Navbar";
import { GlassCard } from "@/components/ui/GlassCard";
import { StoreButton } from "@/components/ui/StoreButton";
import { useLanguage } from "@/context/LanguageContext";
import { trackEvent } from "@/lib/analytics";
import { motion } from "framer-motion";
import {
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  Download,
  LogIn,
  Settings,
  Smartphone,
} from "lucide-react";
import { MouseEvent, useState } from "react";

const installSteps = [
  { icon: Download, title: "Download the APK file", desc: "Tap the Download button above to save the APK to your Android device." },
  { icon: Settings, title: "Allow unknown sources", desc: "Open Settings → Security → enable 'Install from unknown sources' (one-time step)." },
  { icon: Smartphone, title: "Install the app", desc: "Open your Downloads folder and tap the .apk file to begin installation." },
  { icon: LogIn, title: "Login with your account", desc: "Open NammaNanban, enter your credentials, and you're ready to bill." },
];

const versions = [
  { version: "v2.0.1", date: "May 2025", notes: "Bug fixes & performance improvements, faster sync engine." },
  { version: "v2.0.0", date: "Apr 2025", notes: "Offline mode, UPI payments, redesigned dashboard, barcode scanner." },
  { version: "v1.9.0", date: "Feb 2025", notes: "Multi-branch support, branch-wise reports, stock transfer." },
];

const trustBadges = [
  { icon: CheckCircle2, label: "Virus-free ✓" },
  { icon: CheckCircle2, label: "No hidden permissions" },
  { icon: CheckCircle2, label: "Auto-updates via app" },
  { icon: CheckCircle2, label: "256-bit encrypted sync" },
];

type DownloadPageClientProps = {
  apkDownloadPath: string;
  apkFileName: string;
};

function VersionAccordion() {
  const [open, setOpen] = useState<number | null>(0);

  return (
    <div className="space-y-3">
      {versions.map((v, i) => (
        <div
          key={v.version}
          className="overflow-hidden rounded-2xl border border-white/10 bg-white/5 backdrop-blur-xl"
        >
          <button
            type="button"
            className="flex w-full items-center justify-between px-5 py-4 text-sm font-semibold text-offWhite transition hover:text-ctaGold focus-visible:outline-none"
            onClick={() => setOpen(open === i ? null : i)}
          >
            <span>{v.version} — {v.date}</span>
            {open === i ? <ChevronUp size={16} className="text-ctaGold" /> : <ChevronDown size={16} />}
          </button>
          {open === i && <p className="px-5 pb-4 text-sm text-silver">{v.notes}</p>}
        </div>
      ))}
    </div>
  );
}

export default function DownloadPageClient({ apkDownloadPath, apkFileName }: DownloadPageClientProps) {
  const { t } = useLanguage();
  const downloadLabel = t("download.cta");

  async function handleDownload(event: MouseEvent<HTMLAnchorElement>) {
    trackEvent("download_click", {
      cta_label: "download_page_apk",
      file_name: apkFileName,
    });

    event.preventDefault();

    try {
      const response = await fetch(apkDownloadPath);

      if (!response.ok) {
        throw new Error(`APK download failed with status ${response.status}`);
      }

      const blob = await response.blob();
      const objectUrl = window.URL.createObjectURL(blob);
      const link = document.createElement("a");

      link.href = objectUrl;
      link.download = apkFileName;
      link.click();
      window.URL.revokeObjectURL(objectUrl);
    } catch (error) {
      console.warn("APK download fallback triggered because the direct download request failed.", error);
      window.location.assign(apkDownloadPath);
    }
  }

  return (
    <>
      <Navbar />
      <main className="pt-20">
        <section className="section-wrap" aria-labelledby="download-title">
          <div className="section-inner text-center">
            <motion.div
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
            >
              <div className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-2xl bg-ctaGold/10 shadow-[0_0_40px_rgba(212,175,106,0.3)]">
                <Smartphone size={40} className="text-ctaGold" />
              </div>
              <h1 id="download-title" className="font-heading text-3xl font-bold text-offWhite sm:text-4xl lg:text-5xl">
                {t("download.title")}
              </h1>
              <p className="mx-auto mt-4 max-w-xl text-base text-silver">
                {t("download.subtitle")}
              </p>

              <div className="mt-8 flex flex-col items-center gap-4">
                <a
                  href={apkDownloadPath}
                  download={apkFileName}
                  onClick={handleDownload}
                  className="inline-flex items-center gap-3 rounded-xl bg-gold-gradient px-8 py-4 text-base font-bold text-navy shadow-halo transition hover:brightness-110 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ctaGold/50"
                  aria-label={downloadLabel}
                >
                  <Download size={20} />
                  {downloadLabel}
                </a>
                <p className="text-sm text-silver">
                  File: {apkFileName} · {t("download.androidMin")}
                </p>
                <p className="max-w-xl text-center text-sm text-silver">
                  Static deployment: replace the APK file inside <code className="font-mono">website/public/apk</code>, rebuild, and redeploy to publish a new APK.
                </p>
              </div>

            </motion.div>
          </div>
        </section>

        <section className="section-inner mb-12 flex flex-wrap justify-center gap-4 px-6 sm:px-10">
          <StoreButton store="google" href="https://play.google.com/store/apps/details?id=com.nammananban" />
          <StoreButton store="apple" comingSoon />
        </section>

        <section className="section-wrap pt-0">
          <div className="section-inner grid gap-8 lg:grid-cols-2">
            <GlassCard className="p-8">
              <h2 className="mb-6 font-heading text-xl font-bold text-offWhite">System Requirements</h2>
              <ul className="space-y-4">
                {[
                  { label: "Android version", value: "7.0 (Nougat) or higher" },
                  { label: "RAM", value: "2 GB minimum (4 GB recommended)" },
                  { label: "Storage", value: "100 MB free space" },
                  { label: "Internet", value: "Required for sync (offline billing works without it)" },
                ].map((req) => (
                  <li key={req.label} className="flex items-start gap-3">
                    <CheckCircle2 size={16} className="mt-0.5 shrink-0 text-ctaGold" />
                    <span>
                      <span className="text-sm font-semibold text-offWhite">{req.label}: </span>
                      <span className="text-sm text-silver">{req.value}</span>
                    </span>
                  </li>
                ))}
              </ul>
            </GlassCard>

            <div>
              <h2 className="mb-6 font-heading text-xl font-bold text-offWhite">How to Install</h2>
              <ol className="space-y-5">
                {installSteps.map((step, i) => (
                  <li key={step.title} className="flex gap-4">
                    <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-ctaGold/30 bg-ctaGold/10 font-bold text-ctaGold">
                      {i + 1}
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-offWhite">{step.title}</p>
                      <p className="mt-0.5 text-xs text-silver">{step.desc}</p>
                    </div>
                  </li>
                ))}
              </ol>
            </div>
          </div>
        </section>

        <section className="section-wrap pt-0">
          <div className="section-inner max-w-2xl">
            <h2 className="mb-6 font-heading text-xl font-bold text-offWhite">Version History</h2>
            <VersionAccordion />
          </div>
        </section>

        <section className="section-inner mb-16 px-6 sm:px-10">
          <div className="flex flex-wrap justify-center gap-4">
            {trustBadges.map((b) => (
              <div
                key={b.label}
                className="flex items-center gap-2 rounded-full border border-ctaGold/20 bg-ctaGold/5 px-5 py-2.5 text-sm font-medium text-silver"
              >
                <b.icon size={15} className="text-ctaGold" />
                {b.label}
              </div>
            ))}
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
