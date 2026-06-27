"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { readApiError, storefrontId } from "@/lib/ecommerce";

interface LoyaltyBalance {
  points: number;
  rupeeValue: string;
  referralCode: string | null;
  referredByCode: string | null;
}

interface Transaction {
  server_id: string;
  points: number;
  type: string;
  description: string;
  created_at: string;
}

export default function LoyaltyPage() {
  const [balance, setBalance] = useState<LoyaltyBalance | null>(null);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [redeemPoints, setRedeemPoints] = useState("");
  const [redeemError, setRedeemError] = useState("");
  const [redeemSuccess, setRedeemSuccess] = useState("");
  const [referralInput, setReferralInput] = useState("");
  const [referralMsg, setReferralMsg] = useState("");
  const [referralError, setReferralError] = useState("");
  const [copied, setCopied] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const [balRes, txRes] = await Promise.all([
        api.get<LoyaltyBalance>("/ec/loyalty"),
        api.get<Transaction[]>("/ec/loyalty/transactions"),
      ]);
      setBalance(balRes.data);
      setTransactions(txRes.data);
    } catch {
      // unauthenticated
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void load(); }, []);

  const generateReferralCode = async () => {
    const res = await api.post<{ referralCode: string }>("/ec/loyalty/referral");
    setBalance((prev) => prev ? { ...prev, referralCode: res.data.referralCode } : prev);
  };

  const handleRedeem = async (e: React.FormEvent) => {
    e.preventDefault();
    setRedeemError("");
    setRedeemSuccess("");
    try {
      const res = await api.post<{ pointsRedeemed: number; discountAmount: string }>("/ec/loyalty/redeem", {
        points: parseInt(redeemPoints),
      });
      setRedeemSuccess(`Redeemed ${res.data.pointsRedeemed} points (₹${res.data.discountAmount} discount generated).`);
      setRedeemPoints("");
      await load();
    } catch (err) {
      setRedeemError(readApiError(err, "An error occurred"));
    }
  };

  const handleApplyReferral = async (e: React.FormEvent) => {
    e.preventDefault();
    setReferralError("");
    setReferralMsg("");
    try {
      const res = await api.post<{ message: string }>("/ec/loyalty/apply-referral", {
        referralCode: referralInput.trim().toUpperCase(),
      });
      setReferralMsg(res.data.message);
      setReferralInput("");
      await load();
    } catch (err) {
      setReferralError(readApiError(err, "An error occurred"));
    }
  };

  const copyCode = () => {
    if (balance?.referralCode) {
      void navigator.clipboard.writeText(balance.referralCode);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  if (loading) return <p className="text-center py-16 text-slate-400">Loading…</p>;
  if (!balance) return <p className="text-center py-16 text-slate-400">Please log in to view your rewards.</p>;

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold">Loyalty &amp; Rewards</h1>

      {/* Balance card */}
      <div className="card p-6 bg-gradient-to-r from-indigo-500 to-purple-600 text-white rounded-2xl">
        <p className="text-sm opacity-80">Points Balance</p>
        <p className="text-5xl font-extrabold mt-1">{balance.points}</p>
        <p className="text-sm opacity-80 mt-1">Worth ₹{balance.rupeeValue}</p>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Redeem points */}
        <div className="card p-6 space-y-4">
          <h2 className="font-semibold text-lg">Redeem Points</h2>
          <p className="text-sm text-slate-500">Minimum 100 points. 1 point = ₹0.10 discount.</p>
          <form onSubmit={handleRedeem} className="flex gap-3">
            <input
              type="number"
              min={100}
              step={1}
              className="input flex-1"
              placeholder="e.g. 200"
              value={redeemPoints}
              onChange={(e) => setRedeemPoints(e.target.value)}
              required
            />
            <button type="submit" className="btn-primary">Redeem</button>
          </form>
          {redeemError && <p className="text-sm text-red-500">{redeemError}</p>}
          {redeemSuccess && <p className="text-sm text-green-600">{redeemSuccess}</p>}
        </div>

        {/* Referral code */}
        <div className="card p-6 space-y-4">
          <h2 className="font-semibold text-lg">Referral Code</h2>
          {balance.referralCode ? (
            <>
              <p className="text-sm text-slate-500">Share your code and earn 50 points per referral.</p>
              <div className="flex gap-3 items-center">
                <span className="font-mono text-xl font-bold text-indigo-600">{balance.referralCode}</span>
                <button onClick={copyCode} className="text-sm text-slate-500 hover:text-indigo-600">
                  {copied ? "Copied!" : "Copy"}
                </button>
              </div>
            </>
          ) : (
            <button onClick={generateReferralCode} className="btn-secondary">Generate Referral Code</button>
          )}

          {!balance.referredByCode && (
            <form onSubmit={handleApplyReferral} className="pt-2 space-y-2">
              <p className="text-sm text-slate-500">Have a friend&apos;s referral code? Apply below for 25 bonus points.</p>
              <div className="flex gap-3">
                <input
                  className="input flex-1"
                  placeholder="Enter referral code"
                  value={referralInput}
                  onChange={(e) => setReferralInput(e.target.value)}
                  required
                />
                <button type="submit" className="btn-secondary">Apply</button>
              </div>
              {referralError && <p className="text-sm text-red-500">{referralError}</p>}
              {referralMsg && <p className="text-sm text-green-600">{referralMsg}</p>}
            </form>
          )}
        </div>
      </div>

      {/* Transaction history */}
      <div className="card p-6">
        <h2 className="font-semibold text-lg mb-4">Points History</h2>
        {transactions.length === 0 ? (
          <p className="text-sm text-slate-400">No transactions yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-slate-500 border-b">
                <th className="text-left py-2">Date</th>
                <th className="text-left py-2">Description</th>
                <th className="text-left py-2">Type</th>
                <th className="text-right py-2">Points</th>
              </tr>
            </thead>
            <tbody>
              {transactions.map((tx) => (
                <tr key={tx.server_id} className="border-b last:border-0">
                  <td className="py-2 text-slate-500">
                    {new Date(tx.created_at).toLocaleDateString()}
                  </td>
                  <td className="py-2">{tx.description}</td>
                  <td className="py-2 capitalize text-slate-500">{tx.type}</td>
                  <td className={`py-2 text-right font-semibold ${tx.points < 0 ? "text-red-500" : "text-green-600"}`}>
                    {tx.points > 0 ? "+" : ""}{tx.points}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
