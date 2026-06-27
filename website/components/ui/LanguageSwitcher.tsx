"use client";

import { useLanguage } from "@/context/LanguageContext";
import { ChevronDown } from "lucide-react";
import { useEffect, useRef, useState } from "react";

const LOCALES = [
  { code: "en" as const, label: "EN", native: "English", flag: "🇺🇸" },
  { code: "ta" as const, label: "தமிழ்", native: "Tamil", flag: "🇮🇳" },
  { code: "hi" as const, label: "हिंदी", native: "Hindi", flag: "🇮🇳" },
];

export function LanguageSwitcher() {
  const { locale, setLocale } = useLanguage();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  const current = LOCALES.find((l) => l.code === locale) ?? LOCALES[0];

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };

    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  return (
    <div className="relative" ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((p) => !p)}
        className="flex items-center gap-1.5 rounded-lg border border-white/10 px-3 py-1.5 text-xs font-medium text-silver transition hover:text-offWhite focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ctaGold/50"
        aria-label="Switch language"
      >
        <span>{current.flag}</span>
        <span>{current.label}</span>
        <ChevronDown size={12} />
      </button>
      {open && (
        <div className="absolute right-0 top-full z-50 mt-1 w-36 rounded-xl border border-white/10 bg-navy/95 py-1 shadow-xl backdrop-blur-xl">
          {LOCALES.map((l) => (
            <button
              key={l.code}
              type="button"
              onClick={() => {
                setLocale(l.code);
                setOpen(false);
              }}
              className={`flex w-full items-center gap-2 px-3 py-2 text-xs transition hover:bg-white/10 ${
                locale === l.code ? "text-ctaGold" : "text-silver"
              }`}
            >
              <span>{l.flag}</span>
              <span>{l.native}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
