"use client";

import React, { createContext, useContext, useEffect, useState } from "react";
import en from "@/messages/en.json";
import ta from "@/messages/ta.json";
import hi from "@/messages/hi.json";

type Locale = "en" | "ta" | "hi";
type Messages = typeof en;

const messages: Record<Locale, Messages> = { en, ta, hi };

type LanguageContextType = {
  locale: Locale;
  setLocale: (l: Locale) => void;
  t: (key: string) => string;
};

const LanguageContext = createContext<LanguageContextType>({
  locale: "en",
  setLocale: () => {},
  t: (k) => k,
});

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>("en");

  useEffect(() => {
    const stored = localStorage.getItem("nn-locale") as Locale | null;
    if (stored && ["en", "ta", "hi"].includes(stored)) {
      setLocaleState(stored);
    }
  }, []);

  const setLocale = (l: Locale) => {
    setLocaleState(l);
    localStorage.setItem("nn-locale", l);
  };

  const t = (key: string): string => {
    const parts = key.split(".");
    let current: unknown = messages[locale];

    for (const part of parts) {
      if (typeof current !== "object" || current === null || !(part in current)) {
        return key;
      }
      current = (current as Record<string, unknown>)[part];
    }

    return typeof current === "string" ? current : key;
  };

  return (
    <LanguageContext.Provider value={{ locale, setLocale, t }}>
      {children}
    </LanguageContext.Provider>
  );
}

export const useLanguage = () => useContext(LanguageContext);
