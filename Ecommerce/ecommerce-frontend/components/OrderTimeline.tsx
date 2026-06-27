type OrderTimelineProps = {
  status: string;
};

export function OrderTimeline({ status }: OrderTimelineProps) {
  if (status === "cancel_requested") {
    return (
      <div className="rounded-2xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-700">
        Cancel request submitted. We will notify you once it is reviewed.
      </div>
    );
  }

  if (status === "return_requested") {
    return (
      <div className="rounded-2xl border border-purple-300 bg-purple-50 px-4 py-3 text-sm text-purple-700">
        Return request submitted. Pickup/approval updates will appear soon.
      </div>
    );
  }

  const steps = ["pending", "confirmed", "shipped", "delivered"];
  const activeIndex = Math.max(steps.indexOf(status), 0);

  return (
    <div className="grid gap-3 md:grid-cols-4">
      {steps.map((step, index) => (
        <div key={step} className={`rounded-2xl border px-4 py-3 text-sm ${index <= activeIndex ? "border-brand bg-brand-light text-brand-dark" : "border-slate-200 bg-white text-slate-500"}`}>
          {step}
        </div>
      ))}
    </div>
  );
}
