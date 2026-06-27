import Alert from '@cloudscape-design/components/alert'
import Box from '@cloudscape-design/components/box'
import Table from '@cloudscape-design/components/table'
import type { TableProps } from '@cloudscape-design/components/table'
import { useEffect, useMemo, useState } from 'react'
import { listBills } from '../../api/bills'
import { extractApiError } from '../../api/client'
import { listProducts } from '../../api/products'
import { listPurchases } from '../../api/purchases'
import Spinner from '../../components/Spinner'
import type { ProductResponse } from '../../types'
import {
  CsvButton,
  MetricCards,
  ReportPageShell,
} from './reportCloudscape'
import { currencyFormatter, downloadCsv } from './reportCloudscapeUtils'

interface ProductMeta {
  wholesalePrice?: string
  wholesaleQty?: string
  multiUoms?: string
}

interface PurchaseRow {
  items?: Array<{ product_name?: string; quantity?: number }>
}

interface WholesaleRetailRow {
  productName: string
  conversion: number
  remainingStock: string
  purchasedWholesale: number
  wholesaleSold: number
  retailSold: number
  wholesalePrice: number
  retailPrice: number
}

function loadProductMeta() {
  try {
    const raw = localStorage.getItem('nn_product_meta')
    return raw ? (JSON.parse(raw) as Record<string, ProductMeta>) : {}
  } catch {
    return {}
  }
}

function formatMixedStock(stockQuantity: number, conversion: number) {
  if (conversion <= 1) {
    return `${stockQuantity.toFixed(2)} units`
  }
  const wholesaleUnits = Math.floor(stockQuantity / conversion)
  const retailUnits = Number((stockQuantity - wholesaleUnits * conversion).toFixed(2))
  return `${wholesaleUnits} bag + ${retailUnits} retail`
}

function WholesaleRetailStockPage() {
  const [products, setProducts] = useState<ProductResponse[]>([])
  const [bills, setBills] = useState<Awaited<ReturnType<typeof listBills>>>([])
  const [purchases, setPurchases] = useState<PurchaseRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      setLoading(true)
      setError('')
      try {
        const [productRows, billRows, purchaseRows] = await Promise.all([
          listProducts(),
          listBills({ limit: 10000 }),
          listPurchases({ limit: 10000 }) as Promise<PurchaseRow[]>,
        ])
        if (!cancelled) {
          setProducts(productRows)
          setBills(billRows)
          setPurchases(purchaseRows)
        }
      } catch (err) {
        if (!cancelled) {
          setError(extractApiError(err))
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }
    void load()
    return () => {
      cancelled = true
    }
  }, [])

  const rows = useMemo(() => {
    const meta = loadProductMeta()
    const reportRows: WholesaleRetailRow[] = []

    for (const product of products) {
      const productMeta = meta[product.clientRecordId] ?? {}
      const conversion = Number(productMeta.wholesaleQty ?? 0)
      if (!(conversion > 1)) continue

      const wholesaleSold = bills
        .flatMap((bill) => bill.items.map((item) => ({ billType: bill.bill_type ?? 'retail', item })))
        .filter(({ item }) => item.product_name === product.name)
        .reduce((sum, { billType, item }) => sum + (billType === 'wholesale' ? item.quantity : 0), 0)

      const retailSold = bills
        .flatMap((bill) => bill.items.map((item) => ({ billType: bill.bill_type ?? 'retail', item })))
        .filter(({ item }) => item.product_name === product.name)
        .reduce((sum, { billType, item }) => sum + (billType === 'wholesale' ? 0 : item.quantity), 0)

      const purchasedWholesale = purchases
        .flatMap((purchase) => purchase.items ?? [])
        .filter((item) => item.product_name === product.name)
        .reduce((sum, item) => sum + Number(item.quantity ?? 0), 0)

      reportRows.push({
        productName: product.name,
        conversion,
        remainingStock: formatMixedStock(product.stockQuantity, conversion),
        purchasedWholesale,
        wholesaleSold,
        retailSold,
        wholesalePrice: Number(productMeta.wholesalePrice ?? 0),
        retailPrice: product.sellingPrice,
      })
    }

    return reportRows.sort((left, right) => left.productName.localeCompare(right.productName))
  }, [bills, products, purchases])

  const columnDefinitions: ReadonlyArray<TableProps.ColumnDefinition<WholesaleRetailRow>> = [
    { id: 'product', header: 'Product', cell: (item) => item.productName },
    { id: 'conversion', header: 'Conversion', cell: (item) => `1 bag = ${item.conversion} retail` },
    { id: 'remaining', header: 'Remaining stock', cell: (item) => item.remainingStock },
    { id: 'purchased', header: 'Purchased', cell: (item) => item.purchasedWholesale.toFixed(2) },
    { id: 'wholesaleSold', header: 'Wholesale sold', cell: (item) => item.wholesaleSold.toFixed(2) },
    { id: 'retailSold', header: 'Retail sold', cell: (item) => item.retailSold.toFixed(2) },
    { id: 'wholesalePrice', header: 'Wholesale price', cell: (item) => currencyFormatter.format(item.wholesalePrice) },
    { id: 'retailPrice', header: 'Retail price', cell: (item) => currencyFormatter.format(item.retailPrice) },
  ]

  const totalWholesaleSold = useMemo(() => rows.reduce((sum, row) => sum + row.wholesaleSold, 0), [rows])
  const totalRetailSold = useMemo(() => rows.reduce((sum, row) => sum + row.retailSold, 0), [rows])

  if (loading) {
    return <Spinner label="Loading wholesale/retail report..." />
  }

  return (
    <ReportPageShell
      title="Wholesale / Retail Stock"
      description="Stock and sales split for products configured with bag-to-retail conversion."
      actions={(
        <CsvButton
          onClick={() => downloadCsv(
            'wholesale-retail-stock.csv',
            ['Product', 'Conversion', 'Remaining Stock', 'Purchased', 'Wholesale Sold', 'Retail Sold', 'Wholesale Price', 'Retail Price'],
            rows.map((row) => [
              row.productName,
              `1 bag = ${row.conversion} retail`,
              row.remainingStock,
              row.purchasedWholesale.toFixed(2),
              row.wholesaleSold.toFixed(2),
              row.retailSold.toFixed(2),
              row.wholesalePrice.toFixed(2),
              row.retailPrice.toFixed(2),
            ]),
          )}
        />
      )}
    >
      {error ? <Alert type="error">{error}</Alert> : null}
      <MetricCards
        items={[
          { label: 'Products configured', value: String(rows.length) },
          { label: 'Wholesale sold', value: totalWholesaleSold.toFixed(2) },
          { label: 'Retail sold', value: totalRetailSold.toFixed(2) },
          { label: 'Avg wholesale price', value: currencyFormatter.format(rows.length ? rows.reduce((sum, row) => sum + row.wholesalePrice, 0) / rows.length : 0) },
        ]}
      />
      <Table
        items={rows}
        columnDefinitions={columnDefinitions}
        loadingText="Loading stock report"
        empty={<Box color="text-body-secondary">No wholesale products found. Configure wholesale qty in product metadata.</Box>}
        header={<Box variant="h3">Wholesale / retail stock breakdown</Box>}
      />
    </ReportPageShell>
  )
}

export default WholesaleRetailStockPage
