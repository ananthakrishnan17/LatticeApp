"use client";

import { useEffect, useState } from "react";
import api from "@/lib/api";
import { readApiError } from "@/lib/ecommerce";

interface QAItem {
  server_id: string;
  question: string;
  answer?: string;
  answered_at?: string;
  created_at: string;
  customer_name?: string;
}

interface Props {
  listingId: string;
}

export default function ProductQA({ listingId }: Props) {
  const [items, setItems] = useState<QAItem[]>([]);
  const [question, setQuestion] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    api
      .get<QAItem[]>(`/ec/qa/${listingId}`)
      .then((r) => setItems(r.data))
      .catch(() => {});
  }, [listingId]);

  const handleAsk = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError("");
    setSuccess(false);
    try {
      await api.post("/ec/qa", { listingId, question });
      setQuestion("");
      setSuccess(true);
    } catch (err) {
      setError(readApiError(err, "An error occurred"));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <section className="mt-10 border-t pt-8">
      <h2 className="text-xl font-bold mb-4">Questions &amp; Answers</h2>

      {items.length > 0 && (
        <div className="space-y-4 mb-6">
          {items.map((item) => (
            <div key={item.server_id} className="bg-slate-50 rounded-lg p-4">
              <p className="font-semibold text-sm">Q: {item.question}</p>
              <p className="text-xs text-slate-400 mt-0.5">
                Asked by {item.customer_name ?? "Customer"} &middot;{" "}
                {new Date(item.created_at).toLocaleDateString()}
              </p>
              {item.answer ? (
                <p className="mt-2 text-sm text-slate-700">
                  <span className="font-semibold text-indigo-600">A:</span> {item.answer}
                </p>
              ) : (
                <p className="mt-2 text-xs text-slate-400 italic">Awaiting answer from seller.</p>
              )}
            </div>
          ))}
        </div>
      )}

      <form onSubmit={handleAsk} className="space-y-3">
        <p className="text-sm font-medium text-slate-700">Have a question about this product?</p>
        <textarea
          className="input w-full min-h-[80px] resize-none"
          placeholder="Type your question here…"
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          required
        />
        {error && <p className="text-sm text-red-500">{error}</p>}
        {success && (
          <p className="text-sm text-green-600">
            Your question was submitted. We&apos;ll answer it soon!
          </p>
        )}
        <button type="submit" className="btn-secondary" disabled={submitting}>
          {submitting ? "Submitting…" : "Ask a Question"}
        </button>
      </form>
    </section>
  );
}
