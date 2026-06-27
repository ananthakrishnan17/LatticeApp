"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import api from "@/lib/api";
import { readApiError, storefrontId } from "@/lib/ecommerce";

type Coupon = {
  server_id: string;
  code: string;
  discount_type: "flat" | "percent";
  discount_value: number;
  min_order_amount: number;
  usage_limit: number;
  usage_count: number;
  valid_from?: string;
  valid_until?: string;
  is_active: boolean;
};

type Campaign = {
  server_id: string;
  name: string;
  banner: string;
  starts_at: string;
  ends_at: string;
  impressions: number;
  clicks: number;
  orders_count: number;
  revenue: number;
};

const today = new Date().toISOString().slice(0, 10);

export default function AdminMarketingPage() {
  const [coupons, setCoupons] = useState<Coupon[]>([]);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [campaignStartDate, setCampaignStartDate] = useState(today);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    Promise.all([
      api.get<Coupon[]>("/ec/admin/coupons").catch(() => ({ data: [] })),
      api.get<Campaign[]>("/ec/admin/campaigns").catch(() => ({ data: [] })),
    ]).then(([couponRes, campaignRes]) => {
      setCoupons(couponRes.data);
      setCampaigns(campaignRes.data);
    }).finally(() => setLoading(false));
  }, []);

  const couponEffectiveness = useMemo(() => {
    if (coupons.length === 0) return 0;
    const active = coupons.filter((c) => c.usage_count > 0).length;
    return Math.round((active / coupons.length) * 100);
  }, [coupons]);

  const handleCouponSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setSaving(true);
    setError("");
    try {
      const { data } = await api.post<Coupon>("/ec/admin/coupons", {
        storefrontId,
        code: String(formData.get("code") ?? "").toUpperCase(),
        discountType: String(formData.get("discountType") ?? "flat"),
        discountValue: Number(formData.get("discountValue") ?? 0),
        minOrderAmount: Number(formData.get("minOrder") ?? 0),
        usageLimit: Number(formData.get("maxUses") ?? 0) || null,
        validFrom: today,
        validUntil: String(formData.get("expiresAt") ?? ""),
        firstOrderOnly: false,
      });
      api.get<Coupon[]>("/ec/admin/coupons").then((res) => setCoupons(res.data)).catch(() => null);
      (event.target as HTMLFormElement).reset();
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to create coupon."));
    } finally {
      setSaving(false);
    }
  };

  const handleCampaignSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setSaving(true);
    setError("");
    try {
      await api.post("/ec/admin/campaigns", {
        storefrontId,
        name: String(formData.get("name") ?? ""),
        banner: String(formData.get("banner") ?? ""),
        startsAt: String(formData.get("startsAt") ?? ""),
        endsAt: String(formData.get("endsAt") ?? ""),
      });
      const res = await api.get<Campaign[]>("/ec/admin/campaigns");
      setCampaigns(res.data);
      (event.target as HTMLFormElement).reset();
      setCampaignStartDate(today);
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to schedule campaign."));
    } finally {
      setSaving(false);
    }
  };

  const deactivateCoupon = async (id: string) => {
    try {
      await api.delete(`/ec/admin/coupons/${id}`);
      setCoupons((prev) => prev.filter((c) => c.server_id !== id));
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to deactivate coupon."));
    }
  };

  const deleteCampaign = async (id: string) => {
    try {
      await api.delete(`/ec/admin/campaigns/${id}`);
      setCampaigns((prev) => prev.filter((c) => c.server_id !== id));
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to delete campaign."));
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-3xl font-bold">Coupons & campaigns</h1>
        <div className="flex gap-2 text-sm">
          <Link href="/admin/orders" className="btn-secondary">Orders</Link>
          <Link href="/admin/analytics" className="btn-secondary">Analytics</Link>
        </div>
      </div>

      {error && <p className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-600">{error}</p>}

      <section className="card space-y-4 p-5">
        <h2 className="text-xl font-semibold">Create coupon</h2>
        <form className="grid gap-3 md:grid-cols-3" onSubmit={(e) => void handleCouponSubmit(e)}>
          <input name="code" className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Code" required />
          <input name="discountValue" type="number" className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Discount value" min={1} required />
          <select name="discountType" className="rounded-xl border border-slate-300 px-3 py-2">
            <option value="flat">Flat ₹</option>
            <option value="percent">Percent %</option>
          </select>
          <input name="minOrder" type="number" className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Minimum order" min={0} required />
          <input name="maxUses" type="number" className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Usage limit" min={1} required />
          <input name="expiresAt" type="date" className="rounded-xl border border-slate-300 px-3 py-2" min={today} required />
          <button className="btn-primary md:col-span-3" type="submit" disabled={saving}>{saving ? "Saving…" : "Save coupon"}</button>
        </form>
        <div className="rounded-xl border border-slate-200 bg-slate-50 p-3 text-sm text-slate-600">
          Coupon effectiveness (redeemed at least once): <span className="font-semibold text-slate-900">{couponEffectiveness}%</span>
        </div>
        {loading ? (
          <p className="text-sm text-slate-400">Loading…</p>
        ) : coupons.length > 0 && (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-slate-500">
                  <th className="py-2 text-left">Code</th>
                  <th className="py-2 text-left">Rule</th>
                  <th className="py-2 text-left">Usage</th>
                  <th className="py-2 text-left">Expires</th>
                  <th className="py-2 text-left"></th>
                </tr>
              </thead>
              <tbody>
                {coupons.map((coupon) => (
                  <tr key={coupon.server_id} className="border-b last:border-0">
                    <td className="py-2 font-semibold">{coupon.code}</td>
                    <td className="py-2">{coupon.discount_type === "percent" ? `${coupon.discount_value}%` : `₹${coupon.discount_value}`} · Min ₹{coupon.min_order_amount ?? 0}</td>
                    <td className="py-2">{coupon.usage_count ?? 0}/{coupon.usage_limit ?? "∞"}</td>
                    <td className="py-2">{coupon.valid_until ?? "—"}</td>
                    <td className="py-2">
                      {coupon.is_active && (
                        <button className="text-xs text-red-500 hover:underline" onClick={() => void deactivateCoupon(coupon.server_id)}>Deactivate</button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="card space-y-4 p-5">
        <h2 className="text-xl font-semibold">Campaign banner scheduling</h2>
        <form className="grid gap-3 md:grid-cols-4" onSubmit={(e) => void handleCampaignSubmit(e)}>
          <input name="name" className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Campaign name" required />
          <input name="banner" className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Banner placement" required />
          <input
            name="startsAt"
            type="date"
            className="rounded-xl border border-slate-300 px-3 py-2"
            min={today}
            value={campaignStartDate}
            onChange={(e) => setCampaignStartDate(e.target.value)}
            required
          />
          <input name="endsAt" type="date" className="rounded-xl border border-slate-300 px-3 py-2" min={campaignStartDate} required />
          <button className="btn-primary md:col-span-4" type="submit" disabled={saving}>{saving ? "Saving…" : "Schedule banner"}</button>
        </form>

        {loading ? (
          <p className="text-sm text-slate-400">Loading…</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-slate-500">
                  <th className="py-2 text-left">Campaign</th>
                  <th className="py-2 text-left">Schedule</th>
                  <th className="py-2 text-right">CTR</th>
                  <th className="py-2 text-right">Orders</th>
                  <th className="py-2 text-right">Revenue</th>
                  <th className="py-2 text-left"></th>
                </tr>
              </thead>
              <tbody>
                {campaigns.map((campaign) => {
                  const ctr = campaign.impressions > 0 ? ((campaign.clicks / campaign.impressions) * 100).toFixed(1) : "0.0";
                  return (
                    <tr key={campaign.server_id} className="border-b last:border-0">
                      <td className="py-2">
                        <p className="font-semibold">{campaign.name}</p>
                        <p className="text-xs text-slate-500">{campaign.banner}</p>
                      </td>
                      <td className="py-2">{campaign.starts_at} → {campaign.ends_at}</td>
                      <td className="py-2 text-right">{ctr}%</td>
                      <td className="py-2 text-right">{campaign.orders_count ?? 0}</td>
                      <td className="py-2 text-right">₹{Number(campaign.revenue ?? 0).toLocaleString("en-IN")}</td>
                      <td className="py-2">
                        <button className="text-xs text-red-500 hover:underline" onClick={() => void deleteCampaign(campaign.server_id)}>Delete</button>
                      </td>
                    </tr>
                  );
                })}
                {campaigns.length === 0 && (
                  <tr><td colSpan={6} className="py-4 text-center text-slate-400">No campaigns yet.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
