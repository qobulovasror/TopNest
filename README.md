# TopNest 0.4.0

macOS notch uchun native Swift prototipi. macOS 14 yoki yangi versiya kerak.

## Ishlatish

`TopNest.app` ni oching. Notch markazidagi kapsulani bosing. Panelda `Asosiy` va `Clipboard` bo‘limlari bor. Yuqoridagi tishli g‘ildirak tugmasi barcha sozlamalarni alohida macOS oynasida ochadi. Sozlamalarni `⌘,` orqali ham ochish mumkin. Panelni `Esc` yoki uning tashqarisiga bosish bilan yoping. Kapsulaga kursor olib borganda ochish sozlamadan ixtiyoriy yoqiladi; hover bilan ochilgan panel kursor chiqqach o‘zi yopiladi. Menu bar ikonkasini chap bosish panelni ochadi, o‘ng bosish menyuni (sozlamalar, chiqish) ko‘rsatadi.

Notchli ekranda kapsula notchning o‘zini qoplaydi va ko‘rinmaydi; musiqa ijro etilganda notch yonida qanotlar (albom rasmi va waveform) paydo bo‘ladi. Boshqa ekranda o‘lchami 220 × 32 punkt. Fullscreen ilova ochilganda panel standart holatda yashiriladi. Sozlamalarda tizimga kirganda ishga tushirishni yoqish mumkin.

Avvalgi Nukta 0.2 sozlamalari TopNest birinchi ishga tushganda bir marta ko‘chiriladi. Paket identifikatori o‘zgargani uchun macOS Music/Spotify Automation va kalendar ruxsatlarini qayta so‘rashi mumkin. Claude Code status line oldingi Nukta yo‘liga ulangan bo‘lsa, TopNest sozlamasidagi ulash tugmasi uni yangi yo‘lga o‘tkazadi. Boshqa status line sozlamalariga tegilmaydi.

## Mavjud funksiyalar

- Widgetlar: asosiy ekran 2 qatorli grid, vertikal scroll yo‘q. Widgetlar ustunma-ustun joylashadi (bo‘sh sahifa qolmaydi); 4 ustundan ko‘pi gorizontal siljitiladi yoki ‹ › tugmalari bilan ochiladi, kam bo‘lsa kartalar markazda turadi. Widget o‘lchami kichik (1 katak), o‘rta (2) yoki katta (4). Har bir widget uch holatdan birida: tayyor; vaqtincha bo‘sh (masalan, uchrashuv yo‘q) — yashiriladi; sozlash kerak (ruxsat yoki modul o‘chiq) — sabab va tegishli sozlamani ochadigan tugmali kichik karta. Musiqa va clipboard hech qachon o‘zi yoqilmaydi. Birinchi ishga tushirishda “Xush kelibsiz” kartasi nimani qanday yoqishni tushuntiradi. Sozlamalar → Widgetlar bo‘limida jonli sxema (preview), qo‘shish, olib tashlash (qaytarish mumkin), sudrab yoki ↑ ↓ tugmalari bilan tartiblash, o‘lcham tanlash va har widget panelda nega ko‘rinmayotgani ko‘rsatiladi. Maxsus widget istalgan HTTPS API’dan (JSON yo‘li bilan) yoki shell buyrug‘i chiqishidan qiymat oladi; ta’rifini JSON fayl sifatida eksport/import qilish mumkin (buyruqli widget importida buyruq matni ko‘rsatilib, tasdiq so‘raladi).
- Tizim statistikasi: CPU, RAM, GPU va tarmoq (faqat Wi-Fi/Ethernet) widgetlari; uslub — raqam, halqa yoki grafik. Faqat ko‘rinib turgan widget turi har 2 soniyada, fon oqimida o‘lchanadi (masalan, faqat CPU widgeti bo‘lsa GPU va tarmoq so‘ralmaydi).

