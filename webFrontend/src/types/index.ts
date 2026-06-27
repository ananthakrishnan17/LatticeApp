export type UserRole = 'admin' | 'user'

export interface LoginRequest {
  tenantCode: string
  username?: string
  phoneNumber?: string
  password: string
  deviceId: string
}

export interface LoginResponse {
  accessToken: string
  tenantId: string
  deviceId: string
  role: UserRole
  organizationId: string
  branchId: string
  scopeRole: string
}

export interface BootstrapRequest {
  tenantCode: string
  username?: string
  phoneNumber?: string
  password: string
  deviceId: string
}

export interface BootstrapResponse {
  status: 'ok'
}

export interface ProductResponse {
  serverId: string
  clientRecordId: string
  name: string
  unit: string
  sellingPrice: number
  purchasePrice: number
  stockQuantity: number
  version: number
  updatedAt: string
  deletedAt: string | null
}

export interface ProductUpsertRequest {
  clientRecordId: string
  name: string
  unit?: string
  sellingPrice?: number
  purchasePrice?: number
  stockQuantity?: number
  version?: number
  updatedAt?: string
  deleted?: boolean
}

export interface BillItemRequest {
  productId?: string
  productName: string
  productSku?: string
  unit: string
  quantity: number
  unitPrice: number
  purchasePrice?: number
  totalPrice: number
  gstRate?: number
  discountAmount?: number
  itemDiscountType?: string
  itemDiscountValue?: number
}

export interface BillUpsertRequest {
  clientRecordId: string
  billNumber: string
  billType?: string
  customerName?: string
  customerAddress?: string
  customerGstin?: string
  totalAmount: number
  totalProfit?: number
  discountAmount?: number
  gstTotal?: number
  cgstTotal?: number
  sgstTotal?: number
  igstTotal?: number
  paymentMode?: string
  couponCode?: string
  couponDiscountAmount?: number
  cashTendered?: number
  changeAmount?: number
  splitPaymentSummary?: string
  items?: BillItemRequest[]
  version?: number
  createdAt?: string
  updatedAt?: string
}

export interface BillUpsertResponse {
  status: 'ok' | 'duplicate'
  clientRecordId: string
}

export interface UserResponse {
  username: string
  role: UserRole
  isActive: boolean
  canBill: boolean
  canViewReports: boolean
  canManageProducts: boolean
  canManageMasters: boolean
  canViewExpenses: boolean
  canManagePurchase: boolean
  canViewDashboard: boolean
  createdAt: string
  updatedAt: string
}

export type CashSessionStatus = 'OPEN' | 'CLOSED'

export interface CashSessionRecord {
  id: string
  cashierUsername: string
  status: CashSessionStatus
  openingAmount: number
  openingDenominations: Record<string, number> | null
  openedAt: string
  totalCashCollected: number
  totalCashRefunded: number
  expectedClosing: number
  closingAmount: number | null
  closingDenominations: Record<string, number> | null
  closedAt: string | null
  difference: number | null
  closedBy: string | null
  notes: string | null
}

export interface CreateUserRequest {
  username: string
  pin: string
  role?: UserRole
  isActive?: boolean
  canBill?: boolean
  canViewReports?: boolean
  canManageProducts?: boolean
  canManageMasters?: boolean
  canViewExpenses?: boolean
  canManagePurchase?: boolean
  canViewDashboard?: boolean
}

export interface UpdateUserRequest {
  role?: UserRole
  isActive?: boolean
  canBill?: boolean
  canViewReports?: boolean
  canManageProducts?: boolean
  canManageMasters?: boolean
  canViewExpenses?: boolean
  canManagePurchase?: boolean
  canViewDashboard?: boolean
}

export interface UpdateUserPinRequest {
  pin: string
}

export interface SubscriptionStatusResponse {
  companyName: string
  licenseKey: string
  planCode: string
  maxUsers: number
  maxCompanies: number
  active: boolean
  expired: boolean
  activatedAt: string | null
  expiresAt: string | null
  daysLeft: number
}

export interface ActivateSubscriptionRequest {
  licenseKey: string
}

export interface TransactionUpsertRequest {
  clientRecordId: string
  type: string
  totalAmount: number
  tags?: Record<string, unknown>
  createdAt?: string
  updatedAt?: string
}

export interface TransactionUpsertResponse {
  status: string
  clientRecordId: string
}

export interface TransactionRecord {
  server_id: string
  client_record_id: string
  tx_type: string
  total_amount: number
  tags_json: Record<string, unknown>
  created_at: string
  updated_at: string
}

// ─── Purchase ─────────────────────────────────────────────────────────────────

export interface PurchaseItemRequest {
  productId?: string
  productName: string
  quantity: number
  unit?: string
  unitCost: number
  gstRate?: number
  gstAmount?: number
  totalCost: number
}

