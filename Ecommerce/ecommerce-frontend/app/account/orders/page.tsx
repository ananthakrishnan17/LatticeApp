"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import api from "@/lib/api";
import { readApiError } from "@/lib/ecommerce";

type Order = {
  server_id: string;
  order_number: string;
  status: string;
  subtotal: number;
  coupon_discount: number;
  shipping_charge: number;
};

export default function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reorderBusy, setReorderBusy] = useState<string | null>(null);

  useEffect(() => {
    api
      .get("/ec/orders")
      .then((res) => setOrders(res.data))
      .catch((err: unknown) => setError(readApiError(err, "Failed to load orders. Please sign in.")))
      .finally(() => setLoading(false));
  }, []);

  const reorder = async (order: Order) => {
    setReorderBusy(order.server_id);
    setError("");
    try {
      await api.post(`/ec/orders/${order.server_id}/reorder`);
      setError("");
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to reorder. Please try from order detail."));
    } finally {
      setReorderBusy(null);
    }
  };

  if (loading) return <p className="text-slate-500">Loading orders…</p>;
  if (error) return <p className="text-red-600">{error}</p>;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-3xl font-bold">Orders</h1>
        <Link href="/account/support" className="btn-secondary text-sm">Support tickets</Link>
      </div>
      {orders.length === 0 && <p className="text-slate-500">No orders yet.</p>}
      <div className="space-y-4">
        {orders.map((order) => {
          const total = (order.subtotal ?? 0) - (order.coupon_discount ?? 0) + (order.shipping_charge ?? 0);
          return (
            <div key={order.server_id} className="card flex flex-wrap items-center justify-between gap-3 p-5">
              <Link href={`/account/orders/${order.order_number}`} className="min-w-0 flex-1">
                <p className="font-semibold">{order.order_number}</p>
                <p className="text-sm text-slate-500">Status: {order.status}</p>
              </Link>
              <span className="font-semibold">₹{total.toFixed(2)}</span>
              <button className="btn-secondary text-sm disabled:opacity-60" onClick={() => void reorder(order)} disabled={reorderBusy === order.server_id}>
                {reorderBusy === order.server_id ? "Adding…" : "Reorder"}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
