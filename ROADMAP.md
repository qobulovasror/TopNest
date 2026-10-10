# TopNest rivojlantirish rejasi

Reja kod tahlili (v0.3.0) va notch ilovalari tadqiqotiga (NotchNook, Boring Notch, Alcove, DynamicLake, Atoll, NotchDrop, MediaMate, MewNotch, Droppy, Vibe Island, Claude Island, CodexBar) asoslangan. Har bandda ehtiyoj asosi ko‘rsatilgan.

Holat belgilari: `[ ]` — kutilmoqda, `[x]` — bajarildi, `[-]` — ataylab tashlab ketildi.

## 1-bosqich — asosiy muammolarni tuzatish

- [x] **Compact holatni "qanot"larga ko‘chirish.** Notchli ekranda kontent kamera zonasiga chizilib ko‘rinmaydi. Chap qanotda artwork/ikonka, o‘ngda waveform yoki limit foizi; notch markazi bo‘sh. *Asos: kontent hozir ko‘rinmaydi; ~10 ilova shu naqshda.*
- [x] **Fullscreen rejimi sozlamasi.** Fullscreen ilova ustida panelni yashirish (standart yoqiq). *Asos: Boring #803/#1278/#1359, Alcove #412.*
- [x] **Hover bilan ochilgan panel kursor chiqqanda yopilishi.** *Asos: tasodifiy hover shikoyatlari; hozir faqat bosish yopadi.*
- [x] **Chiqish tugmasini panel sarlavhasidan olish.** Menu bar ikonkasi menyusi va sozlamalarda qoladi. *Asos: yopish tugmasi yonida tasodifiy chiqish xavfi.*
- [x] **Polling kamaytirish.** Musiqa — distributed notification + sekin zaxira tekshiruv; Codex — faqat panel ochilganda yoki 5 daqiqada bir. *Asos: batareya sarfi — raqobatchilarda №1 shikoyat.*
- [x] **Login’da ishga tushish** (`SMAppService`). *Asos: menu bar ilovasidan standart kutilma.*
- [x] **Clipboard: `org.nspasteboard.ConcealedType` / `TransientType` ni hurmat qilish.** *Asos: 3 ta qo‘lda istisno yetarli emas.*

## 2-bosqich — UI/UX sayqali

- [x] **Spring animatsiya + "Harakatni kamaytirish".** `accessibilityReduceMotion` hisobga olinadi. *Asos: Boring #364/#335 — animatsiyani boshqarish talabi.*
- [x] **Panelni ixchamlashtirish** va Home kartalarini sozlamada yoqish/o‘chirish. *Asos: 480×580 katta; NotchNook/Atoll ixcham widget’lari.*
- [x] **Tipografiya va accessibility.** Minimal 11pt, VoiceOver label’lari. *Asos: 10pt matnlar o‘qilishi qiyin.*
- [x] **AI limitlari.** Reset countdown, rang darajalari (yashil→sariq→qizil), ≤20% qolganda bildirishnoma, eskirish mantiqini reset vaqtiga bog‘lash, compact qanotda eng kritik foiz. *Asos: CodexBar, claude-notch-tracker asosiy funksiyasi; TopNest farqlovchi tomoni.*
- [x] **Kalendar.** Notes/location’dan Zoom/Meet/Teams havolasini topib "Qo‘shilish", uchrashuvdan 5 daqiqa oldin notch ogohlantirishi, kalendarlarni tanlash. *Asos: DynamicLake meeting alert, Alcove #429.*

## 3-bosqich — yangi funksiyalar

- [x] **Fayl tokchasi.** Faylni notchga sudrab tashlash, qaytarib sudrab olish, AirDrop. *Asos: 7 ilovada bor; Alcove #99 eng ko‘p so‘ralgan.*
- [x] **Batareya/zaryad live activity.** Zaryadga ulanganda qanotda 2–3 soniya. *Asos: 5 ilovada; IOKit bilan arzon.*
- [x] **Tashqi monitor / notchsiz ekran tanlovi.** Qaysi ekranda ko‘rinishini tanlash, clamshell rejimida to‘g‘ri joylashish. *Asos: Boring #1281, Alcove #45.*
- [x] **Global yorliqlar:** `⌃⌥⌘N` — panel, `⌃⌥⌘V` — clipboard qidiruvi (`⌥⌘Space` Finder qidiruvi bilan, `⌃⌥` VoiceOver bilan to‘qnashgani uchun o‘zgartirildi). *Asos: clipboard klaviaturadan tez ishlatilishi kerak.*
- [x] **Clipboard pin.** Mahkamlangan yozuvlar limitdan tashqari va tepada turadi. *Asos: Droppy, DynamicLake.*

