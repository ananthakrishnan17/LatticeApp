"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { readApiError } from "@/lib/ecommerce";

interface Address {
  server_id: string;
  full_name: string;
  phone: string;
  address_line1: string;
  address_line2?: string;
  city: string;
  state: string;
  pincode: string;
  country: string;
  is_default: boolean;
  label: string;
}

const emptyForm = {
  fullName: "",
  phone: "",
  addressLine1: "",
  addressLine2: "",
  city: "",
  state: "",
  pincode: "",
  country: "India",
  isDefault: false,
  label: "home",
};

export default function AddressesPage() {
  const [addresses, setAddresses] = useState<Address[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<string | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = async () => {
    setLoading(true);
    try {
      const res = await api.get<Address[]>("/ec/addresses");
      setAddresses(res.data);
    } catch {
      // unauthenticated
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void load(); }, []);

  const openAdd = () => {
    setEditing(null);
    setForm(emptyForm);
    setShowForm(true);
    setError("");
  };

  const openEdit = (addr: Address) => {
    setEditing(addr.server_id);
    setForm({
      fullName: addr.full_name,
      phone: addr.phone,
      addressLine1: addr.address_line1,
      addressLine2: addr.address_line2 ?? "",
      city: addr.city,
      state: addr.state,
      pincode: addr.pincode,
      country: addr.country,
      isDefault: addr.is_default,
      label: addr.label,
    });
    setShowForm(true);
    setError("");
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError("");
    try {
      if (editing) {
        await api.put(`/ec/addresses/${editing}`, form);
      } else {
        await api.post("/ec/addresses", form);
      }
      setShowForm(false);
      await load();
    } catch (err) {
      setError(readApiError(err, "An error occurred"));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (id: string) => {
    if (!confirm("Delete this address?")) return;
    await api.delete(`/ec/addresses/${id}`);
    await load();
  };

  const setDefault = async (id: string) => {
    await api.post(`/ec/addresses/${id}/set-default`);
    await load();
  };

  if (loading) return <p className="text-center py-16 text-slate-400">Loading…</p>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Saved Addresses</h1>
        <button className="btn-primary" onClick={openAdd}>+ Add New</button>
      </div>

      {addresses.length === 0 && !showForm && (
        <p className="text-slate-500">No addresses saved yet.</p>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        {addresses.map((addr) => (
          <div key={addr.server_id} className={`card p-4 space-y-1 ${addr.is_default ? "ring-2 ring-indigo-500" : ""}`}>
            {addr.is_default && (
              <span className="text-xs font-semibold text-indigo-600 uppercase">Default</span>
            )}
            <p className="font-semibold">{addr.full_name} <span className="text-xs text-slate-400 capitalize ml-1">[{addr.label}]</span></p>
            <p className="text-sm text-slate-600">{addr.phone}</p>
            <p className="text-sm text-slate-600">
              {addr.address_line1}{addr.address_line2 ? `, ${addr.address_line2}` : ""}
            </p>
            <p className="text-sm text-slate-600">{addr.city}, {addr.state} – {addr.pincode}</p>
            <p className="text-sm text-slate-600">{addr.country}</p>
            <div className="flex gap-3 pt-2">
              <button onClick={() => openEdit(addr)} className="text-sm text-indigo-600 hover:underline">Edit</button>
              {!addr.is_default && (
                <button onClick={() => setDefault(addr.server_id)} className="text-sm text-slate-500 hover:underline">Set Default</button>
              )}
              <button onClick={() => remove(addr.server_id)} className="text-sm text-red-500 hover:underline">Delete</button>
            </div>
          </div>
        ))}
      </div>

      {showForm && (
        <form onSubmit={save} className="card p-6 space-y-4 mt-4">
          <h2 className="font-semibold text-lg">{editing ? "Edit Address" : "New Address"}</h2>
          {error && <p className="text-sm text-red-500">{error}</p>}
          <div className="grid gap-4 sm:grid-cols-2">
            {[
              { id: "fullName", label: "Full Name" },
              { id: "phone", label: "Phone" },
              { id: "addressLine1", label: "Address Line 1" },
              { id: "addressLine2", label: "Address Line 2 (optional)" },
              { id: "city", label: "City" },
              { id: "state", label: "State" },
              { id: "pincode", label: "Pincode" },
              { id: "country", label: "Country" },
            ].map(({ id, label }) => (
              <div key={id}>
                <label className="block text-sm font-medium text-slate-700 mb-1">{label}</label>
                <input
                  className="input w-full"
                  value={form[id as keyof typeof form] as string}
                  onChange={(e) => setForm({ ...form, [id]: e.target.value })}
                  required={!["addressLine2"].includes(id)}
                />
              </div>
            ))}
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Label</label>
              <select
                className="input w-full"
                value={form.label}
                onChange={(e) => setForm({ ...form, label: e.target.value })}
              >
                <option value="home">Home</option>
                <option value="work">Work</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div className="flex items-center gap-2 pt-5">
              <input
                type="checkbox"
                id="isDefault"
                checked={form.isDefault}
                onChange={(e) => setForm({ ...form, isDefault: e.target.checked })}
              />
              <label htmlFor="isDefault" className="text-sm text-slate-700">Set as default</label>
            </div>
          </div>
          <div className="flex gap-3 pt-2">
            <button type="submit" className="btn-primary" disabled={saving}>
              {saving ? "Saving…" : "Save Address"}
            </button>
            <button type="button" className="btn-secondary" onClick={() => setShowForm(false)}>Cancel</button>
          </div>
        </form>
      )}
    </div>
  );
}
