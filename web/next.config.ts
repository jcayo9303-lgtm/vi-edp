import type { NextConfig } from "next";

// Sitio 100 % estático (Netlify): los datos vienen de Supabase desde el navegador.
const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
