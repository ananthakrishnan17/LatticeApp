"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import api from "@/lib/api";
import { readApiError } from "@/lib/ecommerce";

type LowStockRow = {
  server_id: string;
  name: string;
  stock_quantity: number;
  low_stock_threshold: number;
  waitlist_count: number;
};

export default function AdminInventoryPage() {
  const [rows, setRows] = useState<LowStockRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = () => {
    setLoading(true);
    api.get<LowStockRow[]>("/ec/admin/inventory/low-stock")
      .then((res) => setRows(res.data))
      .catch((err: unknown) => setError(readApiError(err, "Failed to load inventory.")))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const markBackInStock = async (id: string) => {
    try {
      await api.post(`/ec/admin/inventory/${id}/back-in-stock`);
      load();
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to update stock."));
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-3xl font-bold">Inventory merchandising</h1>
        <Link href="/admin/analytics" className="btn-secondary text-sm">Back to analytics</Link>
      </div>
      <p className="text-sm text-slate-500">Prioritize waitlists, trigger back-in-stock campaigns, and suggest substitutes for low-stock items.</p>
      {error && <p className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-600">{error}</p>}
      {loading ? (
        <p className="text-sm text-slate-400">Loading…</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-slate-500">All items are sufficiently stocked.</p>
      ) : (
        <div className="space-y-3">
          {rows.map((row) => (
            <div key={row.server_id} className="card space-y-3 p-5">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <p className="font-semibold">{row.name}</p>
                <span className="text-sm text-amber-600">Stock: {row.stock_quantity} / threshold: {row.low_stock_threshold}</span>
              </div>
              <p className="text-sm text-slate-500">Waitlist: {row.waitlist_count} alert subscriptions</p>
              <div className="flex flex-wrap gap-2 text-sm">
                <button className="btn-secondary" onClick={() => void markBackInStock(row.server_id)}>
                  Mark back in stock (+10)
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
