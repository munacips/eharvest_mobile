# eHarvest Mobile

A Flutter application for the eHarvest agricultural marketplace. It connects **farmers**, **buyers**, and **logistics providers** in a unified workflow: list produce, browse and purchase, manage orders, track deliveries, chat in real time, and access AI-powered market insights.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Architecture & Patterns](#architecture--patterns)
- [Data Models](#data-models)
- [Services](#services)
- [Navigation & Routing](#navigation--routing)
- [Admin Panel](#admin-panel)
- [Configuration](#configuration)
- [Getting Started](#getting-started)
- [Backend Requirements](#backend-requirements)
- [Deployment](#deployment)

---

## Features

### Authentication
- Role-based sign-up for `FARMER`, `BUYER`, and `LOGISTICS_PROVIDER`.
- JWT login with token stored in `shared_preferences`.
- Splash screen reads the saved session and routes to login or the main tabs.

### Marketplace (Buy)
- Browse produce listings with search and filters (category, price range, harvest dates, quality grade, city/town).
- Product detail view showing farmer profile, trust score, geolocation, and image gallery.
- Cart management: add/remove items, view line totals.
- Checkout flow that creates orders and order items grouped by farmer.
- Multi-currency support (USD / ZiG) with escrow-based payment.

### Selling (Farmer)
- List new produce with name, category, quality grade, quantity, price, harvest date, availability window, geolocation, image URLs, and transport availability flag.
- Edit and delete existing listings.
- Bulk-price suggestion tool powered by the AI service.
- Accept or reject incoming orders from buyers.

### Logistics
- Request delivery for an order specifying pickup and delivery locations.
- Logistics providers view and accept open delivery requests.
- Real-time delivery tracking over STOMP WebSocket (`/ws/tracking`).
- Supply heatmap rendered on `flutter_map` showing produce density by location.
- `supply_map_screen.dart` overlays `HeatmapPoint` data on an interactive map.

### Payments
- Initiate payments via `POST /api/v1/payments/init`.
- Web redirect flow handled by `payment_return_page.dart` after gateway callback.
- Escrow hold and release lifecycle reflected on order and logistics request status.

### Real-Time Chat
- In-app messaging between users over STOMP WebSocket (`/ws`).
- `ChatService` manages connection lifecycle with auto-reconnect and exponential back-off.
- `chat_inbox_page.dart` lists conversations; `chat_conversation_page.dart` shows the message thread.

### Push Notifications
- Firebase Cloud Messaging (FCM) integrated via `firebase_messaging`.
- `NotificationService` initialises Firebase, requests permissions, retrieves the FCM token, and registers it with the backend.
- Foreground notifications shown via `flutter_local_notifications`.
- Token refresh is handled automatically.

### AI & Market Intelligence
- **Demand Forecast** (`ai_forecast_page.dart`): Line chart of predicted demand for a produce category.
- **Demand vs. Supply Forecast** (`demand_supply_forecast_page.dart`): Dual-line chart comparing demand and supply trends.
- **Bulk Pricing** (`bulk_pricing_page.dart`): Suggests optimal bulk prices for a produce item.
- **Market Insights** (`market_insights_page.dart`): Weather conditions and market price summaries.
- **Season Recommendations** (`season_recommendations_page.dart`): Prescriptive crop recommendations based on season and location.
- All AI features communicate with a FastAPI backend via `AiService`.

### Reviews & Trust
- Buyers and farmers can leave star-rated reviews after order completion.
- `ReviewService` fetches, creates, and moderates reviews.
- Trust score is surfaced on all user profile views.
- Pending reviews queue accessible from `My Account`.
- `dispute_reports_page.dart` lets users file and track dispute reports.

### Subscriptions
- Buyers can create recurring produce subscriptions (`subscription_form_page.dart`).
- Manage active subscriptions and view subscription details (`subscriptions_page.dart`, `subscription_detail_page.dart`).
- `SubscriptionService` handles CRUD operations against `/api/v1/subscriptions`.

### Reports
- Request analytical reports (`report_request_page.dart`) and browse generated reports (`reports_page.dart`).
- PDF reports rendered in-app via `syncfusion_flutter_pdfviewer` (`report_pdf_viewer_page.dart`).

### Responsive Layout
- `ResponsiveBreakpoints` utility provides shared breakpoints (tablet: 600 dp, desktop: 900 dp, wide: 1200 dp).
- `ResponsiveContent` widget constrains content width on large screens.
- Product grid adapts from 2 columns (mobile) up to 5 columns (≥ 1400 dp wide screens).
- Targets **Android**, **iOS**, **Web**, **Windows**, **macOS**, and **Linux**.

---

## Tech Stack

| Concern | Package / Tool |
|---|---|
| UI Framework | Flutter (Dart `^3.9.2`) |
| HTTP | `http ^1.1.0` |
| Session storage | `shared_preferences ^2.1.0` |
| Real-time messaging | `stomp_dart_client ^2.1.3` |
| Maps | `flutter_map ^7.0.2` + `latlong2 ^0.9.1` |
| Geolocation | `geolocator ^13.0.2` |
| Push notifications | `firebase_messaging ^15.0.0` + `flutter_local_notifications ^18.0.0` |
| Firebase | `firebase_core ^3.0.0` |
| PDF viewer | `syncfusion_flutter_pdfviewer ^29.2.11` |
| Date formatting | `intl ^0.20.2` |
| Icons | `cupertino_icons ^1.0.8` |
| Launcher icons | `flutter_launcher_icons ^0.14.4` |

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, route table, theme
├── firebase_options.dart        # Auto-generated Firebase platform config
├── global_variables.dart        # Shared models, colour constants, AppConfig
├── models/
│   ├── admin_models.dart        # Admin-specific DTOs
│   ├── chat_models.dart         # ChatMessage, Conversation models
│   ├── dispute_report.dart      # DisputeReport model
│   ├── report_descriptor.dart   # Report metadata model
│   └── tracking_update.dart     # TrackingUpdate model (STOMP payload)
├── pages/
│   ├── splash_page.dart         # Session check → login or tabs
│   ├── login_page.dart          # JWT login form
│   ├── signup_page.dart         # Role-based registration form
│   ├── tab_container.dart       # Bottom-nav shell (Home/Buy/Sell/Logistics/Account)
│   ├── home_page.dart           # Dashboard / landing screen
│   ├── buy_page.dart            # Produce browse, search, filter, cart
│   ├── checkout_page.dart       # Cart review and order placement
│   ├── sell_page.dart           # Farmer produce management and listing
│   ├── logistics_page.dart      # Logistics dashboard
│   ├── logistics_list.dart      # Available delivery requests list
│   ├── logistics_request_page.dart  # Create/manage a delivery request
│   ├── order_page.dart          # Order detail, status, escrow actions
│   ├── my_orders_page.dart      # Buyer order history
│   ├── my_account_page.dart     # Profile, balances, transaction history
│   ├── account_page.dart        # Public user profile view
│   ├── chat_inbox_page.dart     # Conversation list
│   ├── chat_conversation_page.dart  # Message thread
│   ├── supply_map_screen.dart   # Interactive produce heatmap
│   ├── ai_forecast_page.dart    # Demand forecast chart
│   ├── demand_supply_forecast_page.dart  # Dual demand/supply chart
│   ├── bulk_pricing_page.dart   # AI bulk price suggestion
│   ├── market_insights_page.dart  # Weather & price insights
│   ├── season_recommendations_page.dart  # Crop recommendations
│   ├── subscriptions_page.dart  # Subscription list
│   ├── subscription_form_page.dart  # Create/edit subscription
│   ├── subscription_detail_page.dart  # Subscription detail
│   ├── reports_page.dart        # Generated reports list
│   ├── report_request_page.dart # Request a new report
│   ├── report_pdf_viewer_page.dart  # In-app PDF viewer
│   ├── dispute_reports_page.dart  # File and track disputes
│   ├── pending_reviews_page.dart  # Awaiting-review queue
│   ├── payment_return_page.dart # Payment gateway callback handler
│   └── admin/                   # Admin-only pages (see Admin Panel)
├── services/
│   ├── auth_service.dart        # Login, signup, token management
│   ├── order_service.dart       # Order and order-item CRUD
│   ├── logistics_service.dart   # Logistics request CRUD
│   ├── payment_service.dart     # Payment initiation and return
│   ├── chat_service.dart        # STOMP chat + REST history
│   ├── tracking_service.dart    # STOMP real-time location tracking
│   ├── notification_service.dart  # FCM initialisation and token registration
│   ├── notification_api_service.dart  # Backend token registration calls
│   ├── ai_service.dart          # AI/ML FastAPI calls
│   ├── review_service.dart      # Review CRUD and moderation
│   ├── subscription_service.dart  # Subscription CRUD
│   ├── report_service.dart      # Report generation and retrieval
│   ├── dispute_report_service.dart  # Dispute filing and listing
│   ├── supply_heatmap_service.dart  # Heatmap data fetch
│   ├── admin_service.dart       # All admin REST operations
│   └── payment_redirect_web.dart / _stub.dart  # Platform-conditional redirect
├── utils/
│   └── responsive_breakpoints.dart  # Breakpoints + ResponsiveContent widget
└── widgets/
    ├── count_badge.dart          # Notification count badge
    ├── order_review_section.dart # Order-scoped review display
    ├── pending_review_sheet.dart # Bottom-sheet for submitting a review
    ├── review_form.dart          # Star-rating + comment form
    ├── reviews_section.dart      # Aggregated reviews list
    └── star_rating_input.dart    # Tappable star-row input
```

---

## Architecture & Patterns

### Service Layer
All network calls are isolated in `lib/services/`. Each service is a class with `static` async methods that:
1. Retrieve the JWT from `AuthService.getToken()`.
2. Set `Authorization: Bearer <token>` on every request.
3. Decode the JSON response into strongly-typed model objects.

### Data Models
Core models live in `lib/global_variables.dart`; feature-specific models are in `lib/models/`. Every model implements `fromJson` (and `toJson` where mutation is needed). Models accept both `snake_case` and `camelCase` JSON keys for backend compatibility.

### Real-Time Connections (STOMP over WebSocket)
- **Chat**: `ChatService` connects to `AppConfig.chatWebSocketUrl` (`/ws`). It subscribes to `/user/queue/messages` and publishes to `/app/chat.send`. It handles reconnect with exponential back-off and emits typed `ChatConnectionStatus` events.
- **Tracking**: `TrackingService` connects to `AppConfig.trackingWebSocketUrl` (`/ws/tracking`). Providers stream GPS coordinates; buyers receive `TrackingUpdate` payloads in real time.

### Escrow Lifecycle
Orders and logistics requests each maintain an escrow state (`escrowHeld` / `escrowReleased`). The UI surfaces these as actionable buttons (hold/release) on `order_page.dart` and `logistics_request_page.dart`, calling dedicated backend endpoints.

### Responsive Design
`ResponsiveBreakpoints` and the `ResponsiveContent` widget provide a single source of truth for layout thresholds. Grid column counts and aspect ratios adapt automatically based on screen width.

### Environment-Driven Configuration
`AppConfig` reads compile-time `String.fromEnvironment` variables:

| Variable | Default | Description |
|---|---|---|
| `EHARVEST_API_SCHEME` | `http` | HTTP scheme for API calls |
| `EHARVEST_API_HOST` | *(production host)* | Override hostname |
| `EHARVEST_API_PORT` | `8080` | Main API port |
| `EHARVEST_AI_PORT` | `8000` | FastAPI AI service port |

On the web, when no host override is set, relative URLs are used so the app works behind a reverse proxy without CORS issues.

---

## Data Models

| Model | Location | Key Fields |
|---|---|---|
| `User` | `global_variables.dart` | `id`, `role`, `trustScore`, `usdBalance`, `zigBalance` |
| `Farmer` | `global_variables.dart` | extends User + `farmName`, `farmLocation`, `successfulSales` |
| `Buyer` | `global_variables.dart` | extends User + `companyName`, `successfulBuys` |
| `LogisticsProvider` | `global_variables.dart` | extends User + `licenseNumber`, `defensiveId` |
| `Vehicle` | `global_variables.dart` | `plateNumber`, `type`, `colour`, `owner` |
| `Produce` | `global_variables.dart` | `category`, `qualityGrade`, `price`, `harvestDate`, `imageUrls`, `canProvideTransport` |
| `Order` | `global_variables.dart` | `status`, `escrowAmount`, `currency`, `logisticsType`, `escrowHeld/Released` |
| `OrderItem` | `global_variables.dart` | `produce`, `quantity`, `price` |
| `LogisticsRequest` | `global_variables.dart` | `pickupLocation`, `deliveryLocation`, `cost`, `assignedProvider`, `escrowHeld/Released` |
| `Review` | `global_variables.dart` | `rating`, `comment`, `status`, `reviewer`, `reviewee` |
| `Transaction` | `global_variables.dart` | `transactionReference`, `amount`, `currency` |
| `HeatmapPoint` | `global_variables.dart` | `latitude`, `longitude`, `normalizedWeight` (kg) |
| `TrackingUpdate` | `models/tracking_update.dart` | real-time GPS payload |
| `ChatMessage` / `Conversation` | `models/chat_models.dart` | STOMP chat payload |

---

## Services

| Service | Transport | Purpose |
|---|---|---|
| `AuthService` | REST | Login, signup, token read/write/clear |
| `OrderService` | REST | Create orders, fetch buyer/farmer orders, update status |
| `LogisticsService` | REST | Create requests, fetch provider queue, update status |
| `PaymentService` | REST | Initiate payment, poll return status |
| `ChatService` | STOMP + REST | Real-time messaging, history fetch |
| `TrackingService` | STOMP + REST | Live GPS tracking, position broadcast |
| `NotificationService` | FCM | Push notification init, token registration |
| `NotificationApiService` | REST | Register/update FCM token with backend |
| `AiService` | REST | Demand forecast, supply forecast, bulk pricing, market insights, season recommendations |
| `ReviewService` | REST | Submit, fetch, and moderate reviews |
| `SubscriptionService` | REST | Produce subscription CRUD |
| `ReportService` | REST | Request and download analytical reports |
| `DisputeReportService` | REST | File and retrieve dispute reports |
| `SupplyHeatmapService` | REST | Fetch `HeatmapPoint` list for map overlay |
| `AdminService` | REST | Platform admin: users, produce, orders, transactions, vehicles, disputes |

---

## Navigation & Routing

```
SplashPage
  ├── /login       → LoginPage
  │     └── /signup → SignupPage
  └── /tabs        → TabContainer
        ├── Tab 0: HomePage
        ├── Tab 1: BuyPage → CheckoutPage → OrderPage
        ├── Tab 2: SellPage → (produce form, AI tools)
        ├── Tab 3: LogisticsPage → LogisticsList → LogisticsRequestPage
        └── Tab 4: MyAccountPage → AccountPage, ChatInboxPage, ...
/payments/return   → PaymentReturnPage
```

Nested routes (order detail, chat, reports, admin) are pushed imperatively with `Navigator.push`.

---

## Admin Panel

Accessible from `My Account` when the logged-in user has the `ADMIN` role.

| Page | File | Scope |
|---|---|---|
| Dashboard | `admin/admin_dashboard_page.dart` | Platform-wide KPIs |
| Users | `admin/admin_users_page.dart` | All registered users |
| Role Users | `admin/admin_role_users_page.dart` | Filter by FARMER / BUYER / LOGISTICS_PROVIDER |
| Produce | `admin/admin_produce_page.dart` | All listings, moderate or delete |
| Orders | `admin/admin_orders_page.dart` | All orders with status management |
| Order Items | `admin/admin_order_items_page.dart` | Line-item audit |
| Transactions | `admin/admin_transactions_page.dart` | Financial transaction log |
| Logistics | `admin/admin_logistics_page.dart` | All delivery requests |
| Vehicles | `admin/admin_vehicles_page.dart` | Registered provider vehicles |
| Reviews | `admin/admin_reviews_page.dart` | Moderate and approve reviews |
| Disputes | `admin/admin_disputes_page.dart` | Dispute resolution queue |
| Subscriptions | `admin/admin_subscriptions_page.dart` | Platform-wide subscriptions |

All admin calls are routed through `AdminService` using the `/api/v1/admin/` base URL.

---

## Configuration

### API Hosts

Update the compile-time defaults in `lib/global_variables.dart` → `AppConfig`:

```dart
static const String _defaultHost = '34.206.207.121'; // replace with your host
```

Or pass environment variables at build time:

```bash
flutter build web \
  --dart-define=EHARVEST_API_HOST=api.example.com \
  --dart-define=EHARVEST_API_SCHEME=https \
  --dart-define=EHARVEST_API_PORT=443 \
  --dart-define=EHARVEST_AI_PORT=8000
```

For Android emulator local development use `10.0.2.2` instead of `localhost`.

### Firebase

Run `flutterfire configure` to regenerate `lib/firebase_options.dart` for your Firebase project. Refer to [`FCM_SETUP_GUIDE.md`](FCM_SETUP_GUIDE.md) for the full FCM setup walkthrough.

---

## Getting Started

1. **Install Flutter SDK** — requires Dart `^3.9.2`.

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Generate launcher icons:**
   ```bash
   dart run flutter_launcher_icons
   ```

4. **Run the app:**
   ```bash
   # Mobile
   flutter run

   # Web
   flutter run -d chrome

   # With API host override
   flutter run --dart-define=EHARVEST_API_HOST=192.168.1.10
   ```

---

## Backend Requirements

The app expects a Spring Boot REST API and a FastAPI AI service. Key endpoints:

| Area | Endpoints |
|---|---|
| Auth | `POST /auth/login`, `POST /auth/register` |
| Users | `GET/PUT /api/v1/users/{id}`, `/api/v1/farmers`, `/api/v1/buyers`, `/api/v1/logistics-providers` |
| Produce | `GET/POST/PUT/DELETE /api/v1/produce` |
| Orders | `GET/POST /api/v1/orders`, `GET /api/v1/order_items` |
| Logistics | `GET/POST/PUT /api/v1/logistics` |
| Payments | `POST /api/v1/payments/init`, `GET /api/v1/payments/return` |
| Reviews | `GET/POST /api/v1/reviews` |
| Subscriptions | `GET/POST/PUT/DELETE /api/v1/subscriptions` |
| Reports | `GET/POST /api/reports/` |
| Disputes | `GET/POST /api/v1/disputes` |
| Heatmap | `GET /api/v1/supply-heatmap` |
| Notifications | `POST /api/v1/notifications/register-token` |
| Admin | `GET/PUT/DELETE /api/v1/admin/**` |
| WebSocket | `ws://<host>:<port>/ws` (chat), `ws://<host>:<port>/ws/tracking` (tracking) |
| AI (FastAPI) | `POST /forecast/demand`, `/forecast/supply`, `/pricing/bulk`, `/insights/market`, `/recommendations/season` |

All REST endpoints require `Authorization: Bearer <jwt>` except `/auth/**`.

---

## Deployment

### Docker (Web)

A two-stage Dockerfile builds the Flutter web bundle and serves it via Nginx:

```bash
docker build -t eharvest-mobile .
docker run -p 80:80 eharvest-mobile
```

Pass `--dart-define` arguments inside the `flutter build web` command in the Dockerfile to bake API endpoints into the image at build time.

### CI/CD

A `.github/` directory is present for GitHub Actions workflows. Connect your workflow to run `flutter test`, `flutter build web`, and push to your registry or hosting service.