export interface PurchaseUpsertRequest {
  clientRecordId: string
  purchaseNumber: string
  supplierName?: string
  totalAmount: number
  gstTotal?: number
  paymentMode?: string
  invoiceNumber?: string
  invoiceAmount?: number
  notes?: string
  items?: PurchaseItemRequest[]
  purchaseDate?: string
  createdAt?: string
  updatedAt?: string
}

export interface PurchaseUpsertResponse {
  status: string
  clientRecordId: string
}

// ─── Sale Return ──────────────────────────────────────────────────────────────

export interface SaleReturnItemRequest {
  productId?: string
  productName: string
  quantity: number
  unit?: string
  unitPrice: number
  totalPrice: number
}

export interface SaleReturnUpsertRequest {
  clientRecordId: string
  returnNumber: string
  originalBillNumber?: string
  customerName?: string
  returnType?: string
  refundMode?: string
  reason?: string
  totalReturnAmount: number
  items?: SaleReturnItemRequest[]
  createdAt?: string
  updatedAt?: string
}

export interface SaleReturnUpsertResponse {
  status: string
  clientRecordId: string
}

// ─── Purchase Return ──────────────────────────────────────────────────────────

export interface PurchaseReturnUpsertRequest {
  clientRecordId: string
  returnNumber: string
  originalPurchaseNumber?: string
  supplierName?: string
  totalReturnAmount: number
  notes?: string
  createdAt?: string
  updatedAt?: string
}

export interface PurchaseReturnUpsertResponse {
  status: string
  clientRecordId: string
}

// ─── Day Close ────────────────────────────────────────────────────────────────

export interface DayCloseUpsertRequest {
  clientRecordId: string
  closeDate: string
  cashOpening?: number
  cashClosing: number
  cashVariance?: number
  totalSales?: number
  totalExpenses?: number
  totalReturns?: number
  totalPurchases?: number
  cashSales?: number
  digitalSales?: number
  billCount?: number
  notes?: string
  closedBy?: string
  createdAt?: string
  updatedAt?: string
}

export interface DayCloseUpsertResponse {
  status: string
  clientRecordId: string
}

export interface ShopInfoSettings {
  shopName: string
  address: string
  phone: string
  email: string
  gstin: string
  footerNote: string
}

export interface LanguageSettings {
  language: 'en' | 'ta'
  currencySymbol: string
  dateFormat: 'DD/MM/YYYY' | 'MM/DD/YYYY' | 'YYYY-MM-DD'
}

export interface PrinterSettings {
  paperSize: '58mm' | '80mm' | 'A4'
  showGstin: boolean
  headerText: string
  footerText: string
}

// ─── Masters ──────────────────────────────────────────────────────────────────

export interface CategoryRecord {
  serverId: string
  clientRecordId: string
  name: string
  version: number
  updatedAt: string
}

export interface CategoryUpsertRequest {
  clientRecordId: string
  name: string
  version?: number
  updatedAt?: string
  deleted?: boolean
}

export interface BrandRecord {
  serverId: string
  clientRecordId: string
  name: string
  version: number
  updatedAt: string
}

export interface BrandUpsertRequest {
  clientRecordId: string
  name: string
  version?: number
  updatedAt?: string
  deleted?: boolean
}

export interface CustomerRecord {
  serverId: string
  clientRecordId: string
  name: string
  phone: string | null
  address: string | null
  gstNumber: string | null
  creditLimit: number
  outstandingBalance: number
  version: number
  updatedAt: string
}

export interface CustomerUpsertRequest {
  clientRecordId: string
  name: string
  phone?: string
  address?: string
  gstNumber?: string
  creditLimit?: number
  outstandingBalance?: number
  version?: number
  updatedAt?: string
  deleted?: boolean
}

export interface SupplierRecord {
  serverId: string
  clientRecordId: string
  name: string
  phone: string | null
  address: string | null
  gstNumber: string | null
  outstandingBalance: number
  version: number
  updatedAt: string
}

export interface SupplierUpsertRequest {
  clientRecordId: string
  name: string
  phone?: string
  address?: string
  gstNumber?: string
  outstandingBalance?: number
  version?: number
  updatedAt?: string
  deleted?: boolean
}

export interface UnitRecord {
  clientRecordId: string
  name: string
}

// ─── Owner / Org Management ──────────────────────────────────────────────────

export interface OwnerDashboardResponse {
  todayRevenue: number
  trendPercent: number
  totalProfit: number
  transactionCount: number
  activeStaffCount: number
  branches: OwnerBranchSummary[]
}

