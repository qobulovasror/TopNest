# TopNest 0.3.0

macOS notch uchun native Swift prototipi. macOS 14 yoki yangi versiya kerak.

## Ishlatish

`TopNest.app` ni oching. Notch markazidagi kapsulani bosing. Panelda `Asosiy` va `Clipboard` bo‘limlari bor. Yuqoridagi tishli g‘ildirak tugmasi barcha sozlamalarni alohida macOS oynasida ochadi. Sozlamalarni `⌘,` orqali ham ochish mumkin. Panelni `Esc` yoki uning tashqarisiga bosish bilan yoping. Kapsulaga kursor olib borganda ochish sozlamadan ixtiyoriy yoqiladi; hover bilan ochilgan panel kursor chiqqach o‘zi yopiladi. Menu bar ikonkasini chap bosish panelni ochadi, o‘ng bosish menyuni (sozlamalar, chiqish) ko‘rsatadi.

Notchli ekranda kapsula notchning o‘zini qoplaydi va ko‘rinmaydi; musiqa ijro etilganda notch yonida qanotlar (albom rasmi va waveform) paydo bo‘ladi. Boshqa ekranda o‘lchami 220 × 32 punkt. Fullscreen ilova ochilganda panel standart holatda yashiriladi. Sozlamalarda tizimga kirganda ishga tushirishni yoqish mumkin.

Avvalgi Nukta 0.2 sozlamalari TopNest birinchi ishga tushganda bir marta ko‘chiriladi. Paket identifikatori o‘zgargani uchun macOS Music/Spotify Automation va kalendar ruxsatlarini qayta so‘rashi mumkin. Claude Code status line oldingi Nukta yo‘liga ulangan bo‘lsa, TopNest sozlamasidagi ulash tugmasi uni yangi yo‘lga o‘tkazadi. Boshqa status line sozlamalariga tegilmaydi.

## Mavjud funksiyalar

- Spotify va Apple Music: trek nomi, ijro holati, davomiyligi, play/pause va trek almashtirish. Spotify albom rasmini taqdim etsa, u ham ko‘rsatiladi. Musiqa tekshiruvi interfeys oqimidan tashqarida bajariladi. Kuzatuv dastlab o‘chiq; yoqilganda macOS Automation ruxsati so‘ralishi mumkin. Boshqa playerlar hozircha qo‘llanmaydi.
- Clipboard: foydalanuvchi yoqqandan keyin matn tarixi xotirada saqlanadi; ilova yopilganda o‘chadi. 25 tagacha yozuvni qidirish, qayta nusxalash va bittalab o‘chirish mumkin. `⌃⌥⌘V` panelni qidiruv bilan ochadi, Enter birinchi natijani nusxalaydi. Yozuvni mahkamlash mumkin: mahkamlanganlar faqat foydalanuvchi o‘qiy oladigan faylda (`~/Library/Application Support/TopNest/pinned-clips.json`) saqlanadi. Parol menejerlari belgilagan maxfiy yozuvlar (`org.nspasteboard.ConcealedType`) tarixga tushmaydi, ammo barcha maxfiy matnlar avtomatik aniqlanmaydi.
- Tokcha: faylni notchga sudrab tashlasangiz, panel “Tokcha” bo‘limida ochiladi. Fayllar ko‘chirilmaydi, faqat yo‘li eslab qolinadi (30 tagacha). Ularni boshqa ilovaga sudrab olib o‘tish, ochish, Finder’da ko‘rsatish yoki AirDrop qilish mumkin.
- Zaryad: quvvat ulanganda notch yonida 3 soniya batareya foizi ko‘rinadi.
- Kalendar: EventKit orqali keyingi ikki kunning yaqinlashayotgan voqealari. Asosiy panelda navbatdagi uchta voqea ko‘rsatiladi; Zoom, Meet, Teams, Webex havolasi tadbir izohi yoki joyidan topilsa “Qo‘shilish” tugmasi chiqadi. Uchrashuvdan 5 daqiqa oldin notch yonida ogohlantirish paydo bo‘ladi. Sozlamalarda qaysi kalendarlar ko‘rinishini tanlash mumkin. Ruxsat faqat foydalanuvchi tugmani bosganda so‘raladi.
- Ob-havo: foydalanuvchi saqlagan shahar bo‘yicha Open-Meteo; joriy harorat va keyingi 3 soat prognozi. Shahar nomi xizmatga yuboriladi. Shahar koordinatalari ilova ishlayotgan paytda xotirada saqlanadi va har yangilanishda qayta qidirilmaydi. Uning bepul API’si faqat notijorat foydalanish uchun; tijorat nashridan oldin boshqa litsenziya yoki xizmat kerak.
- AI limitlari: har oyna uchun qolgan foiz, tiklanishgacha qolgan vaqt va rangli daraja (yashil → sariq → qizil). Limit 20% yoki kam qolganda bir marta bildirishnoma yuboriladi va notch yonida foiz ko‘rinadi.
- Codex: mahalliy Codex CLI App Server’ning `account/rateLimits/read` usuli orqali limitlar.
- Claude Code: Claude’ning rasmiy status line ma’lumotlari orqali 5 soat va 7 kun limitlari. Ulash ixtiyoriy. Boshqa mavjud status line sozlamasi bo‘lsa, TopNest uni almashtirmaydi. Ulanganidan keyin Claude Code ishlatilgach qiymatlar paydo bo‘ladi.

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

## Cheklovlar

Bu hali prototip. Spotify trek ma’lumotlari va Play/Pause sinovdan o‘tdi; Apple Music hamda tashqi monitorlar va to‘liq ekran rejimi amalda tekshirilmagan. Media ma’lumoti Spotify yoki Music ilovasidan Apple Events orqali olinadi. Boshqa playerlarni qo‘shish uchun alohida adapter kerak. Ilova macOS versiyalari va player yangilanishlarida yana tekshirilishi kerak.
