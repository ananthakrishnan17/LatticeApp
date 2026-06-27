import { useGridNavigation, type GridNavigationKey } from '../context/GridNavigationContext'

const options = [
  { label: 'Enter key', value: 'Enter' },
  { label: 'Space key', value: 'Space' },
  { label: 'Arrow Right key', value: 'ArrowRight' },
]

function GridNavigationPreferences() {
  const { navigationKey, setNavigationKey } = useGridNavigation()

  return (
    <div style={{ padding: '16px 12px', borderTop: '1px solid var(--layout-border)', marginTop: 'auto' }}>
      <div style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--layout-text-primary)', marginBottom: '8px' }}>
        Grid Navigation Key
      </div>
      <select
        className="pos-input"
        style={{ padding: '6px 10px', fontSize: '0.85rem', borderRadius: '8px' }}
        value={navigationKey}
        onChange={(e) => setNavigationKey(e.target.value as GridNavigationKey)}
      >
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>{opt.label}</option>
        ))}
      </select>
      <div style={{ fontSize: '0.75rem', color: 'var(--layout-text-secondary)', marginTop: '8px', lineHeight: 1.4 }}>
        Select which key moves to the next row in tables and grids.
      </div>
    </div>
  )
}

export default GridNavigationPreferences
