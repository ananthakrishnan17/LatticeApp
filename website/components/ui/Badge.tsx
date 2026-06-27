import { ReactNode } from "react";

type BadgeProps = {
  children: ReactNode;
};

export function Badge({ children }: BadgeProps) {
  return (
    <span className="inline-flex rounded-full border border-ctaGold/30 bg-ctaGold/10 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.22em] text-ctaGold">
      {children}
    </span>
  );
}
