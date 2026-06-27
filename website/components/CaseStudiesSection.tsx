"use client";

import { motion } from "framer-motion";
import { SectionTitle } from "./ui/SectionTitle";

const caseStudies = [
  {
    business: "Annapoorna Mini Mart",
    profile: "Neighborhood Grocery, Coimbatore",
    result: "Revenue up 24% in 4 months",
    detail:
      "Switched from manual billing to NammaNanban and cut average checkout time from 3 minutes to 50 seconds.",
  },
  {
    business: "Sri Lakshmi Pharmacy",
    profile: "Single-store Pharmacy, Chennai",
    result: "Expired stock down 38%",
    detail:
      "Automated low-stock and expiry alerts helped the team avoid dead inventory and improve purchase planning.",
  },
  {
    business: "Urban Plates Café",
    profile: "Quick-service Restaurant, Bengaluru",
    result: "30% faster table turnover",
    detail:
      "KOT + mobile billing reduced order delays and gave managers real-time visibility of peak-hour sales.",
  },
];

export function CaseStudiesSection() {
  return (
    <section id="case-studies" className="section-wrap" aria-labelledby="case-studies-title">
      <div className="section-inner">
        <SectionTitle
          title="Case studies with measurable outcomes"
          subtitle="How growing businesses improved speed, accuracy, and profit."
        />
        <div className="mt-12 grid gap-6 lg:grid-cols-3">
          {caseStudies.map((item, index) => (
            <motion.article
              key={item.business}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: index * 0.08 }}
              className="rounded-2xl border border-white/10 bg-white/5 p-6 backdrop-blur-xl"
            >
              <p className="text-xs uppercase tracking-widest text-ctaGold">{item.profile}</p>
              <h3 className="mt-2 font-heading text-xl font-bold text-offWhite">{item.business}</h3>
              <p className="mt-4 text-sm leading-relaxed text-silver">{item.detail}</p>
              <p className="mt-5 rounded-full bg-ctaGold/15 px-3 py-1.5 text-sm font-semibold text-ctaGold">
                {item.result}
              </p>
            </motion.article>
          ))}
        </div>
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
