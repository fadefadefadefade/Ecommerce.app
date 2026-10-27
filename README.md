# ALVY Mobile App (Flutter)

The ALVY marketplace on Android: buyers, sellers, riders / couriers and logistics companies.
(The admin panel is on the website only.)

## One backend, one server

The app has no backend of its own. It talks to the website (`Ecommerce.web`) through `/api/v1`,
which runs the website's own controllers, so the rules, messages and data are the same on both.

```
Website (browser)  ─┐
                    ├──> https://alvy.trade (Cloudflare tunnel) ──> Ecommerce.web (port 8000) ──> ecommerce_db
Mobile app (phone) ─┘
```

Keep `Ecommerce.web` running on port 8000 (`php artisan serve` in `Ecommerce.web`); the tunnel and the app both use it.

## Which server the app uses

- **Built-in:** `https://alvy.trade`.
- **When building:** `flutter run --dart-define=API_URL=http://10.0.2.2:8000` (Android emulator).
- **In the app:** Login → **Server** (type an address, **Test**, **Save**). Examples:
  - Live site: `https://alvy.trade`
  - Phone on USB: run `adb reverse tcp:8000 tcp:8000`, then `http://127.0.0.1:8000`
  - Emulator: `http://10.0.2.2:8000`

One login for every account (buyers, sellers, riders and logistics companies), like the website's `/login`.

## Run and build

```bash
flutter pub get
flutter run                                   # uses https://alvy.trade
flutter build apk --release                   # build/app/outputs/flutter-apk/app-release.apk
```

## Publish the app on the website

People download the app from **https://alvy.trade/app** ("Get the app" in the website footer). To publish a new version:

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ../Ecommerce.web/storage/app/app-releases/ALVY.apk
```

The APK stays out of git (`storage/app` is ignored).

If Gradle says "Network is unreachable" while building on a network that only has IPv6, set
`JAVA_TOOL_OPTIONS=-Djava.net.preferIPv6Addresses=true` for the build (stop the old Gradle daemon first).

## Tests

```bash
flutter analyze
flutter test                                  # unit / widget tests (the e2e ones skip without API_URL)
```

End-to-end tests run against a real `Ecommerce.web` on a **throwaway** database (never `ecommerce_db`),
seeded with `SampleLogisticsSeeder`:

```bash
# host-side widget e2e
flutter test test/e2e_seller_flow_test.dart --dart-define=API_URL=http://127.0.0.1:8095
# on an emulator / phone
flutter test integration_test/rider_flow_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8095
```

## History

The old separate backend (`Ecommerce.app/api`) was removed when the app moved to the website's API.
A copy is kept in `Ecommerce.web/storage/backups/old_mobile_backend_Ecommerce.app-api_20261020.zip`.
