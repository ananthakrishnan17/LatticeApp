import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'

const HELD_BILLS_KEY = 'nn_held_bills'
const RESUME_KEY = 'nn_resume_held'

interface HeldBill {
  id: string
  label: string
  cart: Array<{ quantity: number; product: { sellingPrice: number } }>
  customerName: string
  savedAt: string
}

const loadHeldBills = (): HeldBill[] => {
  try {
    const raw = localStorage.getItem(HELD_BILLS_KEY)
    return raw ? (JSON.parse(raw) as HeldBill[]) : []
  } catch {
    return []
  }
}

export default function HeldBillsPage() {
  const navigate = useNavigate()
  const [heldBills, setHeldBills] = useState<HeldBill[]>(() => loadHeldBills())

  const rows = useMemo(() => heldBills.map((bill, index) => ({
    ...bill,
    index: index + 1,
    itemCount: bill.cart.reduce((sum, item) => sum + Number(item.quantity || 0), 0),
    subtotal: bill.cart.reduce((sum, item) => sum + Number(item.quantity || 0) * Number(item.product?.sellingPrice || 0), 0),
  })), [heldBills])

  const removeBill = (id: string) => {
    const next = heldBills.filter((bill) => bill.id !== id)
    setHeldBills(next)
    localStorage.setItem(HELD_BILLS_KEY, JSON.stringify(next))
  }

  const resumeBill = (id: string) => {
    localStorage.setItem(RESUME_KEY, id)
    navigate('/pos')
  }

  return (
    <div className="space-y-6">
      <header className="rounded-3xl border border-indigo-100 bg-white p-6 shadow-sm">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-indigo-600">Billing</p>
        <h1 className="mt-2 text-3xl font-bold text-slate-900">Held Bills</h1>
        <p className="mt-2 text-sm text-slate-500">Resume or clear saved carts from the POS counter.</p>
      </header>

      <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
        {rows.length ? (
          <div className="overflow-x-auto rounded-2xl border border-slate-200">
            <table className="w-full text-sm">
              <thead className="bg-slate-50 text-slate-600">
                <tr>
                  {['#', 'Label', 'Customer', 'Items count', 'Cart subtotal', 'Held at', 'Actions'].map((heading) => (
                    <th key={heading} className="px-4 py-3 text-left font-semibold">{heading}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((bill) => (
                  <tr key={bill.id} className="border-t border-slate-100 text-slate-700">
                    <td className="px-4 py-3">{bill.index}</td>
                    <td className="px-4 py-3 font-semibold text-slate-900">{bill.label}</td>
                    <td className="px-4 py-3">{bill.customerName || 'Walk-in'}</td>
                    <td className="px-4 py-3">{bill.itemCount}</td>
                    <td className="px-4 py-3">₹{bill.subtotal.toFixed(2)}</td>
                    <td className="px-4 py-3">{new Date(bill.savedAt).toLocaleString()}</td>
                    <td className="px-4 py-3">
                      <div className="flex gap-2">
                        <button type="button" onClick={() => resumeBill(bill.id)} className="rounded-xl bg-indigo-600 px-3 py-2 text-xs font-semibold text-white hover:bg-indigo-700">Resume</button>
                        <button type="button" onClick={() => removeBill(bill.id)} className="rounded-xl border border-rose-200 bg-rose-50 px-3 py-2 text-xs font-semibold text-rose-700 hover:bg-rose-100">Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-10 text-center">
            <h2 className="text-lg font-semibold text-slate-900">No held bills</h2>
            <p className="mt-2 text-sm text-slate-500">Held carts from the POS will appear here.</p>
          </div>
        )}
      </section>
    </div>
  )
}
