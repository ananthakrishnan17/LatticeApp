"use client";

import { useEffect, useMemo, useState } from "react";
import api from "@/lib/api";
import { readApiError, storeSlug } from "@/lib/ecommerce";

type Listing = {
  server_id: string;
  seo_slug: string;
  product_name: string;
  product_id?: string;
  ec_selling_price: number;
  ec_compare_price?: number;
  visibility: string;
  tags?: string[];
};

type FormState = {
  serverId?: string;
  productId: string;
  seoSlug: string;
  sellingPrice: string;
  comparePrice: string;
  tags: string;
  visibility: "public" | "private";
};

type ImageRow = { server_id: string; image_url: string; sort_order: number; is_primary?: boolean };

const defaultForm: FormState = {
  productId: "",
  seoSlug: "",
  sellingPrice: "",
  comparePrice: "",
  tags: "",
  visibility: "public",
};

export default function AdminProductsPage() {
  const [listings, setListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const [imageBusy, setImageBusy] = useState(false);
  const [form, setForm] = useState<FormState>(defaultForm);
  const [selectedListing, setSelectedListing] = useState<Listing | null>(null);
  const [images, setImages] = useState<ImageRow[]>([]);
  const [imageUrlsInput, setImageUrlsInput] = useState("");

  const loadListings = async () => {
    setLoading(true);
    setError("");
    try {
      const { data } = await api.get("/ec/admin/listings");
      setListings(data.items ?? []);
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to load listings. Ensure you are signed in as admin."));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadListings();
  }, []);

  const loadImages = async (seoSlug: string) => {
    try {
      const { data } = await api.get(`/ec/store/${storeSlug}/products/${seoSlug}`);
      if (data.product_id) {
        setForm((prev) => ({ ...prev, productId: String(data.product_id) }));
      }
      setImages((data.images ?? []).map((entry: Record<string, unknown>) => ({
        server_id: String(entry.server_id),
        image_url: String(entry.image_url),
        sort_order: Number(entry.sort_order ?? 0),
        is_primary: Boolean(entry.is_primary),
      })));
    } catch {
      setImages([]);
    }
  };

  const selectForEdit = (listing: Listing) => {
    setSelectedListing(listing);
    setForm({
      serverId: listing.server_id,
      productId: String(listing.product_id ?? ""),
      seoSlug: listing.seo_slug,
      sellingPrice: String(listing.ec_selling_price ?? ""),
      comparePrice: listing.ec_compare_price ? String(listing.ec_compare_price) : "",
      tags: (listing.tags ?? []).join(", "),
      visibility: (listing.visibility as "public" | "private") ?? "public",
    });
    void loadImages(listing.seo_slug);
  };

  const resetForm = () => {
    setSelectedListing(null);
    setForm(defaultForm);
    setImages([]);
    setImageUrlsInput("");
  };

  const submitListing = async () => {
    if (!form.productId || !form.seoSlug || !form.sellingPrice) {
      setError("Product ID, SEO slug and selling price are required.");
      return;
    }
    setSaving(true);
    setError("");
    const payload = {
      productId: form.productId,
      seoSlug: form.seoSlug.trim(),
      sellingPrice: Number(form.sellingPrice),
      comparePrice: form.comparePrice ? Number(form.comparePrice) : null,
      tags: form.tags.split(",").map((tag) => tag.trim()).filter(Boolean),
      visibility: form.visibility,
    };
    try {
      if (form.serverId) {
        await api.put(`/ec/admin/listings/${form.serverId}`, payload);
      } else {
        await api.post("/ec/admin/listings", payload);
      }
      await loadListings();
      resetForm();
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to save listing."));
    } finally {
      setSaving(false);
    }
  };

  const uploadImages = async () => {
    if (!selectedListing) return;
    const imageUrls = imageUrlsInput
      .split("\n")
      .map((entry) => entry.trim())
      .filter(Boolean);
    if (imageUrls.length === 0) return;
    const validUrls = imageUrls.filter((url) => {
      try {
        const parsed = new URL(url);
        return parsed.protocol === "http:" || parsed.protocol === "https:";
      } catch {
        return false;
      }
    });
    if (validUrls.length !== imageUrls.length) {
      setError("One or more image URLs are invalid.");
      return;
    }
    setImageBusy(true);
    setError("");
    try {
      await api.post(`/ec/admin/listings/${selectedListing.server_id}/images`, { imageUrls: validUrls });
      setImageUrlsInput("");
      await loadImages(selectedListing.seo_slug);
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to upload images."));
    } finally {
      setImageBusy(false);
    }
  };

  const reorderImages = async (targetId: string, direction: "up" | "down") => {
    if (!selectedListing) return;
    const currentIndex = images.findIndex((entry) => entry.server_id === targetId);
    if (currentIndex < 0) return;
    const nextIndex = direction === "up" ? currentIndex - 1 : currentIndex + 1;
    if (nextIndex < 0 || nextIndex >= images.length) return;
    const reordered = [...images];
    const [picked] = reordered.splice(currentIndex, 1);
    reordered.splice(nextIndex, 0, picked);
    const payload = {
      items: reordered.map((entry, index) => ({
        imageId: entry.server_id,
        sortOrder: index,
        primary: index === 0,
      })),
    };
    setImageBusy(true);
    try {
      await api.put(`/ec/admin/listings/${selectedListing.server_id}/images/reorder`, payload);
      setImages(
        reordered.map((entry, index) => ({
          ...entry,
          sort_order: index,
          is_primary: index === 0,
        }))
      );
    } catch (err: unknown) {
      setError(readApiError(err, "Failed to reorder images."));
    } finally {
      setImageBusy(false);
    }
  };

  const title = useMemo(() => (form.serverId ? "Edit listing" : "Create listing"), [form.serverId]);

  if (loading) return <p className="text-slate-500">Loading listings…</p>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">Admin products</h1>
        <button className="btn-primary" onClick={resetForm}>Create listing</button>
      </div>
      {error && <p className="rounded-xl bg-red-50 px-4 py-2 text-sm text-red-600">{error}</p>}

      <div className="card space-y-4 p-5">
        <h2 className="text-xl font-semibold">{title}</h2>
        <div className="grid gap-3 md:grid-cols-2">
          <input className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Product ID (UUID)" value={form.productId} onChange={(e) => setForm((v) => ({ ...v, productId: e.target.value }))} />
          <input className="rounded-xl border border-slate-300 px-3 py-2" placeholder="SEO slug" value={form.seoSlug} onChange={(e) => setForm((v) => ({ ...v, seoSlug: e.target.value }))} />
          <input className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Selling price" type="number" value={form.sellingPrice} onChange={(e) => setForm((v) => ({ ...v, sellingPrice: e.target.value }))} />
          <input className="rounded-xl border border-slate-300 px-3 py-2" placeholder="Compare price" type="number" value={form.comparePrice} onChange={(e) => setForm((v) => ({ ...v, comparePrice: e.target.value }))} />
          <input className="rounded-xl border border-slate-300 px-3 py-2 md:col-span-2" placeholder="Tags (comma separated)" value={form.tags} onChange={(e) => setForm((v) => ({ ...v, tags: e.target.value }))} />
          <select className="rounded-xl border border-slate-300 px-3 py-2" value={form.visibility} onChange={(e) => setForm((v) => ({ ...v, visibility: e.target.value as "public" | "private" }))}>
            <option value="public">Public</option>
            <option value="private">Private</option>
          </select>
        </div>
        <div className="flex gap-2">
          <button className="btn-primary disabled:opacity-60" disabled={saving} onClick={() => void submitListing()}>
            {saving ? "Saving…" : form.serverId ? "Update listing" : "Create listing"}
          </button>
          {form.serverId && <button className="btn-secondary" onClick={resetForm}>Cancel edit</button>}
        </div>
      </div>

      {selectedListing && (
        <div className="card space-y-4 p-5">
          <h2 className="text-xl font-semibold">Listing images · {selectedListing.seo_slug}</h2>
          <textarea
            className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
            rows={3}
            placeholder="Paste image URLs, one per line"
            value={imageUrlsInput}
            onChange={(event) => setImageUrlsInput(event.target.value)}
          />
          <button className="btn-secondary disabled:opacity-60" disabled={imageBusy} onClick={() => void uploadImages()}>
            {imageBusy ? "Uploading…" : "Upload images"}
          </button>
          {images.length > 0 && (
            <div className="space-y-2">
              {images.map((image, index) => (
                <div key={image.server_id} className="flex items-center justify-between rounded-xl border border-slate-200 p-3 text-sm">
                  <div className="min-w-0">
                    <p className="truncate">{image.image_url}</p>
                    <p className="text-xs text-slate-500">{index === 0 ? "Primary image" : `Sort order ${index}`}</p>
                  </div>
                  <div className="flex gap-2">
                    <button className="btn-secondary" disabled={imageBusy || index === 0} onClick={() => void reorderImages(image.server_id, "up")}>↑</button>
                    <button className="btn-secondary" disabled={imageBusy || index === images.length - 1} onClick={() => void reorderImages(image.server_id, "down")}>↓</button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {listings.length === 0 && <p className="text-slate-500">No listings found.</p>}
      <div className="grid gap-4">
        {listings.map((listing) => (
          <button key={listing.server_id} className="card flex items-center justify-between p-5 text-left hover:border-brand" onClick={() => selectForEdit(listing)}>
            <div>
              <h2 className="font-semibold">{listing.product_name}</h2>
              <p className="text-sm text-slate-500">
                SEO slug: {listing.seo_slug} · {listing.visibility}
              </p>
            </div>
            <span className="font-semibold">₹{Number(listing.ec_selling_price).toFixed(2)}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
