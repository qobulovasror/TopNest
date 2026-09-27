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
