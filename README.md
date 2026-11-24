# FitnessForLovers - iOS App

A SwiftUI app for sharing health data between two Apple devices, setting shared fitness goals, and tracking progress together.

## Features

- **Apple Sign In** - Secure authentication using Apple ID
- **HealthKit Integration** - Sync health data from Apple Health
- **Partner Pairing** - Invite and connect with a partner
- **Shared Goals** - Create and track fitness goals together
- **Real-time Dashboard** - View your and your partner's health metrics
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

The app communicates with a Node.js/Fastify backend running on `http://localhost:3000`.

### API Endpoints Used

| Feature | Endpoints |
|---------|-----------|
| Auth | `POST /auth/apple`, `POST /auth/refresh`, `GET /auth/me`, `POST /auth/logout` |
| Pairings | `GET/POST /pairings`, `POST /pairings/:id/respond`, `PATCH/DELETE /pairings/:id` |
| Health Data | `POST /health-data/bulk`, `GET /health-data/summary`, `GET /health-data/partner/:id` |
| Goals | `GET/POST /goals`, `GET/PATCH/DELETE /goals/:id`, `GET /goals/:id/progress` |
| Dashboard | `GET /dashboard` |
| User | `GET/PATCH /users/me`, `GET/PATCH /users/me/preferences` |
| Devices | `POST /devices`, `GET/PATCH/DELETE /devices/:id` |
| Notifications | `GET /notifications`, `PATCH /notifications/:id/read` |

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Apple Developer Account (for HealthKit & Sign In with Apple)

## Setup

### 1. Configure Xcode Project

1. Open `FitnessForLovers.xcodeproj` in Xcode
2. Select the project target
3. **Signing & Capabilities**:
   - Add **Sign In with Apple** capability
   - Add **HealthKit** capability
   - Enable **Background Modes** → **Background fetch** & **Remote notifications**
4. **Info.plist** - Add required keys:
   ```xml
   <key>NSHealthShareUsageDescription</key>
   <string>We need access to your health data to sync with your partner</string>
   <key>NSHealthUpdateUsageDescription</key>
   <string>We write workout data to HealthKit</string>
   ```

### 2. Configure Backend URL

In `Services/APIService.swift`, update the base URL:
```swift
struct APIConfig {
    static let baseURL = "https://your-api-domain.com" // Production
    // static let baseURL = "http://localhost:3000" // Development
}
```

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
2. Connect your iPhone (required for HealthKit)
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

1. User taps "Sign in with Apple"
2. `AuthManager` handles ASAuthorization
3. Identity token sent to `/auth/apple`
4. Backend returns JWT access/refresh tokens
5. Tokens stored securely in Keychain
6. Subsequent requests include Bearer token
7. Automatic token refresh on 401

### HealthKit Sync

1. User grants HealthKit permissions
2. `HealthKitService` reads quantity/category samples
3. Samples converted to backend DTO format
4. Bulk synced via `/health-data/bulk`
5. Background delivery enabled for real-time updates

## Key Components

### APIService (Actor)
- Thread-safe network requests
- Automatic token refresh
- Request/response logging
- Error handling with typed errors

### AuthManager (@ObservableObject)
- Current user state
- Apple Sign In flow
- Session restoration
- Sign out handling

### HealthKitService (@ObservableObject)
- Authorization management
- Sample querying & conversion
- Background delivery
- Sync scheduling

### ViewModels (@ObservableObject)
- Reactive UI state
- Data fetching & caching
- User action handling
- Cross-view notifications

## Testing

### Unit Tests
```bash
# Run tests in Xcode
Cmd+U
```

### UI Tests
```bash
# Run UI tests
xcodebuild test -scheme FitnessForLoversUITests
```

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

- Tokens stored in Keychain (not UserDefaults)
- Health data only synced with explicit user consent
- No health data stored locally unencrypted
- Partner data access controlled by sharing scope
- All API communication over HTTPS (production)

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