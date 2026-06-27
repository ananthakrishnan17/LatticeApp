"use client";

import { trackEvent } from "@/lib/analytics";
import Link from "next/link";
import { MouseEventHandler, ReactNode } from "react";

type ButtonVariant = "primary" | "ghost" | "outline";

type ButtonProps = {
  href: string;
  children: ReactNode;
  variant?: ButtonVariant;
  ariaLabel?: string;
  analyticsEvent?: string;
  analyticsLabel?: string;
  onClick?: MouseEventHandler<HTMLAnchorElement>;
};

const variantClasses: Record<ButtonVariant, string> = {
  primary:
    "bg-gold-gradient text-navy shadow-halo hover:brightness-110 focus-visible:ring-ctaGold/60",
  ghost:
    "border border-highlight/50 bg-white/5 text-offWhite hover:bg-white/10 focus-visible:ring-highlight/60",
  outline:
    "border border-ctaGold/60 bg-transparent text-ctaGold hover:bg-ctaGold/10 focus-visible:ring-ctaGold/60",
};

export function Button({
  href,
  children,
  variant = "primary",
  ariaLabel,
  analyticsEvent,
  analyticsLabel,
  onClick,
}: ButtonProps) {
  return (
    <Link
      href={href}
      aria-label={ariaLabel}
      onClick={(event) => {
        onClick?.(event);
        if (analyticsEvent) {
          trackEvent(analyticsEvent, {
            cta_label: analyticsLabel ?? ariaLabel ?? href,
            cta_target: href,
          });
        }
      }}
      className={`inline-flex items-center justify-center rounded-xl px-6 py-3 text-sm font-semibold tracking-wide transition-all duration-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-navy ${variantClasses[variant]}`}
    >
      {children}
    </Link>
  );
}
