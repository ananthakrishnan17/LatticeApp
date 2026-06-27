import Link from "next/link";

type StoreButtonProps = {
  store: "google" | "apple";
  href?: string;
  comingSoon?: boolean;
};

export function StoreButton({
  store,
  href = "#",
  comingSoon = false,
}: StoreButtonProps) {
  const isGoogle = store === "google";

  return (
    <div className="relative inline-flex">
      <Link
        href={href}
        className={`flex items-center gap-3 rounded-xl border px-4 py-3 transition ${
          comingSoon
            ? "cursor-not-allowed border-white/10 opacity-50"
            : "border-white/20 bg-white/5 hover:bg-white/10"
        }`}
        aria-label={isGoogle ? "Get on Google Play" : "Download on App Store"}
        aria-disabled={comingSoon}
        onClick={comingSoon ? (e) => e.preventDefault() : undefined}
      >
        {isGoogle ? (
          <svg viewBox="0 0 24 24" className="h-6 w-6" fill="currentColor" aria-hidden="true">
            <path d="M3.18 23.76c.28.16.6.22.93.18l12.83-11.86L13.35 8.5 3.18 23.76zm17.16-11.03-2.9-1.68-3.22 2.98 3.22 2.97 2.91-1.68c.83-.48.83-1.12-.01-1.59zM2.38.28C2.14.54 2 .94 2 1.47v21.06c0 .53.15.93.39 1.19l.07.07 11.8-10.91v-.26L2.45.2l-.07.08zM16.11 9.48 13.35 6.73 2.52.05c-.3-.17-.61-.22-.9-.16l11.72 11.08 2.77-2.49z" />
          </svg>
        ) : (
          <svg viewBox="0 0 24 24" className="h-6 w-6" fill="currentColor" aria-hidden="true">
            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
          </svg>
        )}
        <div className="text-start">
          <p className="text-[10px] text-silver">
            {isGoogle ? "Get it on" : "Download on the"}
          </p>
          <p className="text-sm font-semibold text-offWhite">
            {isGoogle ? "Google Play" : "App Store"}
          </p>
        </div>
      </Link>
      {comingSoon && (
        <div className="absolute inset-0 flex items-center justify-center rounded-xl bg-navy/60">
          <span className="rounded-full bg-white/10 px-2 py-0.5 text-[10px] font-semibold text-silver">
            Coming Soon
          </span>
        </div>
      )}
    </div>
  );
}
