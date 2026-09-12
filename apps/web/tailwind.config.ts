import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  darkMode: ["class", '[data-theme="night"]'],
  theme: {
    extend: {
      colors: {
        primary: "var(--color-primary)",
        accent: "var(--color-accent)",
        success: "var(--color-success)",
        warning: "var(--color-warning)",
        error: "var(--color-error)",
        reward: "var(--color-reward)",
        ink: "var(--color-text)",
        "ink-secondary": "var(--color-text-secondary)",
        "ink-tertiary": "var(--color-text-tertiary)",
        page: "var(--color-page)",
        surface: "var(--color-surface)",
        "surface-card": "var(--color-surface-card)",
        border: "var(--color-border)",
      },
      borderRadius: {
        xs: "6px",
        sm: "10px",
        md: "14px",
        lg: "18px",
        xl: "24px",
        pill: "999px",
        card: "18px",
      },
      fontFamily: {
        sans: [
          "ui-sans-serif",
          "system-ui",
          "-apple-system",
          "Segoe UI",
          "Roboto",
          "sans-serif",
        ],
      },
      boxShadow: {
        card: "0 1px 2px rgba(36, 54, 75, 0.03)",
      },
    },
  },
  plugins: [],
};

export default config;
