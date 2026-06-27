"use client";

import Link from "next/link";
import { useState } from "react";
import { useRouter } from "next/navigation";
import api from "@/lib/api";
import { readApiError, storefrontId } from "@/lib/ecommerce";

export default function RegisterPage() {
  const router = useRouter();
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError("");
    if (!email.trim() || !password || !firstName.trim()) {
      setError("First name, email, and password are required.");
      return;
    }
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (!storefrontId) {
      setError("Storefront ID is not configured.");
      return;
    }
    setLoading(true);
    try {
      const { data } = await api.post("/ec/auth/register", {
        storefrontId,
        email: email.trim(),
        password,
        firstName: firstName.trim(),
        lastName: lastName.trim() || null,
        phone: phone.trim() || null,
      });
      window.localStorage.setItem("ec_token", data.token);
      router.push("/account/orders");
    } catch (err: unknown) {
      setError(readApiError(err, "Registration failed. Please try again."));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Create ecommerce account</h1>
        <p className="mt-2 text-slate-500">Register with email and password for storefront ordering.</p>
      </div>
      <form className="card grid gap-4 p-6 md:grid-cols-2" onSubmit={handleSubmit}>
        {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600 md:col-span-2">{error}</p>}
        <input
          className="rounded-xl border border-slate-300 px-4 py-3"
          placeholder="First name *"
          value={firstName}
          onChange={(e) => setFirstName(e.target.value)}
          disabled={loading}
        />
        <input
          className="rounded-xl border border-slate-300 px-4 py-3"
          placeholder="Last name"
          value={lastName}
          onChange={(e) => setLastName(e.target.value)}
          disabled={loading}
        />
        <input
          className="rounded-xl border border-slate-300 px-4 py-3 md:col-span-2"
          placeholder="Email *"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={loading}
        />
        <input
          className="rounded-xl border border-slate-300 px-4 py-3"
          placeholder="Phone"
          type="tel"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          disabled={loading}
        />
        <input
          className="rounded-xl border border-slate-300 px-4 py-3"
          placeholder="Password * (min 8 chars)"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          disabled={loading}
        />
        <button className="btn-primary disabled:opacity-60 md:col-span-2" type="submit" disabled={loading}>
          {loading ? "Creating account…" : "Register"}
        </button>
      </form>
      <p className="text-sm text-slate-500">
        Already registered?{" "}
        <Link href="/account/login" className="text-brand">
          Sign in
        </Link>
      </p>
    </div>
  );
}
