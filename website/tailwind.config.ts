import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        navy: {
          DEFAULT: "#0A1628",
          950: "#04091A",
          900: "#0A1628",
          800: "#112240",
        },
        silver: {
          DEFAULT: "#A8B2C3",
          light: "#C0C8D8",
          muted: "#6B7A8F",
        },
        gold: {
          DEFAULT: "#D4AF6A",
          light: "#E8C97A",
          dark: "#B8943A",
        },
        white: {
          DEFAULT: "#F4F6FA",
          pure: "#FFFFFF",
        },
        deepNavy: "#112240",
        highlight: "#C0C8D8",
        ctaGold: "#D4AF6A",
        offWhite: "#F4F6FA",
      },
      fontFamily: {
        heading: ["var(--font-sora)", "sans-serif"],
        body: ["var(--font-inter)", "sans-serif"],
      },
      backgroundImage: {
        "gold-gradient": "linear-gradient(135deg, #D4AF6A 0%, #f3d9a4 100%)",
        "silver-divider": "linear-gradient(90deg, rgba(192,200,216,0) 0%, rgba(192,200,216,0.65) 50%, rgba(212,175,106,0.35) 100%)",
      },
      boxShadow: {
        "gold-glow": "0 0 40px rgba(212,175,106,0.35)",
        halo: "0 0 80px rgba(212,175,106,0.22)",
      },
    },
  },
  plugins: [],
};

export default config;
