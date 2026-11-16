import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Toaster } from "@/components/toast";

export const metadata: Metadata = {
  metadataBase: new URL("https://kiddotasks-app.web.app"),
  title: {
    default: "KiddoTasks | Family Chores and Rewards",
    template: "%s | KiddoTasks",
  },
  description:
    "Make family chores easier. Parents assign missions and rewards; kids earn stars with a simple PIN on a shared device.",
  applicationName: "KiddoTasks",
  verification: { google: "7w7cHQVrCOIQl5IKkiOivW2AnC9ov8fL_ONHNvBX06Q" },
  openGraph: {
    type: "website",
    locale: "en_PH",
    siteName: "KiddoTasks",
    title: "KiddoTasks | Family Chores and Rewards",
    description:
      "Make family chores easier with missions, stars, and rewards that stay in sync across devices.",
    url: "/",
    images: [{ url: "/brand-logo.png", width: 523, height: 530, alt: "KiddoTasks" }],
  },
  twitter: {
    card: "summary",
    title: "KiddoTasks | Family Chores and Rewards",
    description:
      "Make family chores easier with missions, stars, and rewards that stay in sync across devices.",
    images: ["/brand-logo.png"],
  },
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/icon.png", type: "image/png" },
      { url: "/favicon.png", type: "image/png", sizes: "64x64" },
    ],
    apple: [{ url: "/apple-icon.png" }],
  },
};

export const viewport: Viewport = {
  themeColor: "#3978A8",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen font-sans">
        {children}
        <Toaster />
      </body>
    </html>
  );
}
