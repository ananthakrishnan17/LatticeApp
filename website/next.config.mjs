/** @type {import("next").NextConfig} */
const appBasePath = "/NammaNanban";

const nextConfig = {
  basePath: appBasePath,
  assetPrefix: appBasePath,
  output: "export",
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