## 4-bosqich — ixtiyoriy kengaytmalar

- [x] **Claude Code Approve/Deny (hook orqali).** Standart o‘chiq; javob bo‘lmasa Claude o‘z oynasida so‘raydi. *Asos: Vibe Island / Claude Island asosiy qiymati.*
- [x] **Mavjud Claude status line bilan zanjirlash.** Foydalanuvchi buyrug‘i chiqishi saqlanadi, TopNest limitlarni o‘qiydi. *Asos: hozir status line bor bo‘lsa ulash rad etiladi.*
- [x] **Ob-havo: soatlik prognoz.** *Asos: o‘rtacha ehtiyoj; tijorat nashridan oldin Open-Meteo litsenziyasi hal qilinsin.*

## Rejaga kiritilmagan

- **Ovoz/yorqinlik HUD** — Accessibility ruxsati, macOS yangilanishlarida tez buziladi.
- **Kamera oynasi, dekorativ effektlar, CPU/stats** — kam foydalaniladi, qo‘shimcha ruxsatlar (Atoll shikoyati).
- **Audio vizualizator** — ScreenCaptureKit ruxsati va batareya yuki; animatsiyali waveform yetarli.

---

# v0.5 — foydalanuvchi sinovidan keyingi reja

Manba: 0.4.0 ni haqiqiy Mac’da sinash natijalari (10 band). Har bir band foydalanuvchi tomonidan kuzatilgan muammo yoki so‘rov, shuning uchun ehtiyoj tasdiqlangan. Raqobatchilardan olingan yondashuv ko‘rsatilgan.

## 5-bosqich — tezkor tuzatishlar

- [x] **Claude limitini ulashdagi birinchi xato.** Ulash paytida eski `claude-usage.json` ko‘rsatilishi mumkin edi. Ulashda eski cache tozalanadi, eskirgan ma’lumot xato kabi emas, “oxirgi ma’lumot” sifatida ko‘rsatiladi. *(Band 1)*
- [x] **Sarlavhadan sanani olib tashlash, kontentni notch ostidan chiqarish.** Kengaytirilgan panelning yuqori qismi notch balandligida bo‘sh “yelka” bo‘ladi; logotip chapda, tugmalar o‘ngda, notch markazi bo‘sh. *(Band 2)*

## 6-bosqich — panel geometriyasi va shakllari

- [x] **Qat’iy, standart o‘lcham.** Boring Notch (640×190) va NotchNook kabi keng va past panel: 680 pt eni, kontent ~210 pt. Tab almashganda o‘lcham o‘zgarmaydi. Sozlamada Ixcham / Standart / Katta. *(Band 3)*
- [x] **Compact shakl uslublari:** Standart (hozirgi), Orolcha (hamma burchak yumaloq), Birlashgan (tepada ekranga qo‘shilib ketadigan botiq burchaklar). *(Band 6)*
- [x] **Kengaytirilgan panel uslublari:** Birlashgan (ekran tepasiga yopishgan, botiq burchak, qora fon — yangi standart), Yopishgan, Suzuvchi (hozirgi). *(Band 7)*
- [x] **Tablar joyi va ko‘rinishi.** Standart — panel ostida; sozlamada tepada/ostida; ko‘rinish: ikonka / matn / ikonka + matn. Tablar ro‘yxati kengaytiriladigan qilinadi. *(Band 5)*

## 7-bosqich — sozlamalar oynasini zamonaviylashtirish

- [x] **Chap panel doim ochiq** (yopish tugmasi olib tashlanadi), shaffof sidebar, to‘liq o‘lchamli kontent, macOS 26+ da Liquid Glass tugmalar (eski tizimlarda oddiy uslub). *(Band 8)*

## 8-bosqich — widget tizimi

