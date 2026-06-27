/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useMemo, useState, type ReactNode } from 'react'

const STORAGE_KEY = 'grid_navigation_key'

export type GridNavigationKey = 'Enter' | 'Space' | 'ArrowRight'

const keyEventMap: Record<GridNavigationKey, string> = {
  Enter: 'Enter',
  Space: ' ',
  ArrowRight: 'ArrowRight',
}

interface GridNavigationContextValue {
  navigationKey: GridNavigationKey
  keyboardEventKey: string
  setNavigationKey: (value: GridNavigationKey) => void
}

const GridNavigationContext = createContext<GridNavigationContextValue | undefined>(undefined)

const getStoredKey = (): GridNavigationKey => {
  const storedValue = localStorage.getItem(STORAGE_KEY)
  if (storedValue === 'Space' || storedValue === 'ArrowRight' || storedValue === 'Enter') {
    return storedValue
  }
  return 'Enter'
}

export function GridNavigationProvider({ children }: { children: ReactNode }) {
  const [navigationKey, setNavigationKeyState] = useState<GridNavigationKey>(() => getStoredKey())

  const setNavigationKey = (value: GridNavigationKey) => {
    localStorage.setItem(STORAGE_KEY, value)
    setNavigationKeyState(value)
  }

  const value = useMemo<GridNavigationContextValue>(() => ({
    navigationKey,
    keyboardEventKey: keyEventMap[navigationKey],
    setNavigationKey,
  }), [navigationKey])

  return <GridNavigationContext.Provider value={value}>{children}</GridNavigationContext.Provider>
}

export const useGridNavigation = () => {
  const context = useContext(GridNavigationContext)
  if (!context) {
    throw new Error('useGridNavigation must be used inside GridNavigationProvider')
  }
  return context
}
