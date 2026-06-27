"use client";

import { useLanguage } from "@/context/LanguageContext";
import { motion } from "framer-motion";
import { Check } from "lucide-react";
import { useState } from "react";
import { Button } from "./ui/Button";
import { SectionTitle } from "./ui/SectionTitle";

const plans = [
  {
    name: "Starter",
    tag: "Solo sellers & kiosks",
    monthlyPrice: 499,
    features: [
      "1 Web POS terminal",
      "2 Mobile devices",
      "500 products",
      "Basic reports",
      "Email support",
      "14-day free trial",
    ],
    cta: "Start Free Trial",
    href: "#contact",
  },
  {
    name: "Professional",
    tag: "Growing retail chains",
    monthlyPrice: 1299,
    popular: true,
    features: [
      "5 Web POS terminals",
      "10 Mobile devices",
      "Unlimited products",
      "Advanced reports & P&L",
      "Priority support",
      "WhatsApp receipts",
      "API access",
      "14-day free trial",
    ],
    cta: "Start Free Trial",
    href: "#contact",
  },
  {
    name: "Enterprise",
    tag: "Large businesses & franchises",
    monthlyPrice: null,
    features: [
      "Unlimited terminals",
      "Unlimited devices",
      "Multi-branch management",
      "Custom integrations",
      "Dedicated account manager",
      "SLA guarantee",
      "Custom onboarding",
      "SSO & advanced security",
    ],
    cta: "Contact Sales",
    href: "#contact",
  },
];

const comparisonRows = [
  { label: "Web POS terminals", starter: "1", professional: "5", enterprise: "Unlimited" },
  { label: "Mobile devices", starter: "2", professional: "10", enterprise: "Unlimited" },
  { label: "Products", starter: "500", professional: "Unlimited", enterprise: "Unlimited" },
  { label: "Reports", starter: "Basic", professional: "Advanced + P&L", enterprise: "Custom BI" },
  { label: "Support", starter: "Email", professional: "Priority", enterprise: "Dedicated manager" },
];

export function PricingSection() {
  const { t } = useLanguage();
  const [yearly, setYearly] = useState(false);

  return (
    <section id="pricing" className="section-wrap" aria-labelledby="pricing-title">
      <div className="section-inner">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <SectionTitle
            title={t("pricing.title")}
            subtitle={t("pricing.subtitle")}
          />
        </motion.div>

        <div className="mt-10 flex items-center justify-center gap-4">
          <span className={`text-sm ${!yearly ? "font-semibold text-offWhite" : "text-silver"}`}>
            {t("pricing.monthly")}
          </span>
          <button
            type="button"
            role="switch"
            aria-checked={yearly}
            onClick={() => setYearly((p) => !p)}
            className={`relative h-7 w-12 rounded-full transition-colors ${yearly ? "bg-ctaGold" : "bg-white/20"}`}
          >
            <span
              className={`absolute top-0.5 h-6 w-6 rounded-full bg-white shadow transition-transform ${
                yearly ? "translate-x-5" : "translate-x-0.5"
              }`}
            />
          </button>
          <span className={`text-sm ${yearly ? "font-semibold text-offWhite" : "text-silver"}`}>
            {t("pricing.yearly")}
            <span className="ml-1 rounded-full bg-green-500/20 px-2 py-0.5 text-xs font-bold text-green-400">
              {t("pricing.save")}
            </span>
          </span>
        </div>

        <div className="mt-12 grid gap-6 md:grid-cols-3">
          {plans.map((plan, i) => (
            <motion.div
              key={plan.name}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: i * 0.1 }}
              className={`relative flex flex-col rounded-2xl border p-7 backdrop-blur-xl transition hover:scale-[1.02] ${
                plan.popular
                  ? "border-ctaGold/60 bg-ctaGold/5 shadow-[0_0_40px_rgba(212,175,106,0.18)]"
                  : "border-white/10 bg-white/5"
              }`}
            >
              {plan.popular && (
                <span className="absolute -top-3.5 left-1/2 -translate-x-1/2 rounded-full border border-ctaGold/40 bg-ctaGold px-4 py-1 text-xs font-bold text-navy">
                  Most Popular
                </span>
              )}
              <p className="text-xs font-medium uppercase tracking-widest text-ctaGold">{plan.tag}</p>
              <h3 className="mt-2 font-heading text-2xl font-bold text-offWhite">{plan.name}</h3>
              <div className="mt-4">
                {plan.monthlyPrice ? (
                  <p className="font-heading text-4xl font-bold text-offWhite">
                    ₹{yearly ? Math.round(plan.monthlyPrice * 0.8) : plan.monthlyPrice}
                    <span className="text-base font-normal text-silver">/mo</span>
                  </p>
                ) : (
                  <p className="font-heading text-2xl font-bold text-offWhite">Custom</p>
                )}
              </div>
              <ul className="mt-6 flex-1 space-y-3">
                {plan.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm text-silver">
                    <Check size={15} className="mt-0.5 shrink-0 text-ctaGold" />
                    {f}
                  </li>
                ))}
              </ul>
              <div className="mt-8">
                <Button
                  href={plan.href}
                  variant={plan.popular ? "primary" : "ghost"}
                  ariaLabel={plan.cta}
                  analyticsEvent="cta_click"
                  analyticsLabel={`pricing_${plan.name.toLowerCase()}`}
                >
                  {plan.cta}
                </Button>
              </div>
            </motion.div>
          ))}
        </div>

        <div className="mt-10 overflow-x-auto rounded-2xl border border-white/10 bg-white/5 p-3 backdrop-blur-xl">
          <table className="w-full min-w-[640px] border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-white/10 text-offWhite">
                <th className="px-4 py-3 font-semibold">Plan comparison</th>
                <th className="px-4 py-3 font-semibold">Starter</th>
                <th className="px-4 py-3 font-semibold">Professional</th>
                <th className="px-4 py-3 font-semibold">Enterprise</th>
              </tr>
            </thead>
            <tbody>
              {comparisonRows.map((row) => (
                <tr key={row.label} className="border-b border-white/5 last:border-0">
                  <td className="px-4 py-3 text-silver">{row.label}</td>
                  <td className="px-4 py-3 text-offWhite">{row.starter}</td>
                  <td className="px-4 py-3 text-offWhite">{row.professional}</td>
                  <td className="px-4 py-3 text-offWhite">{row.enterprise}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <p className="mt-8 text-center text-sm text-silver">
          No credit card required · Cancel anytime · Free migration
        </p>
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
