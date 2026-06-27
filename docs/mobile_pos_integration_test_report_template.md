# Mobile POS Integration Test Report

## Run Details
- Date:
- Tester:
- Environment:
- App build:
- License mode:

## Reselling
| Scenario | Expected Result | Status | Notes |
| --- | --- | --- | --- |
| Product add and save | Product master is created with expected price and stock defaults |  |  |
| Purchase stock | Purchased quantity increases available stock |  |  |
| Create bill | Bill saves and stock decreases by sold quantity |  |  |
| Sales report | Saved bill appears in sales-by-bill report |  |  |
| Customer return | Returned quantity restores stock |  |  |

## Manufacturing
| Scenario | Expected Result | Status | Notes |
| --- | --- | --- | --- |
| Add raw material stock | Raw material quantity increases after purchase entry |  |  |
| Production entry | Raw material converts to finished stock |  |  |
| Raw material deduction | Raw material stock decreases after manufacturing flow |  |  |
| Finished product sale | Finished availability decreases after sale |  |  |
| Low stock alert | Low stock list surfaces depleted manufacturing inputs |  |  |

## Service
| Scenario | Expected Result | Status | Notes |
| --- | --- | --- | --- |
| Service invoice | Service invoice saves successfully |  |  |
| Service stock impact | Service lines never deduct stock |  |  |
| Partial payment | Outstanding balance is tracked |  |  |
| Full payment | Outstanding balance clears |  |  |
| Mixed bill | Only physical product stock is deducted |  |  |

## Cross-Cutting Rules
| Rule | Expected Result | Status | Notes |
| --- | --- | --- | --- |
| Tenant isolation | Each login sees only its own company data |  |  |
| Online license | Reads and writes use API path only |  |  |
| Offline license | Post-login operations stay local without API dependency |  |  |
| Manufacturing stock rule | Raw materials deduct instead of direct finished-goods inventory |  |  |

## Gaps / Follow-up
- 
