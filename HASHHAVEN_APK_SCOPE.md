# HashHaven: Crypto Factory
## Final Scope untuk APK Android Offline

**Target:** satu game Android offline-first yang bisa dimainkan tanpa login, server, internet, wallet, atau blockchain. Output akhir: APK debug untuk testing dan APK release untuk instalasi.

> Credits, Energy, Hash Power, Data Chips, dan semua reward adalah nilai fiktif di dalam game. Game ini tidak melakukan cryptocurrency mining nyata dan tidak menjanjikan keuntungan finansial.

---

## 1. Ringkasan game

Pemain mengelola pusat mining futuristik bernama **HashHaven**. Pemain membeli dan meningkatkan miner rig, mengelola energi dan temperatur, memainkan mini-game untuk mendapatkan boost, membeli item dari toko, dan memperbesar factory.

Core loop:

```text
Collect offline earnings
 → Inspect factory
 → Mine Now / play mini-game
 → Manage heat + energy
 → Upgrade rigs
 → Buy/use shop items
 → Unlock progress
 → Save locally
```

---

## 2. Fitur wajib APK offline MVP

### Factory dashboard

- Credits
- Energy
- XP dan Level
- Hash Power per detik
- Produksi per menit
- Temperatur factory
- Durability/status miner
- Machine cards
- Empty build slot
- Tombol `MINE NOW`
- Tombol `COOL DOWN`
- Quick Run mini-game

### Miner rigs

Rigs awal:

- GPU 01 / Neon Miner X2
- ASIC 02 / Frost ASIC
- FAN CORE / Cooling Array
- Empty Build Slot

Statistik rig:

- Base hash power
- Heat
- Energy usage
- Durability
- Level
- Online/offline state

### Upgrade system

Upgrade wajib:

1. **Overclock Core**
   - Menambah Hash Power
   - Menambah Heat
2. **Smart Ventilation**
   - Mengurangi Heat
3. **Power Saver**
   - Mengurangi pemakaian Energy
4. **Cooling AI**
   - Mengurangi Heat
   - Menambah Durability
5. **Battery Buffer**
   - Menambah kapasitas Energy
   - Sedikit menambah Heat

Aturan:

- Upgrade memiliki level dan max level.
- Cost meningkat sekitar ×1.35 per level.
- Pembelian harus atomic: validasi Credits → kurangi Credits → tambah level → recalculate stats → save.
- Upgrade production harus memiliki trade-off.
- Upgrade tidak boleh menumpuk dua kali akibat widget rebuild.

### Toko item

Item awal:

- **Coolant Pack** — mengurangi temperatur 18°C.
- **Energy Cell** — memulihkan 25 Energy.
- **Hash Booster** — boost Hash Power sementara.
- **Repair Kit** — memulihkan Durability.
- **Spare Fan** — mengurangi Heat pasif.
- **Data Chip** — menambah XP atau membuka research.

Sistem toko:

- Harga menggunakan Credits fiktif.
- Item dibeli dan masuk Inventory.
- Item consumable berkurang saat digunakan.
- Inventory disimpan lokal.
- Tampilkan harga, deskripsi, quantity, dan efek item.
- Tidak ada pembayaran nyata atau in-app purchase pada MVP.

### Mini-games

#### 1. Cooling Panic

- Tap fan node yang benar.
- Combo sampai 5.
- Reward Credits.
- Mengurangi temperatur.

#### 2. Hash Runner

- 3 lane signal routing.
- Target lane bercahaya.
- Timer 45 detik.
- Tap lane benar untuk maju.
- Salah mengurangi score, reset combo, dan mengurangi 1,5 detik.
- Keyboard/gamepad support untuk source lintas platform.
- Pause/resume.
- Haptic feedback.
- Auto-pause ketika Android app masuk background.
- Menghasilkan `HashRunnerResult` dan reward diterapkan oleh FactoryScreen satu kali.

### Heat dan Energy

| Kondisi | Behavior |
|---|---|
| 0–69% heat | Normal production |
| 70–89% heat | Amber warning, tombol Cool Down |
| 90–99% heat | Production slowdown, critical warning |
| 100% heat | Rig berhenti sementara, recovery action tetap tersedia |
| Energy 0 | Mining pause, Cool Down/Repair/Rest tetap bisa dilakukan |

Tidak boleh ada soft-lock ketika Energy habis atau temperatur mencapai 100%.

### Offline earnings

- Save timestamp terakhir.
- Reward dihitung saat app dibuka kembali.
- Offline cap: 8 jam.
- Offline multiplier: 25% produksi normal.
- Reward hanya diterapkan satu kali.
- Tidak membutuhkan internet atau server.

### Local save

Gunakan `SharedPreferences` untuk MVP.

Simpan:

- schema version
- Credits
- Energy
- Temperature
- XP
- Level
- completed mini-games
- machine levels dan stats
- upgrade levels
- shop inventory
- active boosts
- lastSaved timestamp

Tambahkan migration ketika field baru diperkenalkan agar save lama tidak crash.

---

## 3. UI/UX Android

### Portrait

Urutan tampilan:

```text
Header
 → Resource strip
 → Hash Power hero card
 → Machine grid 2 kolom
 → Temperature warning
 → Quick Run
 → Mine Now CTA
 → Bottom navigation
```

Bottom navigation:

- Factory
- Mini-games
- Upgrades
- Shop
- Inventory / Crew

### Landscape

```text
Navigation rail
 → Factory floor
 → Live readout panel
```

Live readout:

- Hash Power
- Temperature
- Energy
- XP
- Collect/Mine CTA

### Visual style

