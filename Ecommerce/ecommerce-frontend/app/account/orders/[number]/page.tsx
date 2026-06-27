"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useParams } from "next/navigation";
import { OrderTimeline } from "@/components/OrderTimeline";
import api from "@/lib/api";
import { asNumber, readApiError } from "@/lib/ecommerce";

type OrderItem = {
  server_id: string;
  product_name: string;
  variant_label?: string;
  qty: number;
  unit_price: number;
  gst_amount: number;
};

type Shipment = {
  server_id?: string;
  courier_name?: string;
  tracking_number?: string;
  tracking_url?: string;
  estimated_delivery?: string;
};

type Refund = {
  status?: string;
  reference?: string;
  updated_at?: string;
};

type OrderDetail = {
  server_id: string;
  order_number: string;
  status: string;
  payment_mode?: string;
  created_at?: string;
  subtotal: number;
  coupon_discount: number;
  shipping_charge: number;
  gst_total: number;
  items: OrderItem[];
  shipments: Shipment[];
  refund?: Refund;
};

const cancellableStatuses = new Set(["pending", "confirmed"]);
const returnableStatuses = new Set(["delivered"]);

export default function OrderDetailPage() {
  const params = useParams<{ number: string }>();
  const orderNumber = params?.number;
  const [order, setOrder] = useState<OrderDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busyAction, setBusyAction] = useState<"cancel" | "return" | null>(null);
  const [reason, setReason] = useState("");

  const loadOrder = useCallback(async () => {
    if (!orderNumber) return;
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get(`/ec/orders/${orderNumber}`);
      setOrder(data);
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to load order details."));
    } finally {
      setLoading(false);
    }
  }, [orderNumber]);

  useEffect(() => {
    void loadOrder();
  }, [loadOrder]);

  const handleAction = async (action: "cancel" | "return") => {
    if (!order) return;
    setBusyAction(action);
    setError("");
    try {
      await api.post(action === "cancel" ? `/ec/orders/${order.server_id}/cancel` : `/ec/orders/${order.server_id}/return-request`, {
        reason: reason.trim() || undefined,
      });
      await loadOrder();
    } catch (err: unknown) {
      setError(readApiError(err, `Failed to ${action} order.`));
    } finally {
      setBusyAction(null);
    }
  };

  const total = useMemo(() => {
    if (!order) return 0;
    return asNumber(order.subtotal) - asNumber(order.coupon_discount) + asNumber(order.shipping_charge);
  }, [order]);

  if (loading) return <p className="text-slate-500">Loading order…</p>;
  if (error) return <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>;
  if (!order) return <p className="text-slate-500">Order not found.</p>;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-3xl font-bold">Order {order.order_number}</h1>
          <p className="mt-2 text-slate-500">Status: <span className="font-semibold">{order.status}</span></p>
          <p className="text-sm text-slate-500">Payment mode: {order.payment_mode ?? "N/A"}</p>
        </div>
        <div className="text-right">
          <p className="text-sm text-slate-500">Order total</p>
          <p className="text-2xl font-bold">₹{total.toFixed(2)}</p>
          <a className="text-sm text-brand" href={`/api/orders/${order.order_number}/invoice`} target="_blank" rel="noreferrer">
            Download invoice
          </a>
        </div>
      </div>

      <OrderTimeline status={order.status} />

      <div className="card space-y-3 p-5">
        <h2 className="font-semibold">Order actions</h2>
        <textarea
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          placeholder="Reason (optional)"
          className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
          rows={3}
        />
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => void handleAction("cancel")}
            disabled={busyAction !== null || !cancellableStatuses.has(order.status)}
            className="btn-secondary disabled:opacity-60"
          >
            {busyAction === "cancel" ? "Requesting…" : "Request cancel"}
          </button>
          <button
            type="button"
            onClick={() => void handleAction("return")}
            disabled={busyAction !== null || !returnableStatuses.has(order.status)}
            className="btn-secondary disabled:opacity-60"
          >
            {busyAction === "return" ? "Requesting…" : "Request return/refund"}
          </button>
          <Link href="/account/support" className="btn-secondary">Need help?</Link>
        </div>
        <p className="text-xs text-slate-500">Cancel is available for pending/confirmed orders, return request for delivered orders.</p>
      </div>

      {order.refund && (
        <div className="card p-6 text-sm">
          <h2 className="font-semibold">Return / refund tracking</h2>
          <p className="mt-2 text-slate-600">Status: {order.refund.status ?? "In progress"}</p>
          {order.refund.reference && <p className="text-slate-600">Reference: {order.refund.reference}</p>}
          {order.refund.updated_at && <p className="text-slate-500">Updated: {new Date(order.refund.updated_at).toLocaleString()}</p>}
        </div>
      )}

      <div className="card p-6">
        <h2 className="font-semibold">Items</h2>
        <div className="mt-4 space-y-3 text-sm text-slate-600">
          {order.items.map((item) => (
            <div key={item.server_id} className="flex justify-between gap-3">
              <span>
                {item.product_name}
                {item.variant_label ? ` (${item.variant_label})` : ""} × {item.qty}
              </span>
              <span>₹{(asNumber(item.unit_price) * asNumber(item.qty)).toFixed(2)}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="card p-6">
        <h2 className="font-semibold">Summary</h2>
        <div className="mt-3 space-y-2 text-sm">
          <div className="flex justify-between"><span>Subtotal</span><span>₹{asNumber(order.subtotal).toFixed(2)}</span></div>
          <div className="flex justify-between"><span>Coupon discount</span><span>-₹{asNumber(order.coupon_discount).toFixed(2)}</span></div>
          <div className="flex justify-between"><span>Shipping</span><span>₹{asNumber(order.shipping_charge).toFixed(2)}</span></div>
          <div className="flex justify-between"><span>GST</span><span>₹{asNumber(order.gst_total).toFixed(2)}</span></div>
          <div className="flex justify-between border-t pt-2 font-semibold"><span>Total</span><span>₹{total.toFixed(2)}</span></div>
        </div>
      </div>

      <div className="card p-6">
        <h2 className="font-semibold">Shipment timeline</h2>
        {order.shipments.length === 0 ? (
          <p className="mt-3 text-sm text-slate-500">Shipment details will appear once your order is dispatched.</p>
        ) : (
          <div className="mt-4 space-y-3 text-sm">
            {order.shipments.map((shipment, index) => (
              <div key={shipment.server_id ?? `shipment-${index}`} className="rounded-xl border border-slate-200 p-3">
                <p className="font-medium">{shipment.courier_name ?? "Courier assigned"}</p>
                <p className="text-slate-500">Tracking number: {shipment.tracking_number ?? "N/A"}</p>
                {shipment.estimated_delivery && <p className="text-slate-500">Estimated delivery: {String(shipment.estimated_delivery)}</p>}
                {shipment.tracking_url && (
                  <a href={shipment.tracking_url} target="_blank" rel="noreferrer" className="text-brand">
                    Open tracking link
                  </a>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