- Musiqa (standart rejim): Spotify va Apple Music — trek nomi, ijro holati, davomiyligi, play/pause va trek almashtirish rasmiy AppleScript orqali. Kuzatuv dastlab o‘chiq; yoqilganda macOS Automation ruxsati so‘ralishi mumkin.
- Musiqa (kengaytirilgan rejim, ixtiyoriy): istalgan player (brauzer, Yandex Music, VLC va boshq.), albom rasmi va progressni bosib o‘tkazish. macOS 15.4+ da Apple bu ma’lumotni uchinchi tomon ilovalariga yopgan; rejim tizimdagi `/usr/bin/perl` ichida ishlaydigan kichik yordamchi (`Contents/Frameworks/libTopNestMediaBridge.dylib`) orqali oladi. Bu rasmiy yo‘l emas, shuning uchun standart o‘chiq va Sozlamalar → Musiqa bo‘limida tushuntirish va rozilikdan keyin yoqiladi. Ishlamay qolsa, avtomatik standart rejimga qaytadi.
- Clipboard: foydalanuvchi yoqqandan keyin matn tarixi xotirada saqlanadi; ilova yopilganda o‘chadi. 25 tagacha yozuvni qidirish, qayta nusxalash va bittalab o‘chirish mumkin. `⌃⌥⌘V` panelni qidiruv bilan ochadi, Enter birinchi natijani nusxalaydi. Yozuvni mahkamlash mumkin: mahkamlanganlar faqat foydalanuvchi o‘qiy oladigan faylda (`~/Library/Application Support/TopNest/pinned-clips.json`) saqlanadi. Parol menejerlari belgilagan maxfiy yozuvlar (`org.nspasteboard.ConcealedType`) tarixga tushmaydi, ammo barcha maxfiy matnlar avtomatik aniqlanmaydi.
- Tokcha: faylni notchga sudrab tashlasangiz, panel “Tokcha” bo‘limida ochiladi. Fayllar ko‘chirilmaydi, faqat yo‘li eslab qolinadi (30 tagacha). Ularni boshqa ilovaga sudrab olib o‘tish, ochish, Finder’da ko‘rsatish yoki AirDrop qilish mumkin.
- Zaryad: quvvat ulanganda notch yonida 3 soniya batareya foizi ko‘rinadi.
- Kalendar: EventKit orqali keyingi ikki kunning yaqinlashayotgan voqealari. Asosiy panelda navbatdagi uchta voqea ko‘rsatiladi; Zoom, Meet, Teams, Webex havolasi tadbir izohi yoki joyidan topilsa “Qo‘shilish” tugmasi chiqadi. Uchrashuvdan 5 daqiqa oldin notch yonida ogohlantirish paydo bo‘ladi. Sozlamalarda qaysi kalendarlar ko‘rinishini tanlash mumkin. Ruxsat faqat foydalanuvchi tugmani bosganda so‘raladi.
- Ob-havo: foydalanuvchi saqlagan shahar bo‘yicha Open-Meteo; joriy harorat va keyingi 3 soat prognozi. Shahar nomi xizmatga yuboriladi. Shahar koordinatalari ilova ishlayotgan paytda xotirada saqlanadi va har yangilanishda qayta qidirilmaydi. Uning bepul API’si faqat notijorat foydalanish uchun; tijorat nashridan oldin boshqa litsenziya yoki xizmat kerak.
- AI limitlari: har oyna uchun qolgan foiz, tiklanishgacha qolgan vaqt va rangli daraja (yashil → sariq → qizil). Limit 20% yoki kam qolganda bir marta bildirishnoma yuboriladi va notch yonida foiz ko‘rinadi.
- Codex: mahalliy Codex CLI App Server’ning `account/rateLimits/read` usuli orqali limitlar.
- Claude Code: Claude’ning rasmiy status line ma’lumotlari orqali 5 soat va 7 kun limitlari. Ulash ixtiyoriy. Mavjud status line bo‘lsa, u `~/Library/Application Support/TopNest/statusline-original.json` ga saqlanadi va zanjirda ishga tushiriladi: uning chiqishi o‘zgarishsiz ko‘rinadi, uzilganda asl sozlama qaytariladi. Ulanganidan keyin Claude Code ishlatilgach qiymatlar paydo bo‘ladi.
- Claude Code ruxsatlari (ixtiyoriy, standart o‘chiq): yoqilganda `~/.claude/settings.json` ga `PermissionRequest` hook qo‘shiladi. Claude ruxsat so‘raganda panel fokus olmasdan ochiladi va “Ruxsat berish” / “Rad etish” / “Terminalda” tanlanadi. TopNest yopiq bo‘lsa yoki 110 soniyada javob bo‘lmasa, Claude odatdagidek o‘z oynasida so‘raydi. Aloqa foydalanuvchiga tegishli Unix socket (`permission.sock`, 0600) orqali.

