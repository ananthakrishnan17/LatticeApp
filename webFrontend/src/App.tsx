import { Navigate, Route, Routes } from 'react-router-dom'
import Layout from './components/Layout'
import ProtectedRoute from './components/ProtectedRoute'
import Spinner from './components/Spinner'
import { useAuth } from './context/AuthContext'
import AuditLogPage from './pages/AuditLogPage'
import BillHistoryPage from './pages/BillHistoryPage'
import BillViewPage from './pages/BillViewPage'
import BootstrapPage from './pages/BootstrapPage'
import CouponsPage from './pages/CouponsPage'
import CustomersLoyaltyPage from './pages/CustomersLoyaltyPage'
import DashboardPage from './pages/DashboardPage'
import OwnerDashboardPage from './pages/OwnerDashboardPage'
import DayClosePage from './pages/DayClosePage'
import ExpensesPage from './pages/ExpensesPage'
import HeldBillsPage from './pages/HeldBillsPage'
import InventoryAlertsPage from './pages/InventoryAlertsPage'
import LoginPage from './pages/LoginPage'
import MastersPage from './pages/MastersPage'
import OrgManagementPage from './pages/OrgManagementPage'
import POSPage from './pages/POSPage'
import ProductsPage from './pages/ProductsPage'
import PurchasePage from './pages/PurchasePage'
import PurchaseReturnPage from './pages/PurchaseReturnPage'
import ReceiptProfilesPage from './pages/ReceiptProfilesPage'
import ReportsPage from './pages/ReportsPage'
import SaleReturnPage from './pages/SaleReturnPage'
import SettingsPage from './pages/SettingsPage'
import SubscriptionLockPage from './pages/SubscriptionLockPage'
import SubscriptionPage from './pages/SubscriptionPage'
import SupplierLedgerPage from './pages/SupplierLedgerPage'
import UsersPage from './pages/UsersPage'
import BillwiseReportPage from './pages/reports/BillwiseReportPage'
import BankBookPage from './pages/reports/BankBookPage'
import CashBookPage from './pages/reports/CashBookPage'
import CancelledBillReportPage from './pages/reports/CancelledBillReportPage'
import CashierSessionsDashboardPage from './pages/reports/CashierSessionsDashboardPage'
import CashierSalesReportPage from './pages/reports/CashierSalesReportPage'
import CashInHandPage from './pages/reports/CashInHandPage'
import CategoryStockPage from './pages/reports/CategoryStockPage'
import CrmPointsPage from './pages/reports/CrmPointsPage'
import CustomerCreditStatementPage from './pages/reports/CustomerCreditStatementPage'
import CustomerBalancePage from './pages/reports/CustomerBalancePage'
import CustomerPurchaseHistoryPage from './pages/reports/CustomerPurchaseHistoryPage'
import DayBookPage from './pages/reports/DayBookPage'
import DayWiseProfitPage from './pages/reports/DayWiseProfitPage'
import GstReportPage from './pages/reports/GstReportPage'
import HourlySalesReportPage from './pages/reports/HourlySalesReportPage'
import ItemWiseSalesPage from './pages/reports/ItemWiseSalesPage'
import LedgerDashboardPage from './pages/reports/LedgerDashboardPage'
import ModifiedBillReportPage from './pages/reports/ModifiedBillReportPage'
import MovingProductsPage from './pages/reports/MovingProductsPage'
import PaymentMethodWisePage from './pages/reports/PaymentMethodWisePage'
import PendingDuesPage from './pages/reports/PendingDuesPage'
import ProductStockHistoryPage from './pages/reports/ProductStockHistoryPage'
import ProductStockSalesPage from './pages/reports/ProductStockSalesPage'
import ProfitLossPage from './pages/reports/ProfitLossPage'
import PurchaseReportPage from './pages/reports/PurchaseReportPage'
import SalesByBillPage from './pages/reports/SalesByBillPage'
import StockLedgerPage from './pages/reports/StockLedgerPage'
import SupplierBalancePage from './pages/reports/SupplierBalancePage'
import TopCustomersPage from './pages/reports/TopCustomersPage'
import WholesaleRetailStockPage from './pages/reports/WholesaleRetailStockPage'

