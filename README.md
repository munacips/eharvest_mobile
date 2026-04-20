# eHarvest Mobile

Flutter mobile app for the eHarvest marketplace. It connects farmers, buyers, and logistics providers in a single workflow: list produce, browse and purchase, manage orders, and request deliveries.

**Features**
- Role-based sign-up for `FARMER`, `BUYER`, and `LOGISTICS_PROVIDER`.
- Login with token storage in `shared_preferences`.
- Browse produce with search and filters (category, price range, harvest dates, quality grade).
- Cart checkout that creates orders and order items grouped by farmer.
- Farmer flow to list new produce with pricing and availability dates.
- Buyer order history and order detail view.
- Farmer order management with accept/reject actions.
- Logistics requests and tracking view for orders.
- Profile views with trust score and role-specific details.

**Navigation**
- `Home`, `Buy`, `Sell`, `Logistics`, `My Account` tabs in `lib/pages/tab_container.dart`.
- Splash screen routes to login or main tabs based on saved session.

**Tech Stack**
- Flutter (Dart)
- `http` for REST calls
- `shared_preferences` for session storage
- `intl` for date formatting

**Project Structure**
- `lib/main.dart`: app entry point and routes.
- `lib/global_variables.dart`: API base URLs, colors, and models.
- `lib/pages/`: UI screens for auth, marketplace, orders, logistics, and profiles.
- `lib/services/`: API helpers for auth and orders.
- `lib/pages/ai_forecast_page.dart`: Demand forecast UI with a simple line chart.
- `lib/pages/bulk_pricing_page.dart`: Bulk price suggestion UI.
- `lib/pages/demand_supply_forecast_page.dart`: Demand vs supply forecast with a dual-line chart.
- `lib/pages/market_insights_page.dart`: Weather and market price insights.
- `lib/pages/season_recommendations_page.dart`: Prescriptive crop recommendations UI.
- `lib/services/ai_service.dart`: AI API helper.

**Configuration**
- Update API hosts in `lib/global_variables.dart`: `api = "http://localhost:8080/api/v1/"` and `authApi = "http://localhost:8080/auth/"`.
- AI services use `aiApi = "http://localhost:8000"` (FastAPI default). Change it if your AI server is hosted elsewhere.
- If you run the backend on a device or emulator, set the base URL accordingly (for example, Android emulator commonly uses `10.0.2.2` instead of `localhost`).

**Getting Started**
1. Install Flutter SDK (project uses Dart `^3.9.2`).
2. Fetch dependencies:
```bash
flutter pub get
```
3. Run the app:
```bash
flutter run
```

**Backend Requirements**
- Auth: `POST /auth/login`
- Users: `/api/v1/users`, `/api/v1/farmers`, `/api/v1/buyers`, `/api/v1/logistics-providers`
- Produce: `/api/v1/produce`
- Orders: `/api/v1/orders`, `/api/v1/order_items`
- Logistics: `/api/v1/logistics`

**Notes**
- The app expects JSON responses compatible with the models in `lib/global_variables.dart`.
- Some UI elements include placeholders for future enhancements (for example, AI market insight and tracking progress).
