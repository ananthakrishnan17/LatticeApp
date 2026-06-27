"use client";

import { useROICalculator } from "@/hooks/useROICalculator";
import { motion } from "framer-motion";
import { ArrowRight } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { GlassCard } from "./ui/GlassCard";
import { SectionTitle } from "./ui/SectionTitle";
import { Slider } from "./ui/Slider";
import { Button } from "./ui/Button";

function AnimatedNumber({ value }: { value: number }) {
  const [displayed, setDisplayed] = useState(value);
  const prevRef = useRef(value);

  useEffect(() => {
    const start = prevRef.current;
    const end = value;
    const duration = 800;
    const startTime = performance.now();

    const tick = (now: number) => {
      const t = Math.min((now - startTime) / duration, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      setDisplayed(Math.round(start + (end - start) * eased));
      if (t < 1) requestAnimationFrame(tick);
    };

    requestAnimationFrame(tick);
    prevRef.current = end;
  }, [value]);

  return <>{displayed.toLocaleString("en-IN")}</>;
}

export function ROICalculator() {
  const [transactions, setTransactions] = useState(500);
  const [avgOrder, setAvgOrder] = useState(800);
  const [staff, setStaff] = useState(2);
  const [hours, setHours] = useState(3);

  const results = useROICalculator({
    monthlyTransactions: transactions,
    avgOrderValue: avgOrder,
    billingStaff: staff,
    manualHoursPerDay: hours,
  });

  return (
    <section id="roi" className="section-wrap" aria-labelledby="roi-title">
      <div className="section-inner">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <SectionTitle
            title="How much could you save?"
            subtitle="See your return on investment in seconds"
          />
        </motion.div>

        <div className="mt-14 grid gap-8 lg:grid-cols-2">
          <motion.div
            initial={{ opacity: 0, x: -30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <GlassCard className="space-y-8 p-8">
              <Slider
                label="Monthly transactions"
                min={50}
                max={5000}
                step={50}
                value={transactions}
                onChange={setTransactions}
                formatValue={(v) => v.toLocaleString("en-IN")}
              />
              <Slider
                label="Average order value"
                min={100}
                max={5000}
                step={50}
                value={avgOrder}
                onChange={setAvgOrder}
                formatValue={(v) => `₹${v.toLocaleString("en-IN")}`}
              />
              <Slider
                label="Number of billing staff"
                min={1}
                max={20}
                value={staff}
                onChange={setStaff}
              />
              <Slider
                label="Hours lost to manual billing/day"
                min={0.5}
                max={12}
                step={0.5}
                value={hours}
                onChange={setHours}
                formatValue={(v) => `${v}h`}
              />
            </GlassCard>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <GlassCard className="flex flex-col justify-between p-8">
              <div className="space-y-6">
                {[
                  { label: "Monthly time saved", value: results.monthlyTimeSaved, suffix: " hrs" },
                  { label: "Annual cost savings", value: results.annualCostSavings, prefix: "₹" },
                  { label: "ROI in first year", value: results.roiFirstYear, suffix: "%" },
                  { label: "Break-even point", value: results.breakEvenWeeks, suffix: " weeks" },
                ].map((row) => (
                  <div
                    key={row.label}
                    className="flex items-center justify-between border-b border-white/10 pb-4"
                  >
                    <span className="text-sm text-silver">{row.label}</span>
                    <span className="font-heading text-xl font-bold text-ctaGold">
                      {row.prefix}
                      <AnimatedNumber value={row.value} />
                      {row.suffix}
                    </span>
                  </div>
                ))}
              </div>
              <div className="mt-8">
                <p className="mb-4 text-center font-heading text-3xl font-bold text-ctaGold">
                  ₹<AnimatedNumber value={results.annualCostSavings} />
                  <span className="block text-sm font-normal text-silver">
                    estimated annual savings
                  </span>
                </p>
                <Button href="#contact" ariaLabel="Start saving today">
                  <span className="inline-flex items-center gap-2">
                    Start saving today <ArrowRight size={16} />
                  </span>
                </Button>
              </div>
            </GlassCard>
          </motion.div>
        </div>
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
