import { generateUUID } from '../utils/uuid'
import { useMemo, useState } from 'react'
import { STORAGE_KEYS } from '../api/client'
import type { PrinterSettings, ShopInfoSettings } from '../types'

const KEY = 'nn_receipt_profiles'

interface ReceiptProfile {
  id: string
  name: string
  printer: PrinterSettings
  shop: ShopInfoSettings
}

const load = () => {
  try {
    const raw = localStorage.getItem(KEY)
    return raw ? (JSON.parse(raw) as ReceiptProfile[]) : []
  } catch {
    return []
  }
}

const parseJson = <T,>(key: string, fallback: T) => {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

function ReceiptProfilesPage() {
  const [profiles, setProfiles] = useState<ReceiptProfile[]>(() => load())
  const [activeId, setActiveId] = useState<string>('')
  const [profileName, setProfileName] = useState('')

  const printer = parseJson<PrinterSettings>(STORAGE_KEYS.printerSettings, {
    paperSize: '80mm',
    showGstin: true,
    headerText: '',
    footerText: 'Thank you for your purchase!',
  })
  const shop = parseJson<ShopInfoSettings>(STORAGE_KEYS.shopInfo, {
    shopName: '',
    address: '',
    phone: '',
    email: '',
    gstin: '',
    footerNote: '',
  })

  const active = useMemo(() => profiles.find((p) => p.id === activeId), [activeId, profiles])

  const save = () => {
    if (!profileName.trim()) return
    const next = [{ id: generateUUID(), name: profileName.trim(), printer, shop }, ...profiles]
    setProfiles(next)
    localStorage.setItem(KEY, JSON.stringify(next))
    setProfileName('')
    setActiveId(next[0].id)
  }

  const applyProfile = (profile: ReceiptProfile) => {
    localStorage.setItem(STORAGE_KEYS.printerSettings, JSON.stringify(profile.printer))
    localStorage.setItem(STORAGE_KEYS.shopInfo, JSON.stringify(profile.shop))
    setActiveId(profile.id)
  }

  const previewProfile = active ?? { id: 'live', name: 'Current Draft', printer, shop }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Receipt Template Preview + Print Profiles</h1>
        <p className="mt-1 text-sm text-slate-500">Save multiple print profiles and preview receipt output.</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-[1fr_1.1fr]">
        <section className="rounded-2xl bg-white p-5 ring-1 ring-slate-200 space-y-3">
          <h2 className="text-lg font-semibold text-slate-900">Profiles</h2>
          <div className="flex gap-2">
            <input value={profileName} onChange={(e) => setProfileName(e.target.value)} placeholder="Profile name" className="flex-1 rounded-xl border border-slate-200 px-3 py-2 text-sm" />
            <button type="button" onClick={save} className="rounded-xl bg-indigo-600 px-4 py-2 text-sm font-semibold text-white">Save current</button>
          </div>
          <div className="space-y-2">
            {profiles.map((profile) => (
              <button key={profile.id} type="button" onClick={() => applyProfile(profile)} className={`w-full rounded-xl border px-3 py-2 text-left ${activeId === profile.id ? 'border-indigo-300 bg-indigo-50' : 'border-slate-200'}`}>
                <p className="font-semibold text-slate-900">{profile.name}</p>
                <p className="text-xs text-slate-500">{profile.printer.paperSize} · GSTIN {profile.printer.showGstin ? 'ON' : 'OFF'}</p>
              </button>
            ))}
            {!profiles.length ? <p className="text-sm text-slate-500">No saved profiles yet.</p> : null}
          </div>
        </section>

        <section className="rounded-2xl bg-white p-5 ring-1 ring-slate-200">
          <h2 className="text-lg font-semibold text-slate-900">Live preview ({previewProfile.printer.paperSize})</h2>
          <div className="mt-4 rounded-xl border border-dashed border-slate-300 bg-slate-50 p-4 text-sm">
            <p className="text-center font-bold">{previewProfile.shop.shopName || 'Shop Name'}</p>
            <p className="text-center text-xs text-slate-500">{previewProfile.shop.address || 'Address line'}</p>
            {previewProfile.printer.showGstin ? <p className="text-center text-xs text-slate-500">GSTIN: {previewProfile.shop.gstin || 'N/A'}</p> : null}
            <hr className="my-3 border-slate-300" />
            <p>1 × Sample Product ............ ₹120.00</p>
            <p>2 × Test Item .................. ₹300.00</p>
            <hr className="my-3 border-slate-300" />
            <p className="font-semibold">TOTAL: ₹420.00</p>
            {previewProfile.printer.headerText ? <p className="mt-3 text-xs">{previewProfile.printer.headerText}</p> : null}
            <p className="mt-3 text-xs">{previewProfile.printer.footerText || previewProfile.shop.footerNote}</p>
          </div>
        </section>
      </div>
    </div>
  )
}

export default ReceiptProfilesPage
