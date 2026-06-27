"use client";

import Link from "next/link";
import { useState } from "react";
import { useRouter } from "next/navigation";
import api from "@/lib/api";
import { readApiError, storefrontId } from "@/lib/ecommerce";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError("");
    if (!email.trim() || !password) {
      setError("Email and password are required.");
      return;
    }
    if (!storefrontId) {
      setError("Storefront ID is not configured.");
      return;
    }
    setLoading(true);
    try {
      const { data } = await api.post("/ec/auth/login", {
        storefrontId,
        email: email.trim(),
        password,
      });
      window.localStorage.setItem("ec_token", data.token);
      router.push("/account/orders");
    } catch (err: unknown) {
      setError(readApiError(err, "Login failed. Please check your credentials."));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-md space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Customer login</h1>
        <p className="mt-2 text-slate-500">Sign in to your account.</p>
      </div>
      <form className="card space-y-4 p-6" onSubmit={handleSubmit}>
        {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>}
        <input
          className="w-full rounded-xl border border-slate-300 px-4 py-3"
          placeholder="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={loading}
        />
        <input
          className="w-full rounded-xl border border-slate-300 px-4 py-3"
          placeholder="Password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          disabled={loading}
        />
        <button className="btn-primary w-full disabled:opacity-60" type="submit" disabled={loading}>
          {loading ? "Signing in…" : "Login"}
        </button>
      </form>
      <p className="text-sm text-slate-500">
        New here?{" "}
        <Link href="/account/register" className="text-brand">
          Create an account
        </Link>
      </p>
    </div>
  );
}
