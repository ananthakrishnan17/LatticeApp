"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { readApiError } from "@/lib/ecommerce";

type Prefs = {
  email_enabled: boolean;
  sms_enabled: boolean;
  whatsapp_enabled: boolean;
  order_updates: boolean;
  price_drop_alerts: boolean;
  stock_alerts: boolean;
};

const defaultPrefs: Prefs = {
  email_enabled: true,
  sms_enabled: false,
  whatsapp_enabled: true,
  order_updates: true,
  price_drop_alerts: true,
  stock_alerts: true,
};

export default function NotificationsPage() {
  const [prefs, setPrefs] = useState<Prefs>(defaultPrefs);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    api.get<Prefs>("/ec/account/notification-preferences")
      .then((res) => setPrefs(res.data))
      .catch(() => null)
      .finally(() => setLoading(false));
  }, []);

  const toggle = (key: keyof Prefs) => {
    setPrefs((prev) => ({ ...prev, [key]: !prev[key] }));
    setSaved(false);
  };

  const save = async () => {
    setSaving(true);
    setError("");
    try {
      await api.put("/ec/account/notification-preferences", {
        emailEnabled: prefs.email_enabled,
        smsEnabled: prefs.sms_enabled,
        whatsappEnabled: prefs.whatsapp_enabled,
        orderUpdates: prefs.order_updates,
        priceDropAlerts: prefs.price_drop_alerts,
        stockAlerts: prefs.stock_alerts,
      });
      setSaved(true);
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to save preferences."));
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <p className="text-sm text-slate-400 p-6">Loading…</p>;

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">Notifications</h1>
      {error && <p className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-600">{error}</p>}
      {saved && <p className="rounded-xl bg-emerald-50 px-4 py-3 text-sm text-emerald-700">Preferences saved.</p>}

      <div className="card space-y-3 p-5 text-sm">
        <h2 className="text-lg font-semibold">Delivery channels</h2>
        {(["email_enabled", "sms_enabled", "whatsapp_enabled"] as (keyof Prefs)[]).map((key) => (
          <label key={key} className="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" checked={prefs[key] as boolean} onChange={() => toggle(key)} />
            {key.replace("_enabled", "").toUpperCase()}
          </label>
        ))}
      </div>

      <div className="card space-y-3 p-5 text-sm">
        <h2 className="text-lg font-semibold">Notification preferences</h2>
        <label className="flex items-center gap-2 cursor-pointer">
          <input type="checkbox" checked={prefs.order_updates} onChange={() => toggle("order_updates")} />
          Order milestones &amp; delivery updates
        </label>
        <label className="flex items-center gap-2 cursor-pointer">
          <input type="checkbox" checked={prefs.stock_alerts} onChange={() => toggle("stock_alerts")} />
          Back-in-stock alerts
        </label>
        <label className="flex items-center gap-2 cursor-pointer">
          <input type="checkbox" checked={prefs.price_drop_alerts} onChange={() => toggle("price_drop_alerts")} />
          Price drop alerts
        </label>
      </div>

      <button className="btn-primary" onClick={() => void save()} disabled={saving}>
        {saving ? "Saving…" : "Save preferences"}
      </button>
    </div>
  );
}
