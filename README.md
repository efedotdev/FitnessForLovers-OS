# FitnessForLovers - iOS App

A SwiftUI app for sharing health data between two Apple devices, setting shared fitness goals, and tracking progress together.

## Features

- **Email authentication** - Register, log in, restore sessions, and log out
- **Apple Sign In** - Existing sign-in integration remains available
- **HealthKit Integration** - Read steps, active energy, and walking/running distance
- **Partner Pairing** - Invite and connect with a partner
- **Shared Goals** - Create and track fitness goals together
- **Dashboard** - View your daily metrics, partner summary, and shared goals
- **Data Sharing Control** - Granular control over what data to share

## Project Structure

```
FitnessForLovers/
├── FitnessForLoversApp.swift       # App entry point
├── ContentView.swift               # Root view
├── AppRootView.swift               # Authentication flow & main tab view
├── Models/
│   └── APIModels.swift             # Data models matching backend DTOs
├── Services/
│   ├── APIService.swift            # Network layer with token management
│   ├── AuthManager.swift           # Authentication state management
│   ├── HealthKitService.swift      # HealthKit data fetching & sync
│   └── KeychainHelper.swift        # Secure token storage
├── ViewModels/
│   ├── DashboardViewModel.swift    # Dashboard data & logic
│   ├── PairingViewModel.swift      # Partner pairing management
│   ├── GoalsViewModel.swift        # Goals CRUD & progress tracking
│   └── ProfileViewModel.swift      # User preferences & settings
├── Views/
│   ├── DashboardView.swift         # Main dashboard with metrics
│   ├── PairingView.swift           # Partner management
│   ├── GoalsView.swift             # Goals list & creation
│   └── ProfileView.swift           # User profile & settings
├── Extensions/
│   ├── ViewExtensions.swift        # SwiftUI view helpers
│   └── NotificationNames.swift     # Notification center names
└── Resources/
    └── Assets.xcassets             # App icons & colors
```

## Backend API Integration

The app uses the backend at `http://localhost:3000` by default (including iOS Simulator).
There is no `/api` path prefix. Change `APIConfig.baseURL` in
`FitnessForLovers/Services/APIService.swift` for a deployed HTTPS backend.

### API Endpoints Used

| Feature | Endpoints |
|---------|-----------|
| Auth | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `GET /auth/me`, `POST /auth/logout` |
| Pairings | `GET /pairings`, `/pairings/pending`, `/pairings/sent`, `POST /pairings`, `POST /pairings/:id/respond`, `PATCH/DELETE /pairings/:id` |
| Health Data | `POST /health-data/bulk`, `GET /health-data/summary`, `GET /health-data/partner/:id/summary` |
| Goals | `POST /goals`, `GET /goals/pairing/:pairingId`, `GET /goals/:id`, `PATCH/DELETE /goals/:id`, `GET /goals/:id/progress` |
| Dashboard | `GET /dashboard` |
| User | `GET/PATCH /users/me`, `GET/PATCH /users/me/preferences` |
| Devices | `POST /devices`, `GET/PATCH/DELETE /devices/:id` |
| Notifications | `GET /notifications`, `PATCH /notifications/:id/read` |

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Xcode signing team for device builds and Apple capabilities

## Setup

### 1. Configure Xcode Project

1. Open `FitnessForLovers.xcodeproj` in Xcode and select the `FitnessForLovers` target.
2. Set your development team and a unique bundle identifier under **Signing & Capabilities**.
3. Ensure **HealthKit** is enabled for the App ID and signing profile. Keep **Sign In with Apple** enabled only if using the retained Apple sign-in option.
4. The active `Info.plist` is at the repository root and contains the read-only `NSHealthShareUsageDescription`. No HealthKit write permission or Background Modes capability is used.

### 2. Configure Backend URL

The simulator uses `http://localhost:3000`. For production, set `APIConfig.baseURL` to the backend's HTTPS origin. The plist permits insecure HTTP only for the local `localhost` development host.

### 3. Run the Backend

```bash
cd ../backend
npm install
npm run prisma:generate
npm run prisma:migrate
npm run dev
```

### 4. Run the App

1. Select your development team in Xcode
2. Connect an iPhone to test actual HealthKit data (HealthKit data is not available in Simulator)
3. Press `Cmd+R` to build and run

## Architecture

### MVVM Pattern

- **Models** - Pure Swift structs matching backend DTOs
- **ViewModels** - `@ObservableObject` classes handling business logic
- **Views** - SwiftUI declarative UI components
- **Services** - Singleton actors for network, auth, HealthKit

### Data Flow

```
HealthKit → HealthKitService → APIService (sync) → Backend
                                    ↓
Backend → APIService → ViewModels → Views
```

### Authentication Flow

1. User registers or logs in with email and password.
2. JWT access/refresh tokens are saved in Keychain before the app enters the authenticated state.
3. On relaunch, the app verifies the saved session with `GET /auth/me`.
4. Protected requests use a Bearer access token; a 401 triggers one refresh attempt.
5. Logout revokes the backend session and clears local Keychain tokens.

### HealthKit Sync

1. User grants HealthKit permissions
2. `HealthKitService` reads steps, active energy, and walking/running distance.
3. Samples include their HealthKit UUID and are converted to backend DTOs (distance in meters).
4. Authenticated batches are synced via `/health-data/bulk`.

## Key Components

### APIService (Actor)
- Thread-safe network requests
- Automatic token refresh
- Safe request/response diagnostics
- Error handling with typed errors

### AuthManager (@ObservableObject)
- Current user state
- Email/password and retained Apple Sign In flows
- Session restoration
- Sign out handling

### HealthKitService (@ObservableObject)
- Authorization management
- Sample querying & conversion
- Explicit user-triggered sync

### ViewModels (@ObservableObject)
- Reactive UI state
- Data fetching & caching
- User action handling
- Cross-view notifications

## Testing

### API contract tests
```bash
swift test
```

The Xcode project currently has an app scheme but no Xcode test target.

## Deployment

### TestFlight
1. Archive in Xcode (`Product > Archive`)
2. Distribute to TestFlight
3. Add internal/external testers

### App Store
1. Complete App Store Connect setup
2. Submit for review
3. Ensure HealthKit & Sign in with Apple descriptions are accurate

## Privacy & Security

- Access and refresh tokens stored in Keychain (not UserDefaults)
- Health data only synced with explicit user consent
- No health data stored locally unencrypted
- Partner data access controlled by sharing scope
- Production API communication must use HTTPS; local development uses HTTP on localhost

## Troubleshooting

### HealthKit Not Authorized
- Check capabilities in Xcode
- Verify Info.plist usage descriptions
- Test on physical device (simulator limited)

### Sign In with Apple Fails
- Verify capability is added
- Check bundle identifier matches Apple Developer
- Ensure app is signed with correct team

### API Connection Issues
- Verify backend is running
- Check baseURL in APIConfig
- Ensure CORS allows your domain
- Check network permissions in Info.plist

## License

MIT License - See LICENSE file for details