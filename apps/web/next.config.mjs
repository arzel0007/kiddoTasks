/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Firebase JS SDK ships modern ESM; Next needs it transpiled for the client.
  transpilePackages: ["firebase", "@firebase/app", "@firebase/auth", "@firebase/firestore"],
  eslint: { ignoreDuringBuilds: true },
  typescript: { ignoreBuildErrors: false },
};

export default nextConfig;
