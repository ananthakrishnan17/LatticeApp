"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { readApiError } from "@/lib/ecommerce";

type Ticket = {
  server_id: string;
  subject: string;
  status: "open" | "in_progress" | "resolved";
  admin_note?: string;
  updated_at: string;
};

export default function SupportPage() {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const load = () => {
    api.get<Ticket[]>("/ec/support/tickets")
      .then((res) => setTickets(res.data))
      .catch((err: unknown) => setError(readApiError(err, "Failed to load tickets.")))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const subject = String(formData.get("subject") ?? "").trim();
    const details = String(formData.get("details") ?? "").trim();
    if (!subject) return;
    setSubmitting(true);
    setError("");
    try {
      await api.post("/ec/support/tickets", { subject, details });
      (event.target as HTMLFormElement).reset();
      load();
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to submit ticket."));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">Support tickets</h1>
      {error && <p className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-600">{error}</p>}
      <form className="card grid gap-3 p-5" onSubmit={(e) => void handleSubmit(e)}>
        <h2 className="text-lg font-semibold">Create new ticket</h2>
        <input name="subject" className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Issue summary" required />
        <textarea name="details" className="rounded-xl border border-slate-300 px-3 py-2" rows={4} placeholder="Describe your issue" required />
        <button className="btn-primary" type="submit" disabled={submitting}>{submitting ? "Submitting…" : "Submit ticket"}</button>
      </form>
      {loading ? (
        <p className="text-sm text-slate-400">Loading…</p>
      ) : (
        <div className="space-y-3">
          {tickets.length === 0 && <p className="text-sm text-slate-500">No support tickets yet.</p>}
          {tickets.map((ticket) => (
            <div key={ticket.server_id} className="card p-4 text-sm">
              <p className="font-semibold">{ticket.subject}</p>
              <p className="text-slate-500">Status: {ticket.status} · Updated {new Date(ticket.updated_at).toLocaleString()}</p>
              {ticket.admin_note && <p className="mt-1 text-slate-600">Admin note: {ticket.admin_note}</p>}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
