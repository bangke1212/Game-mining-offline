# HashHaven Flutter MVP

Source code Android offline-first untuk **HashHaven: Crypto Factory**.

## Fitur yang sudah dibuat

- Factory dashboard responsif portrait dan landscape.
- Credits, Energy, XP, Level, Hash Power, dan Temperature.
- Produksi idle per detik.
- Offline earnings maksimal 8 jam menggunakan `SharedPreferences`.
- Machine cards, upgrade cost, cooling, heat slowdown, dan machine status.
- Mini-game **Cooling Panic** dengan target fan node dan reward.
- Mini-game **Hash Runner** tersedia di `lib/minigames/hash_runner_screen.dart` dengan lane grid, combo, timer, pause/resume, keyboard/gamepad, haptic, dan `HashRunnerResult`.
- `Mine Now` primary action dengan haptic feedback.
- Local save otomatis saat app background dan setiap beberapa detik.
- Android back-safe settings sheet dan reset local save.
- Full-sensor orientation untuk portrait/landscape.
- Tidak membutuhkan login, server, database, wallet, atau internet.

## Menjalankan di komputer dengan Flutter

```bash
flutter pub get
flutter run
```

Build APK debug:

```bash
flutter build apk --debug
```

Build APK release unsigned/signed sesuai keystore lokal:

```bash
flutter build apk --release
```

File output biasanya berada di:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Catatan source

Sandbox implementasi saat ini tidak memiliki Flutter SDK, Android SDK, `adb`, atau Gradle, sehingga APK belum bisa dikompilasi dan dipasang dari environment ini. Source Flutter dan konfigurasi Android sudah disiapkan; pada komputer developer jalankan `flutter pub get`, lalu `flutter run` atau `flutter build apk`.

Jangan masukkan `android/local.properties`, keystore, atau file signing ke repository.

## Save data

Save key: `hashhaven.save` pada `SharedPreferences`. Reset tersedia dari Settings. Offline earnings memakai 25% dari produksi normal dan dibatasi 8 jam.

## Produk

Credits, Energy, Hash Power, dan Data Chips adalah mata uang fiktif internal game. MVP ini tidak melakukan mining nyata, tidak memakai cryptocurrency nyata, dan tidak menjanjikan keuntungan finansial.