- Background: `#080B14`
- Surface: `#111827`
- Elevated: `#172238`
- Mint: `#49F2C2`
- Violet: `#7C5CFF`
- Amber: `#FFB547`
- Coral: `#FF5C7A`
- Font: Inter/Manrope
- Numeric data: monospace
- Minimum touch target: 48dp
- Primary CTA: 56dp
- Safe-area aware

### Accessibility

- High contrast mode
- Reduce motion mode
- Haptic toggle
- Sound/music toggle
- Android font scaling sampai 130%
- Status tidak hanya menggunakan warna
- Semua icon memiliki semantic label
- Tidak ada aksi penting yang hanya bisa dilakukan dengan drag

---

## 4. Navigation screen

```text
Factory
 ├─ Machine detail
 ├─ Mine Now
 ├─ Temperature
 └─ Offline earnings

Mini-games
 ├─ Cooling Panic
 └─ Hash Runner

Upgrades
 ├─ Miner upgrades
 ├─ Cooling upgrades
 ├─ Energy upgrades
 └─ Research unlocks

Shop
 ├─ Consumables
 ├─ Boosts
 ├─ Machine parts
 └─ Decorations

Inventory
 ├─ Use item
 ├─ Quantity
 └─ Active boosts

Settings
 ├─ Sound
 ├─ Haptics
 ├─ Accessibility
 ├─ Reset local save
 └─ About
```

---

## 5. Android behavior

- Portrait dan landscape didukung.
- Rotasi mempertahankan state dan modal.
- Android Back:
  1. Tutup bottom sheet/dialog.
  2. Pause mini-game.
  3. Kembali ke Factory.
  4. Keluar hanya dengan konfirmasi.
- App background otomatis menyimpan game.
- Mini-game otomatis pause saat app tidak aktif.
- Game dapat dimainkan tanpa internet.
- APK tidak membutuhkan permission jaringan pada MVP.

---

## 6. Struktur source yang diharapkan

```text
lib/
├─ main.dart
├─ models/
│  ├─ miner_machine.dart
│  ├─ upgrade.dart
│  ├─ shop_item.dart
│  └─ game_state.dart
├─ controllers/
│  ├─ factory_controller.dart
│  ├─ economy_controller.dart
│  └─ save_controller.dart
├─ screens/
│  ├─ factory_screen.dart
│  ├─ upgrade_screen.dart
│  ├─ shop_screen.dart
│  └─ inventory_screen.dart
├─ minigames/
│  ├─ cooling_panic_screen.dart
│  └─ hash_runner_screen.dart
└─ widgets/
   ├─ resource_strip.dart
   ├─ machine_card.dart
   ├─ upgrade_card.dart
   ├─ shop_item_card.dart
   └─ temperature_card.dart
```

Current prototype already contains:

- `lib/main.dart`
- `lib/minigames/hash_runner_screen.dart`
- `test/hash_runner_controller_test.dart`
- Android Gradle/Manifest source
- `SharedPreferences` save

Next implementation step is refactoring models into the structure above and adding Upgrade + Shop screens.

---

## 7. Acceptance checklist sebelum APK dibagikan

### Gameplay

- [ ] First launch menampilkan Factory tanpa error.
- [ ] `Mine Now` menambah Credits dan meningkatkan Heat.
- [ ] Production berjalan setiap detik.
- [ ] Upgrade mengurangi Credits sekali dan menaikkan level sekali.
- [ ] Upgrade max level tidak bisa dibeli lagi.
- [ ] Shop purchase masuk Inventory.
- [ ] Item use mengubah resource sesuai efek.
- [ ] Cooling Panic dapat selesai dan memberi reward satu kali.
- [ ] Hash Runner dapat selesai dan memberi reward satu kali.
- [ ] Heat 100% masih dapat dipulihkan.
- [ ] Energy 0 tidak membuat game terkunci.

### Save

- [ ] Tutup dan buka app mempertahankan progress.
- [ ] Offline earnings muncul maksimal 8 jam.
- [ ] Offline reward tidak diduplikasi.
- [ ] Save lama tanpa upgrades/shop fields tetap bisa dibaca.
- [ ] Reset save membutuhkan aksi sadar.

### Android

- [ ] Portrait tidak overflow pada 360×800.
- [ ] Landscape terbaca pada 800×360.
- [ ] Font scale 130% tidak memotong CTA.
- [ ] Back button bekerja bertahap.
- [ ] App pause/resume tidak menggandakan timer.
- [ ] Build debug berhasil.
- [ ] APK bisa di-install di Android test device.
- [ ] Build release ditandatangani dengan keystore pemilik aplikasi.

---

## 8. Build APK final

Di komputer yang memiliki Flutter SDK, Android SDK, Java, dan Android Studio:

```bash
cd HashHaven-Flutter
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

APK debug:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Untuk APK release:

```bash
flutter build apk --release
```

Sebelum distribusi, gunakan keystore milik pemilik game dan jangan memasukkan keystore ke repository.

---

## Status saat ini

**Sudah tersedia:**

- Flutter offline source.
- Responsive Factory UI.
- Idle production.
- Heat dan Energy.
- Local save.
- Offline earnings.
- Cooling Panic.
- Hash Runner lengkap.
- Android Manifest, Gradle, MainActivity, dan icon.
- Source ZIP.

**Masih perlu diproses untuk release APK final:**

- Refactor model agar Upgrade dan Shop menjadi screen terpisah.
- Implementasi Upgrade registry dan Inventory.
- Implementasi Shop UI.
- Jalankan `flutter analyze` dan `flutter test` pada mesin dengan Flutter SDK.
- Build APK debug.
- Test pada device Android nyata.
- Perbaiki balance dan performa setelah device playtest.
- Build release dan signing.
