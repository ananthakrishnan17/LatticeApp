"use client";

import { motion } from "framer-motion";
import { Mail, MapPin, MessageCircle } from "lucide-react";
import { FormEvent, useState } from "react";
import { trackEvent } from "@/lib/analytics";
import { Button } from "./ui/Button";
import { SectionTitle } from "./ui/SectionTitle";

const businessTypes = [
  "Retail Store", "Restaurant / Café", "Pharmacy",
  "Wholesale", "Electronics", "Boutique / Fashion",
  "Grocery", "Other",
];

function isValidEmail(email: string) {
  if (!email || email.length > 320 || email.includes(" ")) {
    return false;
  }

  const parts = email.split("@");
  if (parts.length !== 2) {
    return false;
  }

  const [localPart, domain] = parts;
  return Boolean(localPart) && domain.includes(".") && !domain.startsWith(".") && !domain.endsWith(".");
}

function isValidPhone(phone: string) {
  if (!phone) {
    return true;
  }

  const cleaned = phone.replaceAll(" ", "").replaceAll("-", "");
  const digitsOnly = cleaned.startsWith("+") ? cleaned.slice(1) : cleaned;

  if (digitsOnly.length < 8 || digitsOnly.length > 15) {
    return false;
  }

  for (let index = 0; index < digitsOnly.length; index += 1) {
    const char = digitsOnly[index];
    if (char < "0" || char > "9") {
      return false;
    }
  }

  return true;
}

