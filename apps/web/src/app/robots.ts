import type { MetadataRoute } from "next";

const siteUrl = "https://kiddotasks-app.web.app";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: ["/parent", "/kids", "/admin", "/api"],
    },
    sitemap: `${siteUrl}/sitemap.xml`,
  };
}
