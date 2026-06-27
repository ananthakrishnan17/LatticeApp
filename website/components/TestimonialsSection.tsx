"use client";

import { motion } from "framer-motion";
import { Star } from "lucide-react";
import { SectionTitle } from "./ui/SectionTitle";

const testimonials = [
  {
    name: "Rajesh Kumar",
    city: "Chennai",
    type: "Retail",
    stars: 5,
    quote: "NammaNanban cut our billing time by 60%. The offline mode saved us during a 2-hour power cut — customers never even noticed.",
    avatar: "RK",
  },
  {
    name: "Priya Venkat",
    city: "Coimbatore",
    type: "Restaurant",
    stars: 5,
    quote: "KOT management and table billing are exactly what we needed. Setup took 15 minutes and our staff learned it in a day.",
    avatar: "PV",
  },
  {
    name: "Mohammed Farhan",
    city: "Hyderabad",
    type: "Pharmacy",
    stars: 5,
    quote: "GST automation and expiry tracking are game-changers. Worth every rupee — ROI in the first month.",
    avatar: "MF",
  },
  {
    name: "Anita Sharma",
    city: "Mumbai",
    type: "Wholesale",
    stars: 5,
    quote: "Multi-branch dashboard is excellent. I manage 3 stores from my phone now. The reports are detailed and easy to understand.",
    avatar: "AS",
  },
  {
    name: "Suresh Babu",
    city: "Bengaluru",
    type: "Electronics",
    stars: 5,
    quote: "Barcode scanner integration works seamlessly. Inventory is always accurate. Customer support team is incredibly responsive.",
    avatar: "SB",
  },
  {
    name: "Deepa Nair",
    city: "Kochi",
    type: "Boutique",
    stars: 4,
    quote: "Beautiful interface that our staff loves. WhatsApp receipts are a hit with customers. A few edge cases but support fixed them fast.",
    avatar: "DN",
  },
];

function Stars({ count }: { count: number }) {
  return (
    <div className="flex gap-0.5">
      {Array.from({ length: 5 }).map((_, i) => (
        <Star
          key={i}
          size={14}
          className={i < count ? "fill-ctaGold text-ctaGold" : "fill-white/10 text-white/10"}
        />
      ))}
    </div>
  );
}

export function TestimonialsSection() {
  return (
    <section id="testimonials" className="section-wrap" aria-labelledby="testimonials-title">
      <div className="section-inner">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="mb-14 flex flex-wrap justify-center gap-6 sm:gap-12"
        >
          {[
            { value: "4.9★", label: "average" },
            { value: "5,000+", label: "businesses" },
            { value: "50+", label: "cities" },
          ].map((stat) => (
            <div key={stat.label} className="text-center">
              <p className="font-heading text-2xl font-bold text-ctaGold">{stat.value}</p>
              <p className="text-sm text-silver">{stat.label}</p>
            </div>
          ))}
        </motion.div>

        <SectionTitle
          title="Loved by businesses across India"
          subtitle="Real stories from real business owners."
        />

        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {testimonials.map((t, i) => (
            <motion.div
              key={t.name}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: i * 0.07 }}
              className="flex flex-col rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl transition hover:scale-[1.02]"
            >
              <Stars count={t.stars} />
              <p className="mt-4 flex-1 text-sm leading-relaxed text-silver">
                &ldquo;{t.quote}&rdquo;
              </p>
              <div className="mt-6 flex items-center gap-3">
                <div className="flex h-9 w-9 items-center justify-center rounded-full bg-ctaGold/20 font-heading text-sm font-bold text-ctaGold">
                  {t.avatar}
                </div>
                <div>
                  <p className="text-sm font-semibold text-offWhite">{t.name}</p>
                  <p className="text-xs text-silver">
                    {t.city} ·
                    <span className="ml-1 rounded-full bg-white/10 px-2 py-0.5 text-[10px] font-medium">
                      {t.type}
                    </span>
                  </p>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