export function ContactSection() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [errorMessage, setErrorMessage] = useState("");

  const endpoint = process.env.NEXT_PUBLIC_CONTACT_FORM_ENDPOINT || "/api/contact";

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setErrorMessage("");
    setStatus("sending");
    const form = e.currentTarget;
    const data = Object.fromEntries(new FormData(form).entries());
    const name = String(data.name ?? "").trim();
    const email = String(data.email ?? "").trim();
    const phone = String(data.phone ?? "").trim();
    const message = String(data.message ?? "").trim();

    if (name.length < 2) {
      setStatus("error");
      setErrorMessage("Please enter your full name.");
      return;
    }

    if (!isValidEmail(email)) {
      setStatus("error");
      setErrorMessage("Please enter a valid email address.");
      return;
    }

    if (!isValidPhone(phone)) {
      setStatus("error");
      setErrorMessage("Please enter a valid phone number.");
      return;
    }

    if (message.length > 1000) {
      setStatus("error");
      setErrorMessage("Message should be less than 1000 characters.");
      return;
    }

    try {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...data, name, email, phone, message }),
      });
      const body = await res.json().catch(() => ({} as { error?: string }));
      if (res.ok) {
        setStatus("sent");
        form.reset();
        trackEvent("form_submission", {
          form_name: "contact",
          status: "success",
        });
      } else {
        setStatus("error");
        setErrorMessage(body.error || "Unable to send your message right now.");
        trackEvent("form_submission", {
          form_name: "contact",
          status: "error",
        });
      }
    } catch {
      setStatus("error");
      setErrorMessage("Network issue while sending your message.");
      trackEvent("form_submission", {
        form_name: "contact",
        status: "error",
      });
    }
  };

  return (
    <section id="contact" className="section-wrap" aria-labelledby="contact-title">
      <div className="section-inner">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="mb-16 overflow-hidden rounded-3xl border border-ctaGold/20 bg-gradient-to-br from-ctaGold/10 via-white/5 to-white/5 p-10 text-center"
        >
          <h2 className="font-heading text-3xl font-bold text-offWhite sm:text-4xl">
            Ready to transform your business?
          </h2>
          <p className="mt-3 text-silver">Join 5,000+ businesses already using NammaNanban.</p>
          <div className="mt-8 flex flex-wrap justify-center gap-4">
            <Button href="#contact" ariaLabel="Start free trial" analyticsEvent="cta_click" analyticsLabel="contact_banner_start_trial">Start Free Trial</Button>
            <Button href="#contact" variant="ghost" ariaLabel="Book a live demo" analyticsEvent="cta_click" analyticsLabel="contact_banner_live_demo">Book a Live Demo</Button>
          </div>
        </motion.div>

        <div className="grid gap-10 lg:grid-cols-2">
          <motion.div
            initial={{ opacity: 0, x: -30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <SectionTitle title="Get in touch" subtitle="We'll respond within 24 hours." />
            <form onSubmit={handleSubmit} className="mt-8 space-y-5">
              <input
                type="text"
                name="companyWebsite"
                tabIndex={-1}
                autoComplete="off"
                className="absolute -left-[9999px] h-px w-px overflow-hidden"
                title="Leave this field empty"
                aria-label="Leave this field empty"
                aria-hidden="true"
                role="presentation"
              />
              {[
                { name: "name", label: "Name", type: "text", placeholder: "Your name" },
                { name: "email", label: "Email", type: "email", placeholder: "you@example.com" },
                { name: "phone", label: "Phone", type: "tel", placeholder: "+91 9876543210" },
              ].map((field) => (
                <div key={field.name}>
                  <label htmlFor={field.name} className="mb-1.5 block text-sm font-medium text-silver">
                    {field.label}
                  </label>
                  <input
                    id={field.name}
                    name={field.name}
                    type={field.type}
                    placeholder={field.placeholder}
                    required
                    className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-offWhite placeholder-silver/40 backdrop-blur-xl transition focus:border-ctaGold/50 focus:outline-none"
                  />
                </div>
              ))}
              <div>
                <label htmlFor="businessType" className="mb-1.5 block text-sm font-medium text-silver">
                  Business Type
                </label>
                <select
                  id="businessType"
                  name="businessType"
                  className="w-full rounded-xl border border-white/10 bg-navy px-4 py-3 text-sm text-offWhite backdrop-blur-xl transition focus:border-ctaGold/50 focus:outline-none"
                >
                  {businessTypes.map((t) => (
                    <option key={t} value={t}>{t}</option>
                  ))}
                </select>
              </div>
              <div>
                <label htmlFor="message" className="mb-1.5 block text-sm font-medium text-silver">
                  Message
                </label>
                <textarea
                  id="message"
                  name="message"
                  rows={4}
                  placeholder="Tell us about your business…"
                  maxLength={1000}
                  className="w-full resize-none rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-offWhite placeholder-silver/40 backdrop-blur-xl transition focus:border-ctaGold/50 focus:outline-none"
                />
                <p className="mt-1 text-xs text-silver/70">Max 1000 characters</p>
              </div>
              <button
                type="submit"
                disabled={status === "sending" || status === "sent"}
                className="w-full rounded-xl bg-gold-gradient px-6 py-3 text-sm font-semibold text-navy shadow-halo transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ctaGold/60"
              >
                {status === "sending" ? "Sending…" : status === "sent" ? "✓ Message sent!" : "Send Message"}
              </button>
              {status === "sent" && (
                <p className="text-center text-sm text-green-400">Thanks! Our team will contact you within 24 hours.</p>
              )}
              {status === "error" && (
                <p className="text-center text-sm text-red-400">{errorMessage || "Something went wrong. Please try again."}</p>
              )}
            </form>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="space-y-6"
          >
            {[
              { icon: Mail, label: "Email", value: "hello@nammananban.com", href: "mailto:hello@nammananban.com" },
              { icon: MessageCircle, label: "WhatsApp", value: "+91 99999 00000", href: "https://wa.me/919999900000" },
              { icon: MapPin, label: "Address", value: "Chennai, Tamil Nadu, India", href: "#" },
            ].map((item) => (
              <a
                key={item.label}
                href={item.href}
                className="flex items-center gap-4 rounded-2xl border border-white/10 bg-white/5 p-5 backdrop-blur-xl transition hover:border-ctaGold/30"
              >
                <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-ctaGold/10">
                  <item.icon size={20} className="text-ctaGold" />
                </div>
                <div>
                  <p className="text-xs font-medium uppercase tracking-widest text-silver">{item.label}</p>
                  <p className="text-sm font-semibold text-offWhite">{item.value}</p>
                </div>
              </a>
            ))}

            <a
              href="https://wa.me/919999900000"
              className="flex w-full items-center justify-center gap-3 rounded-xl border border-green-500/40 bg-green-500/10 px-6 py-4 font-semibold text-green-400 transition hover:bg-green-500/20"
              target="_blank"
              rel="noopener noreferrer"
            >
              <MessageCircle size={18} />
              Chat on WhatsApp
            </a>
          </motion.div>
        </div>
      </div>
      <div className="section-inner mt-16 h-px bg-silver-divider" />
    </section>
  );
}
