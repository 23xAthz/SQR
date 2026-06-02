# SQR — Secure QR Resolver

Privacy-aware QR phishing analysis app for Android, built with Flutter.

## Project Structure

```
lib/
├── main.dart                        # Entry point + bottom nav shell
├── core/
│   └── theme/app_theme.dart         # Dark theme, colors
├── domain/
│   └── entities/scan_result.dart    # All entities, enums
├── data/
│   ├── local/database_helper.dart   # SQLite — scans + flagged_domains
│   └── services/
│       ├── url_analyzer.dart        # Structural + intent analysis
│       ├── upi_parser.dart          # UPI payment intent parsing
│       ├── risk_scorer.dart         # Weighted heuristic risk scoring
│       └── redirect_tracer.dart     # HEAD-based redirect chain tracer
└── presentation/
    ├── providers/scan_notifier.dart # Riverpod state + all providers
    ├── widgets/common_widgets.dart  # RiskBadge, SqrCard, InfoRow, etc.
    └── screens/
        ├── scanner_screen.dart      # QR camera + viewfinder overlay
        ├── analysis_screen.dart     # URL breakdown + context selection
        ├── risk_screen.dart         # Score, signals, friction, decisions
        ├── preview_screen.dart      # Restricted WebView (JS off)
        └── history_screen.dart      # Past scans from SQLite
```

## Setup

### 1. Flutter environment
```bash
flutter --version   # requires >=3.19.0
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Android permissions
Copy contents of `android_manifest_note.xml` into:
`android/app/src/main/AndroidManifest.xml`

The manifest needs:
- `CAMERA` permission
- `INTERNET` permission
- `android:usesCleartextTraffic="true"` for HTTP redirect tracing
- UPI scheme in `<queries>`

### 4. Minimum SDK
In `android/app/build.gradle`:
```groovy
android {
    defaultConfig {
        minSdkVersion 21   // required by mobile_scanner
        targetSdkVersion 34
    }
}
```

### 5. Run
```bash
flutter run
```

## Pipeline

```
SCAN → DECODE → CLASSIFY PAYLOAD → SHOW ANALYSIS SCREEN
    → USER SELECTS CONTEXT → RUN RISK ASSESSMENT
    → SHOW RISK SCREEN (5s friction for medium/high)
    → USER DECISION: Preview | Browser | Block | Dismiss
```

## Risk Scoring Weights

| Signal                        | Points |
|-------------------------------|--------|
| HTTP (not HTTPS)              | +20    |
| IP-based URL                  | +30    |
| URL shortener                 | +25    |
| Punycode / homograph          | +25    |
| Suspicious keywords (cap 30)  | +10ea  |
| Context mismatch — unusual    | +20    |
| Context mismatch — high       | +35    |
| Redirect depth 1              | +10    |
| Redirect depth 2              | +20    |
| Redirect depth 3+             | +30    |
| Threat intel flagged          | +40    |
| Previously flagged domain     | +30    |

Score: 0–30 = Low · 31–60 = Medium · 61–100 = High

## Key Design Decisions

- **No auto-execution**: scanner pauses on detect, user must confirm
- **Deliberate friction**: 5-second countdown before Medium/High risk URLs can be opened
- **Offline-first**: all structural analysis runs without network; redirect trace is optional
- **Local-only storage**: QR hash + metadata in SQLite, no raw payload stored
- **Explainable risk**: every signal shown in plain language alongside the score

## Adding Threat Intel (Optional)

In `scan_notifier.dart`, `runAnalysis()`, after the redirect trace:
```dart
// Example: VirusTotal
final vtResult = await VirusTotalService.check(ua.domain);
final threatFlagged = vtResult?.malicious == true;
```
Then pass `threatIntelFlagged: threatFlagged` to `_riskScorer.score()`.