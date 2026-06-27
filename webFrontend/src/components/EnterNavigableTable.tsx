import { useEffect, useRef, type ReactNode } from 'react'
import Table from '@cloudscape-design/components/table'
import type { TableProps } from '@cloudscape-design/components/table'
import { useGridNavigation } from '../context/GridNavigationContext'

interface EnterNavigableTableProps<T> {
  items: ReadonlyArray<T>
  selectedItems: ReadonlyArray<T>
  onSelectionChange: (items: ReadonlyArray<T>) => void
  columnDefinitions: ReadonlyArray<TableProps.ColumnDefinition<T>>
  header?: ReactNode
  empty?: ReactNode
  trackBy?: TableProps.TrackBy<T>
  ariaLabels?: TableProps.AriaLabels<T>
}

const isInteractiveElement = (target: EventTarget | null) => {
  if (!(target instanceof HTMLElement)) {
    return false
  }

  const tagName = target.tagName.toLowerCase()
  if (['input', 'textarea', 'select', 'button'].includes(tagName)) {
    return true
  }

  if (target.closest('[role="button"]') || target.closest('a[href]')) {
    return true
  }

  return target.isContentEditable
}

function EnterNavigableTable<T>({
  items,
  selectedItems,
  onSelectionChange,
  columnDefinitions,
  header,
  empty,
  trackBy,
  ariaLabels,
}: EnterNavigableTableProps<T>) {
  const containerRef = useRef<HTMLDivElement>(null)
  const { keyboardEventKey, navigationKey } = useGridNavigation()

  useEffect(() => {
    const container = containerRef.current
    if (!container) {
      return
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== keyboardEventKey || isInteractiveElement(event.target) || !items.length) {
        return
      }

      event.preventDefault()
      const currentItem = selectedItems[0]
      const currentIndex = currentItem ? items.indexOf(currentItem) : -1
      const nextIndex = currentIndex >= 0 ? (currentIndex + 1) % items.length : 0
      const nextItem = items[nextIndex]

      if (nextItem) {
        onSelectionChange([nextItem])
      }
    }

    container.addEventListener('keydown', handleKeyDown)
    return () => {
      container.removeEventListener('keydown', handleKeyDown)
    }
  }, [items, keyboardEventKey, onSelectionChange, selectedItems])

  return (
    <div ref={containerRef} tabIndex={0} aria-label={`Grid table. Press ${navigationKey} to move selection.`}>
      <Table
        items={items}
        columnDefinitions={columnDefinitions}
        header={header}
        empty={empty}
        trackBy={trackBy}
        ariaLabels={ariaLabels}
        selectionType="single"
        selectedItems={selectedItems}
        onSelectionChange={({ detail }) => onSelectionChange(detail.selectedItems)}
      />
    </div>
  )
}

export default EnterNavigableTable