Ko‘rinish sozlamalari: yopiq holat shakli (Standart, Orolcha, Birlashgan), ochiq panel uslubi (Birlashgan — ekran tepasiga qo‘shilib ketadi, Yopishgan, Suzuvchi), panel o‘lchami (Ixcham, Standart, Katta — tab almashganda o‘zgarmaydi), tablar joyi (ostida/tepada) va ko‘rinishi (ikonka, matn yoki ikkalasi).

Global yorliqlar: `⌃⌥⌘N` — panelni ochish/yopish, `⌃⌥⌘V` — clipboard qidiruvi. Sozlamalarda panel qaysi ekranda ko‘rinishini tanlash va uni faqat notchli ekranda ko‘rsatish mumkin.

Musiqa, clipboard va Codex modullarini sozlamalarda o‘chirish mumkin. Asosiy paneldagi kartalarni alohida yashirish va animatsiyalarni o‘chirish (“Harakatni kamaytirish”) ham mumkin. O‘chirilgan modul fonda kuzatuv olib bormaydi.

## Manbadan yig‘ish

Xcode 26 va Swift 6 kerak. Loyihaning bosh papkasida:

```sh
zsh scripts/build-app.sh
```

Skript `dist/TopNest.app` yaratadi. Boshqa joyga yig‘ish uchun katalog yo‘lini argument sifatida bering: `zsh scripts/build-app.sh /path/to/output`. Chiqqan ilova lokal sinov uchun ad hoc imzolangan; ommaviy tarqatishdan oldin Developer ID bilan imzolash va notarizatsiya qilish kerak.

## GitHub’ga joylash

GitHub’da `TopNest` nomli **bo‘sh** repository yarating. Yaratishda README, `.gitignore` va license qo‘shmang; bu fayllardan ikkitasi manbada bor. So‘ng loyiha papkasida:

```sh
git init -b main
git add .gitignore Package.swift Info.plist README.md Sources scripts Resources/TopNest.icns
git diff --cached --stat
git commit -m "Initial TopNest prototype"
git remote add origin https://github.com/USERNAME/TopNest.git
git push -u origin main
```

`USERNAME` o‘rniga GitHub nomingizni yozing. Agar repository boshqacha nomlangan bo‘lsa, URL’ni o‘sha nomga moslang. `.gitignore` yig‘ilgan ilova va vaqtinchalik fayllarni chetlatadi. Ochiq repository uchun kodni boshqalar qanday ishlata olishini belgilaydigan license tanlash alohida qaror.

## Testlar

```sh
swift test
```

Joylashuv algoritmi, widget holati qoidalari, musiqa manbasi tanlovi (kengaytirilgan rejim fallback’i), saqlangan widgetlarning eski formatdan o‘qilishi, JSON yo‘l va statistika servisi test qilinadi. `TOPNEST_SNAPSHOT_DIR=/papka swift test --filter SnapshotTests` asosiy holatlarni (birinchi ishga tushirish, widget gridlari, musiqa o‘lchamlari, sozlamalar sxemasi) PNG’ga chizadi.

## Cheklovlar

Bu hali prototip. Spotify va Yandex Music (kengaytirilgan rejimda Telegram ham) ijrosi amalda sinaldi; Apple Music, tashqi monitor va to‘liq ekran rejimi hamon kam sinalgan. Kengaytirilgan musiqa rejimi Apple’ning rasmiy bo‘lmagan yo‘lidan foydalanadi va macOS yangilanishlarida ishlamay qolishi mumkin (unda avtomatik standart rejimga qaytadi). Gorizontal widget siljishi va sozlamalar oynasi rasm testlarida to‘liq chizilmaydi, ularni haqiqiy ilovada tekshirish kerak.
