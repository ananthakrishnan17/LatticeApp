

const nextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**" }
    ]
  },
  experimental: {
    typedRoutes: false
  }
};

export default nextConfig;
