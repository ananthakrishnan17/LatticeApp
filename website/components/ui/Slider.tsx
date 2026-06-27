"use client";

type SliderProps = {
  min: number;
  max: number;
  step?: number;
  value: number;
  onChange: (v: number) => void;
  label: string;
  formatValue?: (v: number) => string;
};

export function Slider({
  min,
  max,
  step = 1,
  value,
  onChange,
  label,
  formatValue,
}: SliderProps) {
  const pct = ((value - min) / (max - min)) * 100;

  return (
    <div>
      <div className="mb-2 flex items-center justify-between">
        <span className="text-sm text-silver">{label}</span>
        <span className="text-sm font-semibold text-ctaGold">
          {formatValue ? formatValue(value) : value}
        </span>
      </div>
      <div className="relative h-2 w-full rounded-full bg-white/10">
        <div
          className="absolute inset-y-0 left-0 rounded-full bg-gradient-to-r from-ctaGold to-yellow-300"
          style={{ width: `${pct}%` }}
        />
        <input
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          aria-label={label}
          className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
        />
      </div>
    </div>
  );
}
