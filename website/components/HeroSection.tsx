"use client";

import { useLanguage } from "@/context/LanguageContext";
import { motion } from "framer-motion";
import Image from "next/image";
import { ArrowRight, Download, PlayCircle, Star, TrendingUp, Zap } from "lucide-react";
import { Button } from "./ui/Button";
import { GlassCard } from "./ui/GlassCard";

const logos = [
  "/logos/logo-1.svg",
  "/logos/logo-2.svg",
  "/logos/logo-3.svg",
  "/logos/logo-4.svg",
  "/logos/logo-5.svg",
];

const statCards = [
  { icon: TrendingUp, label: "processed today", value: "₹2.4M", color: "text-green-400" },
  { icon: Star, label: "rated", value: "4.9★", color: "text-ctaGold" },
  { icon: Zap, label: "uptime", value: "99.9%", color: "text-blue-400" },
];

const floatVariants = {
  float: (i: number) => ({
    y: [0, -10, 0],
    transition: {
      duration: 3 + i * 0.5,
      repeat: Infinity,
      ease: "easeInOut" as const,
      delay: i * 0.4,
    },
  }),
};

export function HeroSection() {
  const { t } = useLanguage();
  const headline = t("hero.headline");
  const highlightText = headline.includes("Everywhere")
    ? "Everywhere"
    : headline.includes("எங்கும்")
      ? "எங்கும்"
      : headline.includes("हर जगह")
        ? "हर जगह"
        : "Everywhere";
  const [beforeHighlight, afterHighlight] = headline.split(highlightText);

  return (
    <section className="section-wrap pt-36 sm:pt-40" aria-labelledby="hero-title">
      <div className="section-inner">
        <div className="grid items-center gap-14 lg:grid-cols-2">
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.4 }}
            transition={{ duration: 0.6 }}
          >
            <motion.div
              animate={{ scale: [1, 1.04, 1] }}
              transition={{ duration: 2.5, repeat: Infinity }}
              className="mb-5 inline-flex items-center gap-2 rounded-full border border-ctaGold/40 bg-ctaGold/10 px-4 py-1.5 text-sm font-semibold text-ctaGold"
            >
              {t("hero.badge")}
            </motion.div>

            <h1
              id="hero-title"
              className="font-heading text-4xl font-bold leading-tight tracking-tight text-offWhite sm:text-5xl lg:text-6xl"
            >
              {beforeHighlight}
              <span className="bg-gradient-to-r from-ctaGold to-highlight bg-clip-text text-transparent">
                {highlightText}
              </span>
              {afterHighlight}
            </h1>
            <p className="mt-6 max-w-xl text-base leading-relaxed text-silver sm:text-lg">
              {t("hero.subheadline")} Works even without internet.
            </p>

            <div className="mt-9 flex flex-wrap gap-4">
              <Button
                href="#contact"
                ariaLabel={t("hero.startTrial")}
                analyticsEvent="cta_click"
                analyticsLabel="hero_start_trial"
              >
                <span className="inline-flex items-center gap-2">
                  {t("hero.startTrial")} <ArrowRight size={16} />
                </span>
              </Button>
              <Button
                href="#video"
                variant="ghost"
                ariaLabel={t("hero.watchDemo")}
                analyticsEvent="cta_click"
                analyticsLabel="hero_watch_demo"
              >
                <span className="inline-flex items-center gap-2">
                  <PlayCircle size={16} /> {t("hero.watchDemo")}
                </span>
              </Button>
              <Button
                href="/download"
                variant="outline"
                ariaLabel={t("hero.downloadApk")}
                analyticsEvent="download_click"
                analyticsLabel="hero_download_apk"
              >
                <span className="inline-flex items-center gap-2">
                  <Download size={14} /> {t("hero.downloadApk")}
                  <span className="ml-1 rounded-full bg-ctaGold/20 px-2 py-0.5 text-[10px] font-bold text-ctaGold">
                    v2.0 • 28 MB
                  </span>
                </span>
              </Button>
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 40 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, amount: 0.3 }}
            transition={{ duration: 0.7 }}
            className="relative"
          >
            <div className="absolute -left-12 top-6 h-52 w-52 rounded-full bg-ctaGold/20 blur-3xl" />
            <div className="absolute -right-6 bottom-8 h-48 w-48 rounded-full bg-highlight/20 blur-3xl" />

            <GlassCard className="relative p-4 sm:p-6">
              <div className="grid grid-cols-[1fr_auto] items-end gap-4">
                <Image
                  src="/mockups/web-pos.svg"
                  alt="Web POS dashboard preview"
                  width={760}
                  height={500}
                  className="h-auto w-full rounded-xl"
                  sizes="(max-width: 1024px) 100vw, 760px"
                  priority
                />
                <Image
                  src="/mockups/mobile-pos.svg"
                  alt="Mobile POS app preview"
                  width={240}
                  height={480}
                  className="hidden h-auto w-28 -translate-y-6 rounded-3xl border border-white/20 shadow-2xl sm:block"
                  sizes="112px"
                />
              </div>
            </GlassCard>

            {statCards.map((card, i) => (
              <motion.div
                key={card.label}
                custom={i}
                animate="float"
                variants={floatVariants}
                className={`absolute rounded-xl border border-white/10 bg-navy/90 px-3 py-2 text-sm shadow-lg backdrop-blur-xl ${
                  i === 0
                    ? "-left-8 top-8 hidden sm:block"
                    : i === 1
                      ? "-right-4 top-1/3 hidden sm:block"
                      : "-bottom-2 left-1/4 hidden sm:block"
                }`}
              >
                <div className="flex items-center gap-2">
                  <card.icon size={14} className={card.color} />
                  <span className={`font-bold ${card.color}`}>{card.value}</span>
                  <span className="text-silver">{card.label}</span>
                </div>
              </motion.div>
            ))}
          </motion.div>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.5 }}
          transition={{ duration: 0.5, delay: 0.1 }}
          className="mt-16 rounded-2xl border border-highlight/20 bg-white/5 p-6 backdrop-blur-xl"
        >
          <p className="text-center text-sm font-medium uppercase tracking-[0.22em] text-highlight">
            {t("hero.trustedBy")} across India
          </p>
          <div className="mt-5 flex gap-4 overflow-hidden">
            {[...logos, ...logos].map((src, i) => (
              <Image
                key={`${src}-${i}`}
                src={src}
                alt={`Partner logo ${(i % 5) + 1}`}
                width={80}
                height={32}
                className="h-8 w-auto shrink-0 opacity-60 grayscale transition hover:opacity-100 hover:grayscale-0"
                loading="lazy"
              />
            ))}
          </div>
        </motion.div>
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
