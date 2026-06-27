import { useMemo } from 'react'
import { STORAGE_KEYS } from '../api/client'
import { translations, type TranslationLanguage } from '../i18n/translations'
import type { LanguageSettings } from '../types'

const defaultLanguage: LanguageSettings = {
  language: 'en',
  currencySymbol: '₹',
  dateFormat: 'DD/MM/YYYY',
}

export default function useTranslation() {
  return useMemo(() => {
    let language: TranslationLanguage = 'en'
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.language)
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<LanguageSettings>
        const validLangs: TranslationLanguage[] = ['en', 'ta', 'te', 'hi', 'kn', 'ml']
        if (validLangs.includes(parsed.language as TranslationLanguage)) {
          language = parsed.language as TranslationLanguage
        }
      }
    } catch {
      language = defaultLanguage.language
    }

    return {
      language,
      t: translations[language],
    }
  }, [])
}
