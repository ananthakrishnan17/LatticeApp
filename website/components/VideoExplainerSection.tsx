"use client";

import { motion } from "framer-motion";
import { Clock, Play, WifiOff, Zap } from "lucide-react";
import { useState } from "react";
import { SectionTitle } from "./ui/SectionTitle";

const highlights = [
  { icon: Zap, title: "Zero Learning Curve", desc: "Your team is up and running in minutes." },
  { icon: WifiOff, title: "Works Offline", desc: "Keep billing even when the internet drops." },
  { icon: Clock, title: "Instant Setup", desc: "From sign-up to first invoice in under 10 min." },
];

export function VideoExplainerSection() {
  const [playing, setPlaying] = useState(false);

  return (
    <section id="video" className="section-wrap" aria-labelledby="video-title">
      <div className="section-inner">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <SectionTitle
            title="See the magic in 2 minutes"
            subtitle="Watch how NammaNanban transforms your billing workflow."
          />
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.1 }}
          className="mt-12 overflow-hidden rounded-3xl border border-ctaGold/20 bg-white/5 shadow-[0_0_60px_rgba(212,175,106,0.12)] backdrop-blur-xl"
        >
          <div className="relative mx-auto max-w-4xl">
            <div className="relative flex aspect-video w-full items-center justify-center overflow-hidden bg-navy/80">
              {!playing ? (
                <div className="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-navy/90 to-deepNavy/90">
                  <p className="absolute left-8 top-8 font-heading text-xl font-bold text-offWhite opacity-60">
                    NammaNanban POS — Product Demo
                  </p>
                  <button
                    type="button"
                    onClick={() => setPlaying(true)}
                    className="group relative flex h-20 w-20 items-center justify-center rounded-full bg-ctaGold shadow-[0_0_40px_rgba(212,175,106,0.5)] transition hover:scale-110 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ctaGold/50"
                    aria-label="Play demo video"
                  >
                    <Play size={28} className="translate-x-0.5 text-navy" fill="currentColor" />
                  </button>
                </div>
              ) : (
                <video
                  className="h-full w-full"
                  autoPlay
                  controls
                  src="/demo.mp4"
                  aria-label="NammaNanban product demo"
                >
                  Your browser does not support the video tag.
                </video>
              )}
            </div>
          </div>
        </motion.div>

        <div className="mt-14 grid gap-6 sm:grid-cols-3">
          {highlights.map((h, i) => (
            <motion.div
              key={h.title}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: i * 0.1 }}
              className="flex flex-col items-center rounded-2xl border border-white/10 bg-white/5 p-6 text-center backdrop-blur-xl"
            >
              <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-ctaGold/10">
                <h.icon size={22} className="text-ctaGold" />
              </div>
              <h3 className="font-heading text-base font-semibold text-offWhite">{h.title}</h3>
              <p className="mt-2 text-sm text-silver">{h.desc}</p>
            </motion.div>
          ))}
        </div>
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
