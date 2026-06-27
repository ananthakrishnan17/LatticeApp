"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import api from "@/lib/api";
import { readApiError, storefrontId } from "@/lib/ecommerce";

type QAThread = {
  server_id: string;
  question: string;
  listing_id: string;
  product_name?: string;
  customer_email?: string;
  answer?: string;
  answered_at?: string;
  is_visible: boolean;
};

export default function AdminQAPage() {
  const [threads, setThreads] = useState<QAThread[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const answerRefs = useRef<Record<string, HTMLTextAreaElement | null>>({});

  const load = useCallback(() => {
    if (!storefrontId) return;
    setLoading(true);
    api.get<QAThread[]>(`/ec/qa/admin/unanswered/${storefrontId}`)
      .then((res) => setThreads(res.data))
      .catch((err: unknown) => setError(readApiError(err, "Failed to load Q&A.")))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => { load(); }, [load]);

  const answerAndApprove = async (thread: QAThread) => {
    const answer = answerRefs.current[thread.server_id]?.value.trim() ?? "";
    if (!answer) { setError("Please type an answer before approving."); return; }
    setBusy(thread.server_id);
    setError("");
    try {
      await api.post(`/ec/qa/${thread.server_id}/answer`, { answer });
      setThreads((prev) => prev.filter((t) => t.server_id !== thread.server_id));
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to save answer."));
    } finally {
      setBusy(null);
    }
  };

  const reject = async (id: string) => {
    setBusy(id);
    setError("");
    try {
      await api.delete(`/ec/qa/${id}`);
      setThreads((prev) => prev.filter((t) => t.server_id !== id));
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to reject question."));
    } finally {
      setBusy(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-3xl font-bold">Q&A moderation</h1>
        <Link href="/admin/orders" className="btn-secondary text-sm">Back to orders</Link>
      </div>
      <p className="text-sm text-slate-500">Moderate product questions and publish validated answers from admin.</p>
      {error && <p className="rounded-xl bg-red-50 px-4 py-3 text-sm text-red-600">{error}</p>}
      {loading ? (
        <p className="text-sm text-slate-400">Loading…</p>
      ) : threads.length === 0 ? (
        <p className="text-sm text-slate-500">No unanswered questions.</p>
      ) : (
        <div className="space-y-4">
          {threads.map((thread) => (
            <div key={thread.server_id} className="card space-y-3 p-5">
              <div>
                <p className="font-semibold">Q: {thread.question}</p>
                <p className="text-xs text-slate-500">
                  {thread.product_name ?? "Product"} · Asked by {thread.customer_email ?? "customer"}
                </p>
              </div>
              <textarea
                ref={(el) => { answerRefs.current[thread.server_id] = el; }}
                defaultValue={thread.answer ?? ""}
                className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
                rows={3}
                placeholder="Type admin answer"
              />
              <div className="flex gap-2 text-sm">
                <button
                  className="btn-secondary disabled:opacity-60"
                  disabled={busy === thread.server_id}
                  onClick={() => void answerAndApprove(thread)}
                >
                  {busy === thread.server_id ? "Saving…" : "Approve & publish"}
                </button>
                <button
                  className="btn-secondary disabled:opacity-60"
                  disabled={busy === thread.server_id}
                  onClick={() => void reject(thread.server_id)}
                >
                  Reject
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
