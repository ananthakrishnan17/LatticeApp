"use client";

import { useEffect, useState } from "react";

export type AddressValue = {
  fullName: string;
  phone: string;
  addressLine1: string;
  city: string;
  state: string;
  pincode: string;
};

const defaultAddress: AddressValue = {
  fullName: "",
  phone: "",
  addressLine1: "",
  city: "",
  state: "",
  pincode: ""
};

const fieldLabels: Record<keyof AddressValue, string> = {
  fullName: "Full name",
  phone: "Phone",
  addressLine1: "Address line",
  city: "City",
  state: "State",
  pincode: "Pincode"
};

export function AddressForm({ onSubmit, initialValue }: { onSubmit?: (value: AddressValue) => void; initialValue?: AddressValue }) {
  const [value, setValue] = useState<AddressValue>({
    ...defaultAddress,
    ...initialValue
  });

  useEffect(() => {
    if (initialValue) {
      setValue({ ...defaultAddress, ...initialValue });
    }
  }, [initialValue]);

  return (
    <form
      className="grid gap-4 md:grid-cols-2"
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit?.(value);
      }}
    >
      {Object.entries(value).map(([key, currentValue]) => (
        <label key={key} className="text-sm font-medium text-slate-700">
          <span className="mb-2 block">
            {fieldLabels[key as keyof AddressValue]} <span className="text-red-600">*</span>
            <span className="sr-only"> (required)</span>
          </span>
          <input
            value={currentValue}
            onChange={(event) => setValue((state) => ({ ...state, [key]: event.target.value }))}
            className="w-full rounded-xl border border-slate-300 px-4 py-3"
            required
            aria-required="true"
          />
        </label>
      ))}
      <div className="md:col-span-2">
        <button className="btn-secondary" type="submit">Save address</button>
      </div>
    </form>
  );
}
