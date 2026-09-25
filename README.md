# TopNest 0.2.2

macOS notch uchun native Swift prototipi. macOS 14 yoki yangi versiya kerak.

## Ishlatish

`TopNest.app` ni oching. Notch markazidagi kapsulani bosing. `Asosiy`, `Clipboard`, `Sozlamalar` bo‘limlari mavjud. Panelni `Esc` yoki uning tashqarisiga bosish bilan yoping. Kapsulaga kursor olib borganda ochish sozlamadan ixtiyoriy yoqiladi. Ilovadan chiqish tugmasi yuqori o‘ngda.

Boshlang‘ich kapsula 32 punkt balandlikda. Notchli ekranda kengligi notch bo‘shlig‘iga moslashadi (210–248 punkt); boshqa ekranda 220 punkt.

Avvalgi Nukta 0.2 sozlamalari TopNest birinchi ishga tushganda bir marta ko‘chiriladi. Paket identifikatori o‘zgargani uchun macOS Music/Spotify Automation va kalendar ruxsatlarini qayta so‘rashi mumkin. Claude Code status line oldingi Nukta yo‘liga ulangan bo‘lsa, TopNest sozlamasidagi ulash tugmasi uni yangi yo‘lga o‘tkazadi. Boshqa status line sozlamalariga tegilmaydi.

## Mavjud funksiyalar

- Spotify va Apple Music: trek nomi, ijro holati, davomiyligi, play/pause va trek almashtirish. Spotify albom rasmini taqdim etsa, u ham ko‘rsatiladi. Musiqa tekshiruvi interfeys oqimidan tashqarida bajariladi. Kuzatuv dastlab o‘chiq; yoqilganda macOS Automation ruxsati so‘ralishi mumkin. Boshqa playerlar hozircha qo‘llanmaydi.
- Clipboard: foydalanuvchi yoqqandan keyin matn tarixi xotirada saqlanadi; ilova yopilganda o‘chadi. 25 tagacha yozuvni qidirish, qayta nusxalash va bittalab o‘chirish mumkin. Parol menejerlari uchun ayrim istisnolar bor, ammo barcha maxfiy matnlar avtomatik aniqlanmaydi.
- Kalendar: EventKit orqali keyingi ikki kunning yaqinlashayotgan voqealari. Asosiy panelda navbatdagi uchta voqea va mavjud bo‘lsa ularning havolasi ko‘rsatiladi. Ruxsat faqat foydalanuvchi tugmani bosganda so‘raladi.
- Ob-havo: foydalanuvchi saqlagan shahar bo‘yicha Open-Meteo. Shahar nomi xizmatga yuboriladi. Shahar koordinatalari ilova ishlayotgan paytda xotirada saqlanadi va har yangilanishda qayta qidirilmaydi. Uning bepul API’si faqat notijorat foydalanish uchun; tijorat nashridan oldin boshqa litsenziya yoki xizmat kerak.
- Codex: mahalliy Codex CLI App Server’ning `account/rateLimits/read` usuli orqali limitlar.
- Claude Code: Claude’ning rasmiy status line ma’lumotlari orqali 5 soat va 7 kun limitlari. Ulash ixtiyoriy. Boshqa mavjud status line sozlamasi bo‘lsa, TopNest uni almashtirmaydi. Ulanganidan keyin Claude Code ishlatilgach qiymatlar paydo bo‘ladi.

Musiqa, clipboard va Codex modullarini sozlamalarda o‘chirish mumkin. O‘chirilgan modul fonda kuzatuv olib bormaydi.

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
