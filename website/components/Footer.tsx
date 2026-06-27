import {
  Download,
  Globe,
  MessageCircle,
  PlayCircle,
  Send,
  Share2,
} from "lucide-react";
import Link from "next/link";

const columns = [
  {
    title: "Product",
    links: [
      { label: "Features", href: "#features" },
      { label: "Demo", href: "#demo" },
      { label: "Pricing", href: "#pricing" },
      { label: "Download APK", href: "/download" },
      { label: "Changelog", href: "#" },
    ],
  },
  {
    title: "Company",
    links: [
      { label: "About", href: "#" },
      { label: "Blog", href: "#" },
      { label: "Careers", href: "#" },
      { label: "Press", href: "#" },
    ],
  },
  {
    title: "Support",
    links: [
      { label: "Documentation", href: "#" },
      { label: "FAQ", href: "#faq" },
      { label: "Contact Us", href: "#contact" },
      { label: "WhatsApp Support", href: "https://wa.me/919999900000" },
    ],
  },
  {
    title: "Legal",
    links: [
      { label: "Privacy Policy", href: "#" },
      { label: "Terms of Service", href: "#" },
      { label: "Cookie Policy", href: "#" },
      { label: "Refund Policy", href: "#" },
    ],
  },
];

const socials = [
  { icon: Share2, label: "Twitter / X", href: "#" },
  { icon: Globe, label: "LinkedIn", href: "#" },
  { icon: Send, label: "Instagram", href: "#" },
  { icon: PlayCircle, label: "YouTube", href: "#" },
  { icon: MessageCircle, label: "WhatsApp", href: "https://wa.me/919999900000" },
];

export function Footer() {
  return (
    <footer className="border-t border-white/10 bg-navy/60 backdrop-blur-xl" aria-label="Site footer">
      <div className="section-inner px-6 py-16 sm:px-10">
        <div className="grid gap-10 lg:grid-cols-5">
          <div className="lg:col-span-1">
            <Link href="/" className="font-heading text-xl font-semibold text-offWhite">
              NammaNanban
            </Link>
            <p className="mt-3 text-sm text-silver">
              The POS that works everywhere — Web, Mobile &amp; Offline.
            </p>
            <div className="mt-5 flex gap-3">
              {socials.map((s) => (
                <a
                  key={s.label}
                  href={s.href}
                  aria-label={s.label}
                  className="flex h-9 w-9 items-center justify-center rounded-lg border border-white/10 bg-white/5 text-silver transition hover:border-ctaGold/30 hover:text-ctaGold"
                >
                  <s.icon size={16} />
                </a>
              ))}
            </div>
            <Link
              href="/download"
              className="mt-6 inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-offWhite transition hover:bg-white/10"
            >
              <Download size={14} />
              Download APK
            </Link>
          </div>

          {columns.map((col) => (
            <div key={col.title}>
              <h3 className="mb-4 text-xs font-semibold uppercase tracking-widest text-ctaGold">
                {col.title}
              </h3>
              <ul className="space-y-3">
                {col.links.map((link) => (
                  <li key={link.label}>
                    <Link href={link.href} className="text-sm text-silver transition hover:text-offWhite">
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>

      <div className="border-t border-white/10 px-6 py-5 sm:px-10">
        <div className="section-inner flex flex-wrap items-center justify-between gap-4 text-xs text-silver">
          <p>© 2025 NammaNanban · All rights reserved.</p>
          <div className="flex gap-5">
            {["Privacy Policy", "Terms", "Cookie Policy"].map((l) => (
              <Link key={l} href="#" className="transition hover:text-offWhite">
                {l}
              </Link>
            ))}
          </div>
        </div>
      </div>
    </footer>
  );
}