function HomeRedirect() {
  const { isAuthenticated, loading } = useAuth()

  if (loading) {
    return <Spinner fullScreen label="Loading workspace..." />
  }

  return <Navigate replace to={isAuthenticated ? '/pos' : '/login'} />
}

function App() {
  return (
    <Routes>
      <Route path="/" element={<HomeRedirect />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/bootstrap" element={<BootstrapPage />} />
      <Route path="/subscription-expired" element={<ProtectedRoute><SubscriptionLockPage /></ProtectedRoute>} />

      <Route element={<ProtectedRoute />}>
        <Route element={<Layout />}>
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/owner-dashboard" element={<ProtectedRoute adminOnly><OwnerDashboardPage /></ProtectedRoute>} />
          <Route path="/pos" element={<POSPage />} />
          <Route path="/held-bills" element={<HeldBillsPage />} />
          <Route path="/bill-view/:billId" element={<BillViewPage />} />
          <Route path="/products" element={<ProtectedRoute requiredPermission="canManageProducts"><ProductsPage /></ProtectedRoute>} />
          <Route path="/purchase" element={<ProtectedRoute requiredPermission="canManagePurchase"><PurchasePage /></ProtectedRoute>} />
          <Route path="/sale-return" element={<SaleReturnPage />} />
          <Route path="/purchase-return" element={<ProtectedRoute requiredPermission="canManagePurchase"><PurchaseReturnPage /></ProtectedRoute>} />
          <Route path="/day-close" element={<DayClosePage />} />
          <Route path="/reports" element={<ProtectedRoute requiredPermission="canViewReports"><ReportsPage /></ProtectedRoute>} />
          <Route path="/reports/billwise" element={<ProtectedRoute requiredPermission="canViewReports"><BillwiseReportPage /></ProtectedRoute>} />
          <Route path="/reports/hourly-sales" element={<ProtectedRoute requiredPermission="canViewReports"><HourlySalesReportPage /></ProtectedRoute>} />
          <Route path="/reports/gst" element={<ProtectedRoute requiredPermission="canViewReports"><GstReportPage /></ProtectedRoute>} />
          <Route path="/reports/cancelled-bills" element={<ProtectedRoute requiredPermission="canViewReports"><CancelledBillReportPage /></ProtectedRoute>} />
          <Route path="/reports/sales-by-bill" element={<ProtectedRoute requiredPermission="canViewReports"><SalesByBillPage /></ProtectedRoute>} />
          <Route path="/reports/modified-bills" element={<ProtectedRoute requiredPermission="canViewReports"><ModifiedBillReportPage /></ProtectedRoute>} />
          <Route path="/reports/day-book" element={<ProtectedRoute requiredPermission="canViewReports"><DayBookPage /></ProtectedRoute>} />
          <Route path="/reports/cash-book" element={<ProtectedRoute requiredPermission="canViewReports"><CashBookPage /></ProtectedRoute>} />
          <Route path="/reports/bank-book" element={<ProtectedRoute requiredPermission="canViewReports"><BankBookPage /></ProtectedRoute>} />
          <Route path="/reports/cashier-sessions" element={<ProtectedRoute requiredPermission="canViewReports"><CashierSessionsDashboardPage /></ProtectedRoute>} />
          <Route path="/reports/ledger-dashboard" element={<ProtectedRoute requiredPermission="canViewReports"><LedgerDashboardPage /></ProtectedRoute>} />
          <Route path="/reports/pending-dues" element={<ProtectedRoute requiredPermission="canViewReports"><PendingDuesPage /></ProtectedRoute>} />
          <Route path="/reports/customer-credit-statement" element={<ProtectedRoute requiredPermission="canViewReports"><CustomerCreditStatementPage /></ProtectedRoute>} />
          <Route path="/reports/profit-loss" element={<ProtectedRoute requiredPermission="canViewReports"><ProfitLossPage /></ProtectedRoute>} />
          <Route path="/reports/daywise-profit" element={<ProtectedRoute requiredPermission="canViewReports"><DayWiseProfitPage /></ProtectedRoute>} />
          <Route path="/reports/payment-methods" element={<ProtectedRoute requiredPermission="canViewReports"><PaymentMethodWisePage /></ProtectedRoute>} />
          <Route path="/reports/cashier-sales" element={<ProtectedRoute requiredPermission="canViewReports"><CashierSalesReportPage /></ProtectedRoute>} />
          <Route path="/reports/cash-in-hand" element={<ProtectedRoute requiredPermission="canViewReports"><CashInHandPage /></ProtectedRoute>} />
          <Route path="/reports/item-wise-sales" element={<ProtectedRoute requiredPermission="canViewReports"><ItemWiseSalesPage /></ProtectedRoute>} />
          <Route path="/reports/category-stock" element={<ProtectedRoute requiredPermission="canViewReports"><CategoryStockPage /></ProtectedRoute>} />
          <Route path="/reports/product-stock-history" element={<ProtectedRoute requiredPermission="canViewReports"><ProductStockHistoryPage /></ProtectedRoute>} />
          <Route path="/reports/moving-products" element={<ProtectedRoute requiredPermission="canViewReports"><MovingProductsPage /></ProtectedRoute>} />
          <Route path="/reports/wholesale-retail-stock" element={<ProtectedRoute requiredPermission="canViewReports"><WholesaleRetailStockPage /></ProtectedRoute>} />
          <Route path="/reports/stock-ledger" element={<ProtectedRoute requiredPermission="canViewReports"><StockLedgerPage /></ProtectedRoute>} />
          <Route path="/reports/product-stock-sales" element={<ProtectedRoute requiredPermission="canViewReports"><ProductStockSalesPage /></ProtectedRoute>} />
          <Route path="/reports/customer-balance" element={<ProtectedRoute requiredPermission="canViewReports"><CustomerBalancePage /></ProtectedRoute>} />
          <Route path="/reports/top-customers" element={<ProtectedRoute requiredPermission="canViewReports"><TopCustomersPage /></ProtectedRoute>} />
          <Route path="/reports/supplier-balance" element={<ProtectedRoute requiredPermission="canViewReports"><SupplierBalancePage /></ProtectedRoute>} />
          <Route path="/reports/purchase-report" element={<ProtectedRoute requiredPermission="canViewReports"><PurchaseReportPage /></ProtectedRoute>} />
          <Route path="/reports/customer-purchase-history" element={<ProtectedRoute requiredPermission="canViewReports"><CustomerPurchaseHistoryPage /></ProtectedRoute>} />
          <Route path="/reports/crm-points" element={<ProtectedRoute requiredPermission="canViewReports"><CrmPointsPage /></ProtectedRoute>} />
          <Route path="/bill-history" element={<ProtectedRoute requiredPermission="canViewReports"><BillHistoryPage /></ProtectedRoute>} />
          <Route path="/expenses" element={<ProtectedRoute requiredPermission="canViewExpenses"><ExpensesPage /></ProtectedRoute>} />
          <Route path="/inventory-alerts" element={<ProtectedRoute requiredPermission="canManageProducts"><InventoryAlertsPage /></ProtectedRoute>} />
          <Route path="/customers-loyalty" element={<ProtectedRoute requiredPermission="canViewReports"><CustomersLoyaltyPage /></ProtectedRoute>} />
          <Route path="/supplier-ledger" element={<ProtectedRoute requiredPermission="canManagePurchase"><SupplierLedgerPage /></ProtectedRoute>} />
          <Route path="/receipt-profiles" element={<ProtectedRoute adminOnly><ReceiptProfilesPage /></ProtectedRoute>} />
          <Route path="/audit-log" element={<ProtectedRoute adminOnly><AuditLogPage /></ProtectedRoute>} />
          <Route path="/org" element={<ProtectedRoute adminOnly><OrgManagementPage /></ProtectedRoute>} />
          <Route path="/masters" element={<ProtectedRoute requiredPermission="canManageMasters"><MastersPage /></ProtectedRoute>} />
          <Route path="/coupons" element={<ProtectedRoute adminOnly><CouponsPage /></ProtectedRoute>} />
          <Route path="/subscription" element={<SubscriptionPage />} />
          <Route path="/users" element={<ProtectedRoute adminOnly><UsersPage /></ProtectedRoute>} />
          <Route path="/settings" element={<SettingsPage />} />
        </Route>
      </Route>

      <Route path="*" element={<Navigate replace to="/" />} />
    </Routes>
  )
}

export default App
