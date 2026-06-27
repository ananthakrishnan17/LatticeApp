"use client";

import { useLanguage } from "@/context/LanguageContext";
import { motion } from "framer-motion";
import type { LucideIcon } from "lucide-react";
import {
  BarChart2,
  Cpu,
  CreditCard,
  FileText,
  Globe,
  Layers,
  Lock,
  Map,
  Package,
  Receipt,
  Scan,
  Smartphone,
  Users,
  WifiOff,
  Zap,
} from "lucide-react";
import { useMemo, useState } from "react";
import { SectionTitle } from "./ui/SectionTitle";

const pills = [
  "Multi-currency", "Cloud sync", "WhatsApp receipts", "Dark mode",
  "Bulk import", "SMS alerts", "API access", "Webhook support",
  "Custom branding", "Employee attendance", "Cash denomination", "Day-end report",
  "Kot management", "Table billing", "Delivery tracking", "Franchise ready",
  "Tally export", "24/7 support",
];

type FeatureItem = { icon: LucideIcon; title: string; desc: string };

type Tab = "Web POS" | "Mobile POS" | "Back Office";

const features: Record<Tab, FeatureItem[]> = {
  "Web POS": [
    { icon: BarChart2, title: "Real-time Sales Dashboard", desc: "Live sales metrics at a glance." },
    { icon: Cpu, title: "Multi-terminal Billing", desc: "Run multiple counters simultaneously." },
    { icon: Scan, title: "Barcode Scanner Support", desc: "Plug-and-play USB scanners." },
    { icon: FileText, title: "GST / Tax Automation", desc: "Auto-apply GST rates and generate compliant bills." },
    { icon: Receipt, title: "Receipt Printing (thermal)", desc: "58mm / 80mm thermal printer support." },
    { icon: Lock, title: "Role-based Access Control", desc: "Cashier, manager, owner roles out of the box." },
  ],
  "Mobile POS": [
    { icon: WifiOff, title: "Full Offline Mode", desc: "Bill without internet; sync on reconnect." },
    { icon: Scan, title: "Camera Barcode Scanner", desc: "Use phone camera as barcode reader." },
    { icon: CreditCard, title: "UPI / QR Payment", desc: "Integrated UPI QR code generation." },
    { icon: Zap, title: "Lightweight APK", desc: "28 MB install, fast on any Android device." },
    { icon: Smartphone, title: "Any Android Device", desc: "Android 7.0+ supported." },
    { icon: Map, title: "Sales Rep Tracking", desc: "GPS-based field rep tracking." },
  ],
  "Back Office": [
    { icon: Package, title: "Inventory Management", desc: "Stock tracking with low-stock alerts." },
    { icon: Users, title: "Customer & Loyalty", desc: "Loyalty points and customer profiles." },
    { icon: Layers, title: "Purchase Orders", desc: "Supplier management and PO workflows." },
    { icon: BarChart2, title: "Detailed P&L Reports", desc: "Profit & loss by branch, date, or category." },
    { icon: Globe, title: "Multi-branch Management", desc: "Manage unlimited locations from one dashboard." },
    { icon: FileText, title: "Export to Excel / PDF", desc: "One-click data export." },
  ],
};

export function FeaturesSection() {
  const { t } = useLanguage();
  const tabs = useMemo(
    () => [t("features.webPos"), t("features.mobilePos"), t("features.backOffice")] as const,
    [t],
  );
  const [activeTab, setActiveTab] = useState<Tab>("Web POS");

  const tabMap = useMemo<Record<string, Tab>>(
    () => ({
      [t("features.webPos")]: "Web POS",
      [t("features.mobilePos")]: "Mobile POS",
      [t("features.backOffice")]: "Back Office",
    }),
    [t],
  );

  return (
    <section id="features" className="section-wrap" aria-labelledby="features-title">
      <div className="section-inner">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <SectionTitle
            title={t("features.title")}
            subtitle={t("features.subtitle")}
          />
        </motion.div>

        <div className="mt-10 flex justify-center">
          <div className="inline-flex rounded-xl border border-white/10 bg-white/5 p-1">
            {tabs.map((tab) => {
              const mappedTab = tabMap[tab];
              return (
                <button
                  key={tab}
                  type="button"
                  onClick={() => setActiveTab(mappedTab)}
                  className={`rounded-lg px-5 py-2.5 text-sm font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ctaGold/50 ${
                    activeTab === mappedTab
                      ? "bg-ctaGold text-navy shadow-md"
                      : "text-silver hover:text-offWhite"
                  }`}
                >
                  {tab}
                </button>
              );
            })}
          </div>
        </div>

        <motion.div
          key={activeTab}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35 }}
          className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3"
        >
          {features[activeTab].map((f) => (
            <div
              key={f.title}
              className="flex gap-4 rounded-2xl border border-white/10 bg-white/5 p-5 backdrop-blur-xl transition hover:scale-[1.02] hover:border-ctaGold/30"
            >
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-ctaGold/10">
                <f.icon size={18} className="text-ctaGold" />
              </div>
              <div>
                <h3 className="text-sm font-semibold text-offWhite">{f.title}</h3>
                <p className="mt-1 text-xs text-silver">{f.desc}</p>
              </div>
            </div>
          ))}
        </motion.div>

        <div className="mt-14 flex flex-wrap justify-center gap-3">
          {pills.map((pill) => (
            <span
              key={pill}
              className="rounded-full border border-white/10 bg-white/5 px-4 py-1.5 text-xs font-medium text-silver"
            >
              {pill}
            </span>
          ))}
        </div>
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
