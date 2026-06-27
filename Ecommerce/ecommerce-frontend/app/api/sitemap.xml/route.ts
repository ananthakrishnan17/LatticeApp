export async function GET() {
  const base = process.env.NEXT_PUBLIC_API_BASE ?? "https://api.nammananban.in";
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
  <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url><loc>${base}</loc></url>
    <url><loc>${base}/products</loc></url>
    <url><loc>${base}/categories/groceries</loc></url>
  </urlset>`;

  return new Response(xml, {
    headers: {
      "Content-Type": "application/xml"
    }
  });
}
