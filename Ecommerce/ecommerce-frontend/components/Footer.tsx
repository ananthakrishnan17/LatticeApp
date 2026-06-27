export function Footer() {
  return (
    <footer className="mt-16 border-t border-slate-200 bg-white">
      <div className="container-shell grid gap-6 py-10 text-sm text-slate-600 md:grid-cols-3">
        <div>
          <h3 className="font-semibold text-slate-900">Namma Nanban Ecommerce</h3>
          <p className="mt-2">Fast grocery and essentials ordering for modern neighbourhood stores.</p>
        </div>
        <div>
          <h3 className="font-semibold text-slate-900">Customer care</h3>
          <p className="mt-2">Support, shipping, tracking, and returns are available from the dashboard.</p>
        </div>
        <div>
          <h3 className="font-semibold text-slate-900">Commerce stack</h3>
          <p className="mt-2">Next.js 14 frontend, Spring Boot backend, PostgreSQL, Razorpay, and async notifications.</p>
        </div>
      </div>
    </footer>
  );
}
