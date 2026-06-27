"use client";

import { AnimatePresence, motion } from "framer-motion";
import Image from "next/image";
import { useState } from "react";
import { SectionTitle } from "./ui/SectionTitle";

const tabs = [
  {
    label: "Web Dashboard",
    img: "/mockups/web-pos.svg",
    bullets: ["Real-time transactions feed", "Branch-wise revenue charts", "Low-stock notifications"],
  },
  {
    label: "Mobile POS",
    img: "/mockups/mobile-pos.svg",
    bullets: ["Offline-first billing screen", "Camera barcode scan", "UPI QR generation"],
  },
  {
    label: "Reports",
    img: "/mockups/web-pos.svg",
    bullets: ["P&L statement by date range", "Top products by revenue", "Export to Excel / PDF"],
  },
  {
    label: "Inventory",
    img: "/mockups/web-pos.svg",
    bullets: ["Category-wise stock view", "Supplier purchase orders", "Auto reorder triggers"],
  },
];

export function DemoSection() {
  const [active, setActive] = useState(0);

  return (
    <section id="demo" className="section-wrap" aria-labelledby="demo-title">
      <div className="section-inner">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <SectionTitle
            title="The interface your team will love"
            subtitle="Designed for speed, clarity, and zero training time."
          />
        </motion.div>

        <div className="mt-10 flex flex-wrap justify-center gap-2">
          {tabs.map((t, i) => (
            <button
              key={t.label}
              type="button"
              onClick={() => setActive(i)}
              className={`rounded-full px-5 py-2 text-sm font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ctaGold/50 ${
                active === i
                  ? "bg-ctaGold text-navy"
                  : "border border-white/10 bg-white/5 text-silver hover:text-offWhite"
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className="relative mt-12">
          <AnimatePresence mode="wait">
            <motion.div
              key={active}
              initial={{ opacity: 0, scale: 0.97 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.97 }}
              transition={{ duration: 0.3 }}
              className="rounded-3xl border border-white/10 bg-white/5 p-4 backdrop-blur-xl"
            >
              <Image
                src={tabs[active].img}
                alt={`${tabs[active].label} screenshot`}
                width={1280}
                height={720}
                className="h-auto w-full rounded-2xl"
                sizes="(max-width: 1024px) 100vw, 1024px"
              />
            </motion.div>
          </AnimatePresence>

          <div className="mt-8 flex flex-wrap justify-center gap-4">
            {tabs[active].bullets.map((b) => (
              <span
                key={b}
                className="flex items-center gap-2 rounded-full border border-ctaGold/20 bg-ctaGold/5 px-4 py-2 text-sm text-silver"
              >
                <span className="h-1.5 w-1.5 rounded-full bg-ctaGold" />
                {b}
              </span>
            ))}
          </div>
        </div>
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
