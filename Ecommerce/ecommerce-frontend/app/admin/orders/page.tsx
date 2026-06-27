"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import api from "@/lib/api";
import { readApiError } from "@/lib/ecommerce";

type Shipment = {
  courier_name?: string;
  tracking_number?: string;
  tracking_url?: string;
};

type Order = {
  server_id: string;
  order_number: string;
  status: string;
  subtotal: number;
  coupon_discount: number;
  shipping_charge: number;
  shipments?: Shipment[];
};

const statuses = ["pending", "confirmed", "packed", "shipped", "delivered", "cancelled"];

export default function AdminOrdersPage() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busyOrderId, setBusyOrderId] = useState<string | null>(null);

  const loadOrders = () => {
    setLoading(true);
    setError("");
    api
      .get("/ec/admin/orders")
      .then((res) => setOrders(res.data))
      .catch((err: unknown) => setError(readApiError(err, "Failed to load orders. Ensure you are signed in as admin.")))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadOrders();
  }, []);

  const updateStatus = async (order: Order, nextStatus: string) => {
    setBusyOrderId(order.server_id);
    setError("");
    try {
      await api.put(`/ec/admin/orders/${order.server_id}`, { status: nextStatus });
      setOrders((prev) => prev.map((entry) => (entry.server_id === order.server_id ? { ...entry, status: nextStatus } : entry)));
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to update order status."));
    } finally {
      setBusyOrderId(null);
    }
  };

  const saveShipment = async (order: Order, form: FormData) => {
    const courierName = String(form.get("courierName") ?? "").trim();
    const trackingNumber = String(form.get("trackingNumber") ?? "").trim();
    const trackingUrl = String(form.get("trackingUrl") ?? "").trim();
    if (!courierName || !trackingNumber) {
      setError("Courier and tracking number are required to create shipment.");
      return;
    }
    setBusyOrderId(order.server_id);
    setError("");
    try {
      await api.post(`/ec/admin/orders/${order.server_id}/shipment`, { courierName, trackingNumber, trackingUrl: trackingUrl || undefined });
      setOrders((prev) =>
        prev.map((entry) =>
          entry.server_id === order.server_id
            ? {
                ...entry,
                status: entry.status === "packed" ? "shipped" : entry.status,
                shipments: [{ courier_name: courierName, tracking_number: trackingNumber, tracking_url: trackingUrl || undefined }],
              }
            : entry
        )
      );
      (document.getElementById(`shipment-form-${order.server_id}`) as HTMLFormElement | null)?.reset();
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to save shipment details."));
    } finally {
      setBusyOrderId(null);
    }
  };

  if (loading) return <p className="text-slate-500">Loading orders…</p>;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-3xl font-bold">Admin orders</h1>
        <div className="flex gap-2 text-sm">
          <Link href="/admin/marketing" className="btn-secondary">Coupons & campaigns</Link>
          <Link href="/admin/analytics" className="btn-secondary">Analytics</Link>
          <Link href="/admin/qa" className="btn-secondary">Q&A moderation</Link>
        </div>
      </div>
      {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>}
      {orders.length === 0 && <p className="text-slate-500">No orders found.</p>}
      <div className="space-y-4">
        {orders.map((order) => {
          const total = (order.subtotal ?? 0) - (order.coupon_discount ?? 0) + (order.shipping_charge ?? 0);
          const shipment = order.shipments?.[0];
          return (
            <div key={order.server_id} className="card space-y-4 p-5">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <p className="font-semibold">{order.order_number}</p>
                  <p className="text-sm text-slate-500">Amount ₹{total.toFixed(2)}</p>
                </div>
                <div className="flex items-center gap-2">
                  <select
                    className="rounded-xl border border-slate-300 px-3 py-2 text-sm"
                    value={order.status}
                    disabled={busyOrderId === order.server_id}
                    onChange={(event) => void updateStatus(order, event.target.value)}
                  >
                    {statuses.map((status) => (
                      <option key={status} value={status}>{status}</option>
                    ))}
                  </select>
                </div>
              </div>

              <form
                id={`shipment-form-${order.server_id}`}
                className="grid gap-2 md:grid-cols-4"
                onSubmit={(event) => {
                  event.preventDefault();
                  void saveShipment(order, new FormData(event.currentTarget));
                }}
              >
                <input name="courierName" placeholder="Courier name" className="rounded-xl border border-slate-300 px-3 py-2 text-sm" defaultValue={shipment?.courier_name ?? ""} />
                <input name="trackingNumber" placeholder="Tracking number" className="rounded-xl border border-slate-300 px-3 py-2 text-sm" defaultValue={shipment?.tracking_number ?? ""} />
                <input name="trackingUrl" placeholder="Tracking URL" className="rounded-xl border border-slate-300 px-3 py-2 text-sm" defaultValue={shipment?.tracking_url ?? ""} />
                <button className="btn-secondary disabled:opacity-60" disabled={busyOrderId === order.server_id} type="submit">
                  {busyOrderId === order.server_id ? "Saving…" : "Create / update shipment"}
                </button>
              </form>

              {shipment && (
                <div className="rounded-xl border border-slate-200 bg-slate-50 p-3 text-sm text-slate-600">
                  Courier {shipment.courier_name ?? "N/A"} · Tracking {shipment.tracking_number ?? "N/A"}
                  {shipment.tracking_url && (
                    <>
                      {" "}·{" "}
                      <a href={shipment.tracking_url} target="_blank" rel="noreferrer" className="text-brand">
                        Open tracking
                      </a>
                    </>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
