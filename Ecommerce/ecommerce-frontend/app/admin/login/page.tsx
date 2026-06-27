"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import api from "@/lib/api";
import { readApiError, storefrontId } from "@/lib/ecommerce";

export default function AdminLoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError("");
    if (!username.trim() || !password) {
      setError("Username and password are required.");
      return;
    }
    if (!storefrontId) {
      setError("Storefront ID is not configured.");
      return;
    }
    setLoading(true);
    try {
      const { data } = await api.post("/ec/auth/admin/login", {
        storefrontId,
        username: username.trim(),
        password,
      });
      window.localStorage.setItem("ec_token", data.token);
      // Also set a cookie so the middleware can detect authentication for route protection
      document.cookie = `ec_token=${data.token}; path=/; SameSite=Strict`;
      router.push("/admin/orders");
    } catch (err: unknown) {
      setError(readApiError(err, "Login failed. Check your admin credentials."));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-md space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Admin login</h1>
        <p className="mt-2 text-slate-500">Sign in to the store admin panel.</p>
      </div>
      <form className="card space-y-4 p-6" onSubmit={(e) => void handleSubmit(e)}>
        {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>}
        <input
          className="w-full rounded-xl border border-slate-300 px-4 py-3"
          placeholder="Admin username"
          type="text"
          autoComplete="username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          disabled={loading}
        />
        <input
          className="w-full rounded-xl border border-slate-300 px-4 py-3"
          placeholder="Password"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          disabled={loading}
        />
        <button className="btn-primary w-full disabled:opacity-60" type="submit" disabled={loading}>
          {loading ? "Signing in…" : "Login as admin"}
        </button>
      </form>
    </div>
  );
}
