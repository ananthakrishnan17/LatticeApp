import Link from "next/link";
import { ShoppingCart } from "lucide-react";

export function Navbar() {
  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="container-shell flex items-center justify-between py-4">
        <Link href="/" className="text-xl font-bold text-brand">
          Namma Nanban Store
        </Link>
        <nav className="flex items-center gap-5 text-sm font-medium text-slate-600">
          <Link href="/products">Products</Link>
          <Link href="/search">Search</Link>
          <Link href="/account/dashboard">Account</Link>
          <Link href="/account/notifications">Alerts</Link>
          <Link href="/admin/orders">Admin</Link>
          <Link href="/cart" className="inline-flex items-center gap-2 rounded-full bg-slate-100 px-4 py-2">
            <ShoppingCart className="h-4 w-4" /> Cart
          </Link>
        </nav>
      </div>
    </header>
  );
}
