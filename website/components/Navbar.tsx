"use client";

import { useLanguage } from "@/context/LanguageContext";
import { trackEvent } from "@/lib/analytics";
import { AnimatePresence, motion } from "framer-motion";
import { Download, Menu, X } from "lucide-react";
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { Button } from "./ui/Button";
import { LanguageSwitcher } from "./ui/LanguageSwitcher";

export function Navbar() {
  const { t } = useLanguage();
  const [isOpen, setIsOpen] = useState(false);
  const [isScrolled, setIsScrolled] = useState(false);

  const links = useMemo(
    () => [
      { label: t("nav.features"), href: "#features" },
      { label: t("nav.demo"), href: "#demo" },
      { label: t("nav.pricing"), href: "#pricing" },
      { label: t("nav.download"), href: "/download" },
      { label: t("nav.faq"), href: "#faq" },
    ],
    [t],
  );

  useEffect(() => {
    const onScroll = () => setIsScrolled(window.scrollY > 16);
    onScroll();
    window.addEventListener("scroll", onScroll);
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-all duration-300 ${
        isScrolled
          ? "border-b border-ctaGold/20 bg-navy/80 backdrop-blur-xl"
          : "border-b border-transparent bg-transparent"
      }`}
    >
      <nav
        className="section-inner flex h-20 items-center justify-between px-6 sm:px-10"
        aria-label="Primary"
      >
        <Link href="/" className="font-heading text-xl font-semibold text-offWhite">
          NammaNanban
        </Link>

        <ul className="hidden items-center gap-7 lg:flex">
          {links.map((link) => (
            <li key={link.label}>
              <Link
                href={link.href}
                className="text-sm text-silver transition hover:text-offWhite focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ctaGold/50"
              >
                {link.label}
              </Link>
            </li>
          ))}
        </ul>

        <div className="hidden items-center gap-3 lg:flex">
          <LanguageSwitcher />
          <Link
            href="/download"
            onClick={() => trackEvent("download_click", { cta_label: "navbar_download_apk" })}
            className="inline-flex items-center gap-2 rounded-xl border border-white/20 bg-white/5 px-4 py-2 text-sm font-semibold text-offWhite transition hover:bg-white/10"
            aria-label={t("nav.downloadApk")}
          >
            <Download size={14} />
            {t("nav.downloadApk")}
          </Link>
          <Button href="#contact" ariaLabel={t("nav.startTrial")} analyticsEvent="cta_click" analyticsLabel="navbar_start_trial">
            {t("nav.startTrial")}
          </Button>
        </div>

        <button
          type="button"
          className="rounded-lg border border-highlight/40 p-2 text-offWhite lg:hidden"
          onClick={() => setIsOpen((prev) => !prev)}
          aria-label="Toggle navigation menu"
          aria-expanded={isOpen}
        >
          {isOpen ? <X size={20} /> : <Menu size={20} />}
        </button>
      </nav>

      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ x: "100%" }}
            animate={{ x: 0 }}
            exit={{ x: "100%" }}
            transition={{ duration: 0.25, ease: "easeOut" }}
            className="fixed right-0 top-20 h-[calc(100vh-5rem)] w-72 border-l border-highlight/20 bg-deepNavy/95 p-6 backdrop-blur-xl lg:hidden"
          >
            <ul className="space-y-5">
              {links.map((link) => (
                <li key={link.label}>
                  <Link
                    href={link.href}
                    className="block text-sm text-silver transition hover:text-offWhite"
                    onClick={() => setIsOpen(false)}
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
            <div className="mt-6 space-y-3">
              <LanguageSwitcher />
              <Link
                href="/download"
                className="inline-flex w-full items-center justify-center gap-2 rounded-xl border border-white/20 bg-white/5 px-4 py-2 text-sm font-semibold text-offWhite transition hover:bg-white/10"
                onClick={() => {
                  setIsOpen(false);
                  trackEvent("download_click", { cta_label: "mobile_navbar_download_apk" });
                }}
              >
                <Download size={14} />
                {t("nav.downloadApk")}
              </Link>
              <Button
                href="#contact"
                ariaLabel={t("nav.startTrial")}
                analyticsEvent="cta_click"
                analyticsLabel="mobile_navbar_start_trial"
                onClick={() => setIsOpen(false)}
              >
                {t("nav.startTrial")}
              </Button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  );
}
