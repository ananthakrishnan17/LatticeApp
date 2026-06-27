type FilterSidebarProps = {
  activeCategory?: string;
  activeBrand?: string;
};

export function FilterSidebar({ activeCategory, activeBrand }: FilterSidebarProps) {
  const sections = [
    { title: "Categories", values: ["Groceries", "Beverages", "Personal care"] },
    { title: "Brands", values: ["Namma", "Fresh Farms", "Daily Basket"] },
    { title: "Sort", values: ["latest", "price-asc", "price-desc"] }
  ];

  return (
    <aside className="card space-y-5 p-5">
      <div>
        <h2 className="font-semibold">Filters</h2>
        <p className="mt-1 text-sm text-slate-500">Category: {activeCategory ?? "All"} · Brand: {activeBrand ?? "All"}</p>
      </div>
      {sections.map((section) => (
        <div key={section.title}>
          <h3 className="text-sm font-semibold text-slate-900">{section.title}</h3>
          <ul className="mt-2 space-y-2 text-sm text-slate-600">
            {section.values.map((value) => (
              <li key={value} className="rounded-xl bg-slate-50 px-3 py-2">{value}</li>
            ))}
          </ul>
        </div>
      ))}
    </aside>
  );
}
