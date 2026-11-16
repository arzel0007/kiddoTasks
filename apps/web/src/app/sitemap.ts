import type { MetadataRoute } from "next";

const siteUrl = "https://kiddotasks-app.web.app";

export default function sitemap(): MetadataRoute.Sitemap {
  return ["/", "/pricing", "/about", "/how-to", "/blog/kid-pin", "/blog/summer-missions"].map(
    (path) => ({
      url: `${siteUrl}${path}`,
      changeFrequency: path.startsWith("/blog/") ? ("monthly" as const) : ("yearly" as const),
      priority: path === "/" ? 1 : path === "/pricing" ? 0.8 : 0.6,
    })
  );
}
