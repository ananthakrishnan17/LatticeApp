"use client";

import { useLanguage } from "@/context/LanguageContext";
import { motion } from "framer-motion";
import { Search } from "lucide-react";
import { useMemo, useState } from "react";
import { Accordion } from "./ui/Accordion";
import { SectionTitle } from "./ui/SectionTitle";

const faqs = [
  { question: "Is the APK free to download?", answer: "Yes! The NammaNanban Mobile POS APK is completely free to download and install. You only pay for the subscription plan which unlocks cloud sync, multi-device, and advanced features." },
  { question: "Does the mobile app work without internet?", answer: "Absolutely. The mobile app is built with an offline-first architecture. You can create bills, manage inventory, and process cash payments without any internet connection. Data syncs automatically when connectivity is restored." },
  { question: "How do I update to a new version?", answer: "In-app update notifications are shown automatically. You can also download the latest APK from our website at any time, or update through Google Play Store once the listing is live." },
  { question: "Is my data safe and backed up?", answer: "Yes. All data is encrypted with 256-bit AES encryption and automatically backed up to our secure cloud infrastructure every hour. You can also manually trigger a sync at any time." },
  { question: "Can I use both Web POS and Mobile POS together?", answer: "Yes! Both platforms sync in real-time. A sale made on the mobile app instantly reflects on the web dashboard and vice versa. Multiple devices can operate simultaneously." },
  { question: "What payment methods does it support?", answer: "NammaNanban supports Cash, UPI (via QR code), Credit/Debit cards (via external terminal), Cheque, and custom payment methods. More integrations are being added regularly." },
  { question: "Does it support GST billing?", answer: "Yes. GST billing is fully supported with auto-calculation of CGST, SGST, and IGST based on the product HSN code and customer state. GST reports are available in PDF and Excel formats." },
  { question: "How many devices can I connect?", answer: "The Starter plan supports up to 2 devices, Professional supports up to 10 devices, and Enterprise supports unlimited devices. You can manage all devices from the central dashboard." },
  { question: "Is there a free trial?", answer: "Yes! We offer a 14-day free trial of the Professional plan with no credit card required. You get access to all features so you can experience the full power of NammaNanban before committing." },
  { question: "What happens after the trial ends?", answer: "After your 14-day trial, you can choose a plan that fits your business. Your data is always safe and accessible. If you choose not to subscribe, your account moves to the free tier with limited features." },
  { question: "Do you offer onboarding support?", answer: "Yes! Every new account gets a dedicated onboarding call with our team. We help you set up your products, configure tax settings, and train your staff. Premium plans include priority support." },
  { question: "Can I export my sales data?", answer: "Yes. You can export all sales data, inventory reports, customer lists, and financial statements to Excel, CSV, or PDF format at any time from the Back Office dashboard." },
];

export function FAQSection() {
  const { t } = useLanguage();
  const [search, setSearch] = useState("");

  const filtered = useMemo(
    () =>
      faqs.filter(
        (f) =>
          f.question.toLowerCase().includes(search.toLowerCase()) ||
          f.answer.toLowerCase().includes(search.toLowerCase()),
      ),
    [search],
  );

  const half = Math.ceil(filtered.length / 2);
  const left = filtered.slice(0, half);
  const right = filtered.slice(half);

  return (
    <section id="faq" className="section-wrap" aria-labelledby="faq-title">
      <div className="section-inner">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <SectionTitle title={t("faq.title")} />
        </motion.div>

        <div className="mx-auto mt-10 max-w-xl">
          <div className="flex items-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 backdrop-blur-xl focus-within:border-ctaGold/50">
            <Search size={18} className="shrink-0 text-silver" />
            <input
              type="search"
              placeholder={t("faq.searchPlaceholder")}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full bg-transparent text-sm text-offWhite placeholder-silver/50 focus:outline-none"
              aria-label="Search frequently asked questions"
            />
          </div>
        </div>

        {filtered.length === 0 ? (
          <p className="mt-10 text-center text-sm text-silver">No matching questions found.</p>
        ) : (
          <div className="mt-10 grid gap-6 lg:grid-cols-2">
            <Accordion items={left} />
            <Accordion items={right} />
          </div>
        )}
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