export interface OwnerBranchSummary {
  branchId: string
  branchName: string
  transactionCount: number
  activeStaffCount: number
  revenueAmount: number
  targetPercent: number
}

export interface OwnerBranchResponse {
  id: string
  name: string
  isDefault: boolean
  createdAt: string
}

export interface OwnerRoleResponse {
  code: string
  displayName: string
  scope: string
}

export interface AssignUserRequest {
  branchId: string
  roleCode: string
}

// ─── Coupons ──────────────────────────────────────────────────────────────────

export type CouponDiscountType = 'flat' | 'percent'

export interface CouponConfig {
  id: string
returnNumber: string
  originalPurchaseNumber?: string
  supplierName?: string
  totalReturnAmount: number
  notes?: string
  createdAt?: string
  updatedAt?: string
}

export interface PurchaseReturnUpsertResponse {
  status: string
  clientRecordId: string
}

// ─── Day Close ────────────────────────────────────────────────────────────────

export interface DayCloseUpsertRequest {
  clientRecordId: string
  closeDate: string
  cashOpening?: number
  cashClosing: number
  cashVariance?: number
  totalSales?: number
  totalExpenses?: number
  totalReturns?: number
  totalPurchases?: number
  cashSales?: number
  digitalSales?: number
  billCount?: number
  notes?: string
  closedBy?: string
  createdAt?: string
  updatedAt?: string
}

export interface DayCloseUpsertResponse {
  status: string
  clientRecordId: string
}

export interface ShopInfoSettings {
  shopName: string
  address: string
  phone: string
  email: string
  gstin: string
  footerNote: string
}

export interface LanguageSettings {
  language: 'en' | 'ta'
  currencySymbol: string
  dateFormat: 'DD/MM/YYYY' | 'MM/DD/YYYY' | 'YYYY-MM-DD'
}

export interface PrinterSettings {
  paperSize: '58mm' | '80mm' | 'A4'
  showGstin: boolean
  headerText: string
  footerText: string
}

// ─── Masters ──────────────────────────────────────────────────────────────────

export interface CategoryRecord {
  serverId: string
  clientRecordId: string
  name: string
  version: number
  updatedAt: string
}

export interface CategoryUpsertRequest {
  clientRecordId: string
  name: string
  version?: number
  updatedAt?: string
  deleted?: boolean
}

export interface BrandRecord {
  serverId: string
  clientRecordId: string
  name: string
  version: number
  updatedAt: string
}

export interface BrandUpsertRequest {
  clientRecordId: string
  name: string
  version?: number
  updatedAt?: string
  deleted?: boolean
}

export interface CustomerRecord {
  serverId: string
  clientRecordId: string
  name: string
  phone: string | null
  address: string | null
  gstNumber: string | null
  creditLimit: number
  outstandingBalance: number
  version: number
  updatedAt: string
}

export interface CustomerUpsertRequest {
  clientRecordId: string
  name: string
  phone?: string
  address?: string
  gstNumber?: string
  creditLimit?: number
  outstandingBalance?: number
  version?: number
  updatedAt?: string
  deleted?: boolean
}

export interface SupplierRecord {
  serverId: string
  clientRecordId: string
  name: string
  phone: string | null
  address: string | null
  gstNumber: string | null
  outstandingBalance: number
  version: number
  updatedAt: string
}

export interface SupplierUpsertRequest {
  clientRecordId: string
  name: string
  phone?: string
  address?: string
  gstNumber?: string
  outstandingBalance?: number
  version?: number
  updatedAt?: string
  deleted?: boolean
}

export interface UnitRecord {
  clientRecordId: string
  name: string
}

// ─── Owner / Org Management ──────────────────────────────────────────────────

export interface OwnerDashboardResponse {
  todayRevenue: number
  trendPercent: number
  totalProfit: number
  transactionCount: number
  activeStaffCount: number
  branches: OwnerBranchSummary[]
}

export interface OwnerBranchSummary {
  branchId: string
  branchName: string
  transactionCount: number
  activeStaffCount: number
  revenueAmount: number
  targetPercent: number
}

export interface OwnerBranchResponse {
  id: string
  name: string
  isDefault: boolean
  createdAt: string
}

export interface OwnerRoleResponse {
  code: string
  displayName: string
  scope: string
}

export interface AssignUserRequest {
  branchId: string
  roleCode: string
}

// ─── Coupons ──────────────────────────────────────────────────────────────────

export type CouponDiscountType = 'flat' | 'percent'

export interface CouponConfig {
  id: string
  code: string
  discountType: CouponDiscountType
  discountValue: number
  minOrderAmount: number
  active: boolean
}

export interface BranchSummary {
  branchId: string
  branchName: string
  transactionCount: number
  activeStaffCount: number
  revenueAmount: number
  targetPercent: number
}
