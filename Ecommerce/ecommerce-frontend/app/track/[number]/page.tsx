"use client";

import { useCallback, useEffect, useState } from "react";
import { OrderTimeline } from "@/components/OrderTimeline";
import api from "@/lib/api";
import { readApiError } from "@/lib/ecommerce";

type TrackingEvent = {
  id: string;
  title: string;
  detail: string;
  at: string;
};

type TrackingPayload = {
  orderNumber: string;
  status: string;
  courierName?: string;
  trackingNumber?: string;
  trackingUrl?: string;
  eta?: string;
  events: TrackingEvent[];
};

const TRACKING_REFRESH_INTERVAL_MS = 30000;
const TWO_DAYS_MS = 2 * 24 * 60 * 60 * 1000;

const fallbackEvents = (orderNumber: string): TrackingPayload => ({
  orderNumber,
  status: "confirmed",
  courierName: "Courier partner will be assigned",
  eta: new Date(Date.now() + TWO_DAYS_MS).toISOString(),
  events: [
    {
      id: "created",
      title: "Order confirmed",
      detail: "Your order has been confirmed and is being prepared.",
      at: new Date().toISOString(),
    },
  ],
});

export default function TrackOrderPage({ params }: { params: { number: string } }) {
  const [payload, setPayload] = useState<TrackingPayload>(() => fallbackEvents(params.number));
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [lastCheckedAt, setLastCheckedAt] = useState<string | null>(null);

  const loadTracking = useCallback(async () => {
    setError("");
    try {
      const endpoints = [`/ec/orders/track/${params.number}`, `/ec/orders/${params.number}`];
      let data: Record<string, unknown> | null = null;
      for (const endpoint of endpoints) {
        try {
          const response = await api.get(endpoint);
          data = response.data as Record<string, unknown>;
          break;
        } catch {
          // try next endpoint
        }
      }
      if (!data) throw new Error("Unable to fetch tracking data");

      const status = String(data.status ?? "confirmed");
      const shipments = Array.isArray(data.shipments) ? data.shipments : [];
      const firstShipment = (shipments[0] ?? {}) as Record<string, unknown>;
      const shipmentEvents = Array.isArray(firstShipment.events) ? firstShipment.events : [];
      const events: TrackingEvent[] = shipmentEvents.length
        ? shipmentEvents.map((entry, index) => ({
            id: String((entry as Record<string, unknown>).id ?? index),
            title: String((entry as Record<string, unknown>).title ?? "Update"),
            detail: String((entry as Record<string, unknown>).detail ?? "Status updated."),
            at: String((entry as Record<string, unknown>).at ?? new Date().toISOString()),
          }))
        : [
            {
              id: "state",
              title: `Order is ${status}`,
              detail: "We will post more shipment scans once courier updates are available.",
              at: String(data.updated_at ?? data.created_at ?? new Date().toISOString()),
            },
          ];

      setPayload({
        orderNumber: String(data.order_number ?? params.number),
        status,
        courierName: String(firstShipment.courier_name ?? "Courier pending"),
        trackingNumber: firstShipment.tracking_number ? String(firstShipment.tracking_number) : undefined,
        trackingUrl: firstShipment.tracking_url ? String(firstShipment.tracking_url) : undefined,
        eta: firstShipment.estimated_delivery ? String(firstShipment.estimated_delivery) : undefined,
        events,
      });
      setLastCheckedAt(new Date().toISOString());
    } catch (err: unknown) {
      setPayload(fallbackEvents(params.number));
      setError(readApiError(err, "Live tracking is temporarily unavailable. Showing latest known status."));
    } finally {
      setLoading(false);
    }
  }, [params.number]);

  useEffect(() => {
    void loadTracking();
    const interval = setInterval(() => {
      void loadTracking();
    }, TRACKING_REFRESH_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [loadTracking]);

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-3xl font-bold">Track order {payload.orderNumber}</h1>
          <p className="mt-2 text-slate-500">Live tracking with courier milestones and ETA updates.</p>
        </div>
        <button type="button" className="btn-secondary" onClick={() => void loadTracking()}>
          Refresh now
        </button>
      </div>
      {error && <p className="rounded-xl bg-amber-50 px-4 py-2 text-sm text-amber-700">{error}</p>}
      <OrderTimeline status={payload.status} />
      <div className="card space-y-2 p-6 text-sm text-slate-600">
        <p>
          Courier: <span className="font-medium text-slate-900">{payload.courierName ?? "Awaiting assignment"}</span>
        </p>
        <p>
          Tracking number: <span className="font-medium text-slate-900">{payload.trackingNumber ?? "Will be shared after shipment creation"}</span>
        </p>
        {payload.eta && <p>Estimated delivery: <span className="font-medium text-slate-900">{new Date(payload.eta).toLocaleString()}</span></p>}
        {payload.trackingUrl && (
          <a href={payload.trackingUrl} target="_blank" rel="noreferrer" className="text-brand">
            Open courier tracking link
          </a>
        )}
        {lastCheckedAt && <p className="text-xs text-slate-400">Last synced: {new Date(lastCheckedAt).toLocaleTimeString()}</p>}
      </div>
      <div className="card p-6">
        <h2 className="font-semibold">Shipment updates</h2>
        <div className="mt-4 space-y-3">
          {loading && <p className="text-sm text-slate-500">Loading updates…</p>}
          {payload.events.map((event) => (
            <div key={event.id} className="rounded-xl border border-slate-200 p-3 text-sm">
              <p className="font-medium">{event.title}</p>
              <p className="text-slate-500">{event.detail}</p>
              <p className="mt-1 text-xs text-slate-400">{new Date(event.at).toLocaleString()}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