- [x] **Widget arxitekturasi.** Har bir karta — widget: turi, o‘lchami (kichik 1×1, o‘rta 2×1, katta 2×2), uslubi, sozlamalari. Asosiy ekran grid bo‘lib, scroll’siz to‘ladi; ma’lumoti yo‘q yoki ruxsati berilmagan widget yashiriladi (masalan, ruxsatsiz kalendar). *(Band 5, 10)*
- [x] **Widget galereyasi sozlamada.** Qo‘shish, olib tashlash, tartiblash, o‘lcham va uslub tanlash. *(Band 10)*
- [x] **Maxsus widgetlar:** URL/JSON (istalgan sayt yoki API’dan qiymat, JSON yo‘li bilan), shell buyrug‘i (istalgan dasturdan chiqish). Widget ta’rifini JSON fayl sifatida import/eksport qilish. *(Band 10)*

## 9-bosqich — tizim statistikasi

- [x] **CPU, GPU, RAM, tarmoq widgetlari.** Uslublar: raqam, halqa, chiziqli grafik (sparkline). Faqat panel ochiq bo‘lganda o‘lchanadi. *(Band 9; Atoll’dagi Stats tab)*

## 10-bosqich — musiqa

- [x] **Barcha playerlar (brauzer, YouTube, VLC va boshqalar).** macOS 15.4+ da MediaRemote uchinchi tomon ilovalariga yopiq; `/usr/bin/perl` orqali yuklanadigan kichik yordamchi kutubxona ishlaydi (tajribada tasdiqlandi). Bu Apple cheklovini chetlab o‘tgani uchun **standart o‘chiq**: standart rejim — rasmiy AppleScript (Spotify/Music); kengaytirilgan rejim sozlamada tushuntirish va rozilik oynasidan keyin yoqiladi, ishlamay qolsa avtomatik standart rejimga qaytadi. *(Band 4; Boring Notch #417 muammosi)*
- [x] **Musiqa widgetini qayta dizayn qilish:** katta albom rasmi, manba ilova ikonkasi, progress, boshqaruv. *(Band 4)*

---

# v0.6 — UI, UX va ishlash

Manba: foydalanuvchi talablari (birinchi foydalanish, widget joylashuvi, musiqa UX, widget sozlamalari, ishlash).

- [x] **Testlar asosi.** `TopNestTests` target; layout, widget holati va musiqa manbasi tanlovi UI’dan ajratilib test qilinadi.
- [x] **Uzluksiz widget grid.** Qat’iy 4×2 sahifalar o‘rniga 2 qatorli, ustunma-ustun to‘ladigan gorizontal grid: bo‘sh sahifa qolmaydi, siljish ustunga yopishadi, widget kam bo‘lsa kartalar kenglikni to‘ldiradi. Panel balandligi o‘zgarmaydi.
- [x] **Widget holatlari va birinchi foydalanish.** Tayyor / vaqtincha bo‘sh (yashiriladi) / sozlash kerak (tushuntirish va tegishli sozlamani ochadigan tugma). Birinchi ishga tushirishda “Xush kelibsiz” kartasi. Musiqa va clipboard roziligisiz yoqilmaydi.
- [x] **Musiqa UX.** Trek yo‘q, Automation ruxsati yo‘q, kengaytirilgan rejim xatosi holatlari; standart rejimda progress boshqariladigan element ko‘rinishida emas; kichik/o‘rta/katta o‘lchamlar tekshiriladi.
- [x] **Widget sozlamalari.** Jonli preview, tugma va klaviatura bilan tartiblash, o‘chirishni qaytarish, “panelda nega ko‘rinmayapti” izohi.
- [x] **Ishlash.** Statistika faqat ko‘rinib turgan tur uchun, fon oqimida o‘lchanadi; kengaytirilgan rejim fallback’i testlar bilan qoplanadi.
- [x] **Yakun.** Release build, vizual tekshiruv, README.

---

# v0.7 — yangi asboblar va widgetlar

Manba: foydalanuvchi so‘rovi (notes, pomodoro, timer, todo, screen time, kalkulyator, Bluetooth batareyasi, ob-havo, tarjima, tizim monitoringi) va kod tahlili. Har bosqich alohida branch va PR, oxirida `swift test` va real Mac’da vizual tekshiruv.

**Har yangi widget uchun umumiy qadamlar** (har bandda takrorlanmaydi):
`WidgetKind` ga tur → `WidgetContext`/`WidgetRules` holatlari + `WidgetRulesTests` → `WidgetView` va kichik/o‘rta/katta ko‘rinishlar → `WidgetLayoutPreview` → kerak bo‘lsa `SettingsPage` → `generate-localizations.py` (4 til) → snapshot test.

## 11-bosqich — asos (keyingi bosqichlar shunga tayanadi)

- [x] **Matn kiritishda panel yopilmasligi.** Panel ichidagi `TextField`/`TextEditor` fokus olganda `markInteracted()`: hover bilan ochilgan panel kursor chiqqanda yopilmaydi. `Esc` — avval fokusni olish, ikkinchisida yopish. *Asos: notes, todo, kalkulyator, tarjima matn kiritadi; hozir `checkHoverExit` 0,4 s da yopadi.*
- [x] **Sozlanadigan tablar.** `AppState.Tab` ga `notes`, `tasks`, `tools` qo‘shiladi; Sozlamalar → Umumiy’da “Ko‘rinadigan tablar” (yoqish/o‘chirish, tartib). “Asosiy” doim bor. 5 tadan ko‘p tabda “Ikonka va matn” avtomatik “Faqat ikonka” ga o‘tadi. *Asos: 600 pt panelga 6+ matnli tab sig‘maydi; ROADMAP Band 5.*
- [x] **Fayl ombori.** `Application Support/TopNest/<nom>.json` ga atomik yozuvchi kichik `JSONFileStore<T: Codable>` (notes, todo kesh, screen time). Buzilgan fayl `.backup` ga ko‘chiriladi. *Asos: `UserDefaults` katta ma’lumot uchun emas.*
- [x] **Compact activity ustuvorligini sof funksiyaga ajratish.** `updateActivity()` mantiqi `ActivityPolicy.resolve(inputs) -> CompactActivity` ga ko‘chadi va test qilinadi. Yangi holatlar uchun joy: `timerDone`, `timer`, `device`, `rain`. Vaqtinchalik (3–5 s) activity’lar uchun umumiy `flash(_:for:)` (hozirgi `showCharging` shundan foydalanadi).
- [x] **Hotkey ro‘yxatini kengaytirish.** Yangi yorliqlar bitta jadvalda (id, tugma, amal), sozlamada ro‘yxat ko‘rinadi; to‘qnashuv bo‘lsa `hotKeyMessage` ko‘rsatiladi.
- **Tekshiruv:** mavjud testlar o‘tadi, hover-yopilish va tab almashish qo‘lda tekshiriladi.

## 12-bosqich — Timer va Pomodoro

- [x] **`FocusTimerService`.** Holat: `mode` (timer / ish / tanaffus), `endDate`, `pausedRemaining`, `cycle`; `UserDefaults` da saqlanadi — uyqu va qayta ishga tushirishdan keyin to‘g‘ri davom etadi. Tick timer yo‘q: view `TimelineView` bilan `endDate` dan chizadi, tugash uchun bitta rejalangan `Task`.
- [x] **Compact qanot.** Chapda progress halqasi (ish — qizil, tanaffus — yashil), o‘ngda monospace `mm:ss` (1 soatdan ko‘p — `65m`). Ustuvorlik: timer tugadi (5 s) > zaryad > uchrashuv > ishlayotgan timer > musiqa > limit.
- [x] **Widget.** Kichik: halqa + vaqt + ▶︎/⏸. O‘rta: 5/10/25/50 tayyor tugmalar, Pomodoro tsikl nuqtalari (●●○○), “+1 daq” tugmasi (scroll gorizontal grid siljishi bilan to‘qnashgani uchun tugma tanlandi).
- [x] **Tugaganda.** Qanot pulsatsiyasi, ovoz (`NSSound`, sozlamada tanlanadi/o‘chiriladi), `UNNotification` “+5 daq” / “Tanaffus” amallari bilan.
- [x] **Sozlamalar sahifasi.** Ish/qisqa/uzun tanaffus davomiyligi, uzun tanaffusgacha tsikllar, tanaffusni avtomatik boshlash, ovoz.
- [x] **Yorliq** `⌃⌥⌘T` — boshlash/pauza.
- **Tekshiruv:** servis testlari (pauza/davom, tsikl o‘tishi, eskirgan `endDate` tiklanishi), qanot snapshot.

## 13-bosqich — Kalkulyator va “Asboblar” tabi

- [ ] **Ifoda parseri.** Shunting-yard: `+ − × ÷ ^ %`, qavslar, o‘nlik vergul/nuqta, `NSExpression` ishlatilmaydi (noto‘g‘ri ifodada ObjC exception). To‘liq unit testlar.
- [ ] **UI.** Bitta ifoda maydoni, natija yozish davomida, `Enter` — natijani nusxalash, oxirgi 3 hisob tarixi (bosilsa qayta qo‘yiladi).
- [ ] **Joylashuv.** Kichik widget (oxirgi natija + maydon) va “Asboblar” tabi (kalkulyator; 18-bosqichda tarjima qo‘shiladi).
- **Tekshiruv:** parser testlari, kichik panel o‘lchamida maydon sig‘ishi.

## 14-bosqich — Notes

- [ ] **`NotesStore`.** Bir nechta qayd, birinchi qator — sarlavha, 0,5 s debounce bilan avtomatik saqlash (`JSONFileStore`).
- [ ] **“Qaydlar” tabi.** Chapda ro‘yxat, o‘ngda `TextEditor`; qidiruv, o‘chirish + qaytarish, mahkamlash.
- [ ] **Widget.** O‘rta/katta: oxirgi (yoki mahkamlangan) qayd ko‘rinishi, bosilganda joyida tahrirlash.
- [ ] **Kirish yo‘llari.** Matnni notchga sudrash (`onDrop` ga `.plainText`), clipboard yozuvi menyusida “Qaydga qo‘shish”, `⌃⌥⌘J` — yangi qayd bilan panel ochiladi.
- **Tekshiruv:** store testlari (saqlash, buzilgan fayl), drop va hotkey qo‘lda.

## 15-bosqich — Todo (Reminders)

- [ ] **`RemindersService`** (EventKit, kalendar servisiga o‘xshash). `Info.plist` ga `NSRemindersFullAccessUsageDescription`. Holatlar: ruxsat so‘ralmagan / rad etilgan / bor — mavjud `SetupAction` naqshi bilan.
- [ ] **Widget.** O‘rta: bugungi va muddati o‘tgan 3 vazifa, checkbox, “+” bilan joyida qo‘shish; belgilanganda chiziladi, 1 s keyin yo‘qoladi, “Qaytarish”. Muddati o‘tgan — qizil.
- [ ] **“Vazifalar” tabi.** Ro‘yxat tanlash, barcha vazifalar, muddat qo‘yish.
- [ ] **Sozlamalar.** Qaysi ro‘yxatlar ko‘rinadi, bajarilganlarni yashirish.
- **Tekshiruv:** `WidgetRules` holatlari, Reminders bilan iPhone sinxroni qo‘lda.

## 16-bosqich — Bluetooth qurilmalar batareyasi

- [ ] **`DeviceBatteryService`.** Magic Keyboard/Mouse/Trackpad — IOKit registry `BatteryPercent` (ruxsatsiz). AirPods va quloqchinlar — fonda `system_profiler SPBluetoothDataType -json` (5 daqiqada bir va ulanishda). Parser test qilinadi (namuna JSON bilan).
- [ ] **Ulanish hodisasi.** IOBluetooth connect bildirishnomasi; kerak bo‘lsa `NSBluetoothAlwaysUsageDescription`.
- [ ] **Live activity.** Ulanganda qanotda 3 s: qurilma ikonkasi + foiz (`flash`). ≤20% da bir martalik bildirishnoma.
- [ ] **Widget.** Kichik: eng kam zaryadli qurilma. O‘rta: 3 tagacha qurilma (ikonka + halqa), ixtiyoriy Mac batareyasi (`PowerService`).
- **Tekshiruv:** parser testlari, AirPods va Magic Mouse bilan real tekshiruv.

## 17-bosqich — Tizim monitoringini yaxshilash

- [ ] **“Tizim” kombinatsiyalangan widgeti** (o‘rta): CPU/RAM/GPU/Net 4 ta mini halqa.
- [ ] **Yangi ko‘rsatkichlar.** Disk bo‘sh joyi, batareya salomatligi va sikllar soni (IOKit `AppleSmartBattery`).
- [ ] **Top jarayonlar.** Widget bosilganda eng ko‘p CPU/RAM ishlatayotgan 3 jarayon (popover).
- [ ] **Ogohlantirish.** CPU 2 daqiqadan ko‘p ≥90% bo‘lsa (sozlamada yoqiladi). SMC harorati — rejaga kiritilmaydi.
- **Tekshiruv:** `SystemStatsTests` kengaytiriladi, faqat ko‘rinib turgan tur o‘lchanishi saqlanadi.

## 18-bosqich — Tarjima

- [ ] **Apple Translation** (macOS 15+, qurilmada). `#available` bilan; macOS 14 da widget “macOS 15 kerak” sababi bilan yashiriladi. `LanguageAvailability` bilan til juftligi tekshiriladi, til paketi yo‘q bo‘lsa yuklab olish taklifi.
- [ ] **Ixtiyoriy tashqi provayder** (o‘zbek tili uchun). API kaliti Keychain’da, standart o‘chiq, matn tashqariga yuborilishi sozlamada aniq yoziladi.
- [ ] **UI.** “Asboblar” tabida: manba/natija, ⇄ tugmasi, nusxalash. Clipboard’dagi oxirgi matn taklif qilinadi. Kichik widget — oxirgi tarjima.
- [ ] **Yagona tez maydon.** Asboblar tabida bitta maydon: ifoda bo‘lsa hisoblaydi, matn bo‘lsa tarjima qiladi (aniqlash funksiyasi test qilinadi).
- **Tekshiruv:** macOS 14 va 15+ da holatlar, provayder kalitisiz holat.

## 19-bosqich — Screen time (o‘z hisoblagichi)

- [ ] **`ScreenTimeTracker`.** `NSWorkspace.didActivateApplicationNotification`, faolsizlik (`CGEventSource.secondsSinceLastEventType`, 2 daqiqa chegarasi), ekran qulfi va uyqu hodisalari. Kunlik yig‘indi `JSONFileStore` da, 30 kundan eskisi o‘chiriladi. Xususiy `knowledgeC.db` ishlatilmaydi.
- [ ] **Rozilik.** Clipboard kabi standart o‘chiq, sozlamada tushuntirish, ma’lumot faqat qurilmada, “Tarixni tozalash”.
- [ ] **Widget.** Kichik: bugungi jami. O‘rta: top-3 ilova (ikonka + chiziq). Katta: haftalik ustunli grafik (Swift Charts).
- [ ] **Tanaffus eslatmasi.** Sozlangan muddat (masalan 90 daq) uzluksiz ishlansa — qanot/bildirishnoma, Pomodoro bilan bog‘lanadi.
- **Tekshiruv:** yig‘ish mantiqi testlari (ilova almashuvi, faolsizlik, kun chegarasi).

## 20-bosqich — Ob-havoni yaxshilash

- [ ] **Katta o‘lcham:** 5 kunlik prognoz, yog‘ingarchilik ehtimoli, “his qilinishi”.
- [ ] **Birliklar** °C/°F, **ixtiyoriy joylashuv** (CoreLocation, `NSLocationUsageDescription`), bosilganda Weather ilovasi.
- [ ] **Yomg‘ir ogohlantirishi.** Keyingi 30 daqiqada yog‘ingarchilik bo‘lsa qanotda `rain` activity.
- **Tekshiruv:** Open-Meteo javobi parser testlari.

## 21-bosqich — qo‘shimcha g‘oyalar

- [ ] **Valyuta kursi (CBU.uz)** — native emas, extension katalogiga JSON paket.
- [ ] **Namoz vaqtlari** — widget va vaqtdan 10 daqiqa oldin qanot ogohlantirishi (uchrashuv naqshi).
- [ ] **Dunyo soatlari** — kichik widget, 2–3 shahar.
- [ ] **Shortcuts tugmalari** — `shortcuts run` orqali 4 ta tez amal.
- [ ] **Yuklab olish progressi** — `~/Downloads` dagi `.download`/`.crdownload` kuzatuvi, qanotda foiz.
- [ ] **Focus/DND holati** — compact qanotda kichik ikonka.

## 22-bosqich — yakun

- [ ] Barcha yangi widgetlar uchun snapshot testlar, 4 tilda tarjimalar tekshiruvi.
- [ ] `Info.plist` ruxsat matnlari (Reminders, Bluetooth, Location) 4 tilda.
- [ ] README jadvali va Extensions sahifasi yangilanadi, versiya `0.7.0`.
- [ ] Release build, real Mac’da (notchli va tashqi ekran) vizual tekshiruv.
