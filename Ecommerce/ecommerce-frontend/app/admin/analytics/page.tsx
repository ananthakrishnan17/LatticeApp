"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import api from "@/lib/api";
import { storefrontId } from "@/lib/ecommerce";

type Dashboard = {
  total_orders: number;
  total_revenue: number;
  confirmed_orders: number;
  repeat_customers?: number;
  new_customers?: number;
};

type FunnelMetrics = {
  view: number;
  cart_add: number;
  checkout_start: number;
  purchase: number;
};

type SearchTerm = { query: string; count: number };

type CategoryConversion = { category: string; visits: number; purchases: number };

type Cohort = { cohort: string; month1: number; month2: number; month3: number };

const fallbackCategory: CategoryConversion[] = [
  { category: "Groceries", visits: 4200, purchases: 516 },
  { category: "Snacks", visits: 2900, purchases: 301 },
];

const fallbackCohorts: Cohort[] = [
  { cohort: "Jan 2026", month1: 100, month2: 62, month3: 51 },
  { cohort: "Feb 2026", month1: 100, month2: 58, month3: 44 },
];

export default function AdminAnalyticsPage() {
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [funnel, setFunnel] = useState<FunnelMetrics | null>(null);
  const [topSearches, setTopSearches] = useState<SearchTerm[]>([]);
  const [categoryConversion, setCategoryConversion] = useState<CategoryConversion[]>(fallbackCategory);
  const [cohorts, setCohorts] = useState<Cohort[]>(fallbackCohorts);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const sfId = storefrontId;
    Promise.all([
      api.get("/ec/admin/analytics/dashboard"),
      sfId ? api.get(`/ec/admin/analytics/funnel?storefrontId=${sfId}`) : Promise.resolve(null),
      sfId ? api.get<SearchTerm[]>(`/ec/admin/analytics/top-searches?storefrontId=${sfId}&limit=10`) : Promise.resolve(null),
      sfId ? api.get<CategoryConversion[]>(`/ec/admin/analytics/category-conversion?storefrontId=${sfId}`).catch(() => null) : Promise.resolve(null),
      sfId ? api.get<Cohort[]>(`/ec/admin/analytics/cohorts?storefrontId=${sfId}`).catch(() => null) : Promise.resolve(null),
    ])
      .then(([dashRes, funnelRes, searchRes, categoryRes, cohortRes]) => {
        setDashboard(dashRes.data);
        if (funnelRes) setFunnel(funnelRes.data as FunnelMetrics);
        if (searchRes) setTopSearches(searchRes.data);
        if (categoryRes?.data && categoryRes.data.length > 0) setCategoryConversion(categoryRes.data);
        if (cohortRes?.data && cohortRes.data.length > 0) setCohorts(cohortRes.data);
      })
      .catch(() => setError("Failed to load analytics. Ensure you are signed in as admin."))
      .finally(() => setLoading(false));
  }, []);

  const retention = useMemo(() => {
    if (cohorts.length === 0) return 0;
    return Math.round(cohorts.reduce((sum, cohort) => sum + cohort.month3, 0) / cohorts.length);
  }, [cohorts]);

  if (loading) return <p className="text-slate-500">Loading analytics…</p>;
  if (error) return <p className="text-red-600">{error}</p>;

  const repeatCustomers = Number(dashboard?.repeat_customers ?? 0);
  const totalCustomers = repeatCustomers + Number(dashboard?.new_customers ?? 0);
  const repeatRate = totalCustomers > 0 ? Math.round((repeatCustomers / totalCustomers) * 100) : 0;

  const metrics = dashboard
    ? [
        { label: "Revenue", value: `₹${Number(dashboard.total_revenue ?? 0).toLocaleString("en-IN")}` },
        { label: "Orders", value: String(dashboard.total_orders ?? 0) },
        { label: "Confirmed", value: String(dashboard.confirmed_orders ?? 0) },
        { label: "Repeat rate", value: `${repeatRate}%` },
        { label: "Retention (M3)", value: `${retention}%` },
      ]
    : [];

  const funnelSteps = funnel
    ? [
        { label: "Product Views", value: funnel.view, color: "bg-blue-500" },
        { label: "Add to Cart", value: funnel.cart_add, color: "bg-indigo-500" },
        { label: "Checkout Start", value: funnel.checkout_start, color: "bg-purple-500" },
        { label: "Purchases", value: funnel.purchase, color: "bg-green-500" },
      ]
    : [];

  const maxFunnel = funnelSteps.reduce((m, s) => Math.max(m, s.value), 1);

  return (
    <div className="space-y-8">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-3xl font-bold">Admin analytics</h1>
        <div className="flex gap-2 text-sm">
          <Link href="/admin/marketing" className="btn-secondary">Coupons & campaigns</Link>
          <Link href="/admin/inventory" className="btn-secondary">Inventory actions</Link>
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-5">
        {metrics.map((metric) => (
          <div key={metric.label} className="card p-6">
            <p className="text-sm text-slate-500">{metric.label}</p>
            <p className="mt-3 text-3xl font-bold">{metric.value}</p>
          </div>
        ))}
      </div>

      {funnelSteps.length > 0 && (
        <div className="card p-6 space-y-4">
          <h2 className="text-lg font-semibold">Conversion Funnel (Last 30 days)</h2>
          <div className="space-y-3">
            {funnelSteps.map((step, idx) => {
              const pct = maxFunnel > 0 ? Math.round((step.value / maxFunnel) * 100) : 0;
              const conversionRate =
                idx === 0 || funnelSteps[idx - 1].value === 0
                  ? null
                  : Math.round((step.value / funnelSteps[idx - 1].value) * 100);
              return (
                <div key={step.label}>
                  <div className="flex justify-between text-sm mb-1">
                    <span className="font-medium">{step.label}</span>
                    <span className="text-slate-500">
                      {step.value.toLocaleString()}
                      {conversionRate !== null && <span className="ml-2 text-slate-400 text-xs">({conversionRate}% from prev)</span>}
                    </span>
                  </div>
                  <div className="h-3 bg-slate-100 rounded-full overflow-hidden">
                    <div className={`h-full rounded-full ${step.color} transition-all`} style={{ width: `${pct}%` }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="card p-6">
          <h2 className="mb-4 text-lg font-semibold">Coupon effectiveness by category conversion</h2>
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-slate-500">
                <th className="py-2 text-left">Category</th>
                <th className="py-2 text-right">Visits</th>
                <th className="py-2 text-right">Purchases</th>
                <th className="py-2 text-right">Conversion</th>
              </tr>
            </thead>
            <tbody>
              {categoryConversion.map((row) => {
                const conversion = row.visits > 0 ? ((row.purchases / row.visits) * 100).toFixed(1) : "0.0";
                return (
                  <tr key={row.category} className="border-b last:border-0">
                    <td className="py-2">{row.category}</td>
                    <td className="py-2 text-right">{row.visits}</td>
                    <td className="py-2 text-right">{row.purchases}</td>
                    <td className="py-2 text-right">{conversion}%</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="card p-6">
          <h2 className="mb-4 text-lg font-semibold">Cohort retention</h2>
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-slate-500">
                <th className="py-2 text-left">Cohort</th>
                <th className="py-2 text-right">Month 1</th>
                <th className="py-2 text-right">Month 2</th>
                <th className="py-2 text-right">Month 3</th>
              </tr>
            </thead>
            <tbody>
              {cohorts.map((row) => (
                <tr key={row.cohort} className="border-b last:border-0">
                  <td className="py-2">{row.cohort}</td>
                  <td className="py-2 text-right">{row.month1}%</td>
                  <td className="py-2 text-right">{row.month2}%</td>
                  <td className="py-2 text-right">{row.month3}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {topSearches.length > 0 && (
        <div className="card p-6">
          <h2 className="text-lg font-semibold mb-4">Top Search Terms (Last 30 days)</h2>
          <table className="w-full text-sm">
            <thead>
              <tr className="text-slate-500 border-b">
                <th className="text-left py-2">Query</th>
                <th className="text-right py-2">Searches</th>
              </tr>
            </thead>
            <tbody>
              {topSearches.map((term) => (
                <tr key={term.query} className="border-b last:border-0">
                  <td className="py-2">{term.query}</td>
                  <td className="py-2 text-right font-semibold">{term.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
