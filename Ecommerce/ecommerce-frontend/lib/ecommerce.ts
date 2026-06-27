export const storeSlug = process.env.NEXT_PUBLIC_STORE_SLUG ?? "default";
export const storefrontId = process.env.NEXT_PUBLIC_STOREFRONT_ID ?? "";

export type UnknownApiError = {
  response?: {
    data?: {
      message?: string;
      error?: string;
    };
  };
  message?: string;
};

export function readApiError(error: unknown, fallback: string) {
  const candidate = error as UnknownApiError;
  return candidate.response?.data?.message ?? candidate.response?.data?.error ?? candidate.message ?? fallback;
}

export function asNumber(value: unknown, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}
