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

- [ ] **CPU, GPU, RAM, tarmoq widgetlari.** Uslublar: raqam, halqa, chiziqli grafik (sparkline). Faqat panel ochiq bo‘lganda o‘lchanadi. *(Band 9; Atoll’dagi Stats tab)*

## 10-bosqich — musiqa

- [ ] **Barcha playerlar (brauzer, YouTube, VLC va boshqalar).** macOS 15.4+ da MediaRemote uchinchi tomon ilovalariga yopiq; `/usr/bin/perl` orqali yuklanadigan kichik yordamchi kutubxona ishlaydi (tajribada tasdiqlandi). Ishlamasa, Spotify/Music AppleScript zaxirasi qoladi. *(Band 4; Boring Notch #417 muammosi)*
- [ ] **Musiqa widgetini qayta dizayn qilish:** katta albom rasmi, manba ilova ikonkasi, progress, boshqaruv. *(Band 4)*
