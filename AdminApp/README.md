# AdminApp

AdminApp is a standalone Flutter application for centralized administration of the NammaNanban platform.

## Scope

- Dashboard with business KPIs, summary cards, and trend chart
- Organization management (create/update/deactivate/view)
- User management with role and status controls
- License management (create/renew/upgrade/suspend)
- Organization mapping overview (organization ↔ license/users/branches)
- Usage analytics per organization
- Reports with export options (Excel/PDF/CSV)

## Tech Stack

- Flutter + Material 3
- Riverpod state management
- Existing backend API with JWT authentication
- Existing PostgreSQL database (through backend)

## Folder Structure

```text
lib/
  main.dart
  src/
    app/
    core/
    features/
    models/
    shared/
```

## Run

```bash
flutter pub get
flutter run
```
