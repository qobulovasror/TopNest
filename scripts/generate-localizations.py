#!/usr/bin/env python3
"""Generate the four app localization tables from Uzbek source labels.

Run this after changing a user-facing SwiftUI string. Untranslated entries are
reported so they can be reviewed before a release.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
sources = root / "Sources" / "TopNest"
pattern = re.compile(r'(?:Text|Button|Toggle|Picker|Section|Label|TextField|Menu|LabeledContent|accessibilityLabel|help)\(\s*"((?:\\.|[^"\\])*)"|L10n\.(?:tr|format)\("((?:\\.|[^"\\])*)"')
keys = set()
for source in sources.glob("*.swift"):
    for match in pattern.finditer(source.read_text()):
        key = match.group(1) or match.group(2)
        if key and not key.startswith('\\(') and not key.startswith('https:'):
            keys.add(key)

EN = {
    "AI savollari va ruxsat xabarlari": "AI questions and permission notices",
    "Asosiy": "Home", "Asosiy ekrandagi widgetlar": "Home widgets",
    "Avtomatik (notchli ekran)": "Automatic (notched display)",
    "Bekor qilish": "Cancel", "Bildirishnomalar": "Notifications", "Boshqa AI vositalari": "Other AI tools",
    "Clipboard": "Clipboard", "Clipboard qidiruvi": "Clipboard search", "Clipboard tarixi o‘chiq": "Clipboard history is off",
    "Clipboard tarixini saqlash": "Save clipboard history", "Codex limiti": "Codex limits", "Claude limiti": "Claude limits",
    "Dastur haqida": "About", "Ekran": "Display", "Fayldan import…": "Import from file…",
    "Finder’da ko‘rsatish": "Show in Finder", "Global yorliqlar": "Global shortcuts", "Grafik": "Graph",
    "Halqa": "Ring", "Harakatni kamaytirish": "Reduce motion", "Hozir davom etmoqda": "In progress",
    "Hozir yangilash": "Refresh now", "Hozircha ko‘rsatiladigan ma’lumot yo‘q": "Nothing to show yet",
    "Ijro holati": "Playback progress", "Ijrodagi musiqa": "Now playing", "Ishga tushish": "Startup",
    "Ishga tushmoqda…": "Starting…", "Ishlayapti": "Running", "Ixcham": "Compact",
    "Joylashuv": "Position", "Kalendar": "Calendar", "Kalendar topilmadi.": "No calendars found.",
    "Katta": "Large", "Katta raqam": "Large number", "Kengaytirilgan rejim": "Extended mode",
    "Kichik": "Small", "Klaviatura yorliqlari": "Keyboard shortcuts", "Ko‘rinish": "Appearance",
    "Ko‘rsatiladigan kalendarlar": "Calendars to show", "Ko‘rsatish": "Display",
    "Limitlarni yangilash": "Refresh limits", "Live activity": "Live activity", "Mahkamlangan": "Pinned",
    "Mahkamlanganlarni o‘chirish": "Clear pinned items", "Maksimum qiymat": "Maximum value",
    "Manba": "Source", "Masalan: Toshkent": "For example: Tashkent", "Matn": "Text",
    "Matn tarixi": "Text history", "Mavzu": "Theme", "Maxsus widget": "Custom widget",
    "Maxsus widget…": "Custom widget…", "Ma’lumot eskirgan": "Data is outdated",
    "Ma’lumot manbasi": "Data source", "Musiqa": "Music", "Musiqa kuzatuvi": "Music monitoring",
    "Musiqa kuzatuvi o‘chiq": "Music monitoring is off", "Nimani bilishingiz kerak": "What to know",
    "Nomi": "Name", "Notch paneli": "Notch panel", "Ob-havo": "Weather",
    "Ob-havo yuklanmoqda": "Loading weather", "Ob-havo yuklanmadi: %@": "Weather could not load: %@",
    "Ochiq panel uslubi": "Expanded panel style", "Ochish": "Open", "Olib tashlash": "Remove",
    "Orolcha": "Island", "Panel ko‘rinadigan ekran": "Display for the panel",
    "Panel o‘lchami": "Panel size", "Panelda hozir hech qaysi widget ko‘rinmaydi": "No widgets are currently visible in the panel",
    "Panelda ko‘rinadi": "Visible in panel", "Panelni ochish/yopish": "Open/close panel",
    "Pastga": "Move down", "Protsessor (CPU)": "Processor (CPU)", "Qaytarish": "Undo",
    "Qorong‘i": "Dark", "Raqam": "Number", "Ruxsat": "Permission", "Ruxsat berish": "Allow",
    "Saqlash": "Save", "Shahar": "City", "Shahar tanlanmagan": "No city selected",
    "Shell buyrug‘i": "Shell command", "Sinab ko‘rish": "Test", "Sinov": "Test",
    "Sozlash": "Set up", "Sozlash kerak: \\(reason)": "Needs setup: \\(reason)",
    "Sozlamalarda o‘chirilgan": "Disabled in settings", "Standart": "Standard",
    "Standartga qaytarish": "Reset to defaults", "Suzuvchi": "Floating", "Tablar": "Tabs",
    "Tanlangan ekran (ulanmagan)": "Selected display (disconnected)", "Tarmoq": "Network",
    "Tarixni tozalash": "Clear history", "Tarixni yoqish": "Enable history", "Til": "Language",
    "Til va mavzu": "Language and theme", "Tizim ko‘rinishi": "System appearance",
    "Tizim sozlamalari": "System Settings", "Tizim tili": "System language",
    "Tokcha": "Shelf", "Tokchadan olib tashlash": "Remove from shelf",
    "TopNest panelini ochish": "Open TopNest panel", "TopNest’dan chiqish": "Quit TopNest",
    "TopNest’ga xush kelibsiz": "Welcome to TopNest", "Tozalash": "Clear", "Tushunarli": "Got it",
    "Ulangan": "Connected", "Ulanishni uzish": "Disconnect", "Umumiy": "General",
    "URL (sayt yoki API)": "URL (website or API)", "Versiya": "Version",
    "Widget qo‘shish": "Add widget", "Widgetlar": "Widgets",
    "Xotira (RAM)": "Memory (RAM)", "Xush kelibsiz": "Welcome",
    "Yashirin: \\(reason)": "Hidden: \\(reason)", "Yopiq holat shakli": "Collapsed shape",
    "Yopish": "Close", "Yopishgan": "Attached", "Yorug‘": "Light",
    "Yorliq ko‘rinishi": "Tab label style", "Yozuvni o‘chirish": "Delete item",
    "Yuqoriga": "Move up", "O‘rta": "Medium", "Birlashgan": "Blended",
    "Faoliyat": "Activity", "Grafika (GPU)": "Graphics (GPU)",
    "Ikonka va matn": "Icon and text", "Faqat ikonka": "Icon only", "Faqat matn": "Text only",
    "Panel ostida": "Below panel", "Panel tepasida": "Above panel",
    "Kalendarga ruxsat kerak": "Calendar access required", "Kalendar ruxsati rad etilgan": "Calendar access denied",
    "Automation ruxsati yo‘q": "Automation permission missing", "Codex CLI topilmadi": "Codex CLI not found",
    "Limitlar yuklanmoqda": "Loading limits", "Claude Code ulanmagan": "Claude Code not connected",
    "Claude Code ishlatilgach limitlar paydo bo‘ladi": "Limits appear after using Claude Code",
    "Widget ta’rifi yo‘q": "Widget definition missing", "Yaqin 2 kunda uchrashuv yo‘q": "No meetings in the next two days",
    "Hali nusxalangan matn yo‘q": "No copied text yet",
}

RU = {
    "AI savollari va ruxsat xabarlari": "Вопросы ИИ и уведомления о доступе",
    "Asosiy": "Главная", "Asosiy ekrandagi widgetlar": "Виджеты главного экрана",
    "Avtomatik (notchli ekran)": "Автоматически (экран с вырезом)",
    "Bekor qilish": "Отмена", "Bildirishnomalar": "Уведомления", "Boshqa AI vositalari": "Другие инструменты ИИ",
    "Clipboard": "Буфер обмена", "Clipboard qidiruvi": "Поиск в буфере обмена",
    "Clipboard tarixi o‘chiq": "История буфера обмена выключена", "Clipboard tarixini saqlash": "Сохранять историю буфера обмена",
    "Codex limiti": "Лимиты Codex", "Claude limiti": "Лимиты Claude", "Dastur haqida": "О программе",
    "Ekran": "Экран", "Fayldan import…": "Импорт из файла…", "Finder’da ko‘rsatish": "Показать в Finder",
    "Global yorliqlar": "Глобальные сочетания", "Grafik": "График", "Halqa": "Кольцо",
    "Harakatni kamaytirish": "Уменьшить движение", "Hozir davom etmoqda": "Выполняется",
    "Hozir yangilash": "Обновить сейчас", "Hozircha ko‘rsatiladigan ma’lumot yo‘q": "Пока нечего показать",
    "Ijro holati": "Ход воспроизведения", "Ijrodagi musiqa": "Сейчас играет", "Ishga tushish": "Запуск",
    "Ishga tushmoqda…": "Запуск…", "Ishlayapti": "Работает", "Ixcham": "Компактный",
    "Joylashuv": "Расположение", "Kalendar": "Календарь", "Kalendar topilmadi.": "Календари не найдены.",
    "Katta": "Большой", "Katta raqam": "Крупное число", "Kengaytirilgan rejim": "Расширенный режим",
    "Kichik": "Маленький", "Klaviatura yorliqlari": "Сочетания клавиш", "Ko‘rinish": "Внешний вид",
    "Ko‘rsatiladigan kalendarlar": "Показываемые календари", "Ko‘rsatish": "Отображение",
    "Limitlarni yangilash": "Обновить лимиты", "Live activity": "Текущие события", "Mahkamlangan": "Закреплённые",
    "Mahkamlanganlarni o‘chirish": "Очистить закреплённые", "Maksimum qiymat": "Максимальное значение",
    "Manba": "Источник", "Masalan: Toshkent": "Например: Ташкент", "Matn": "Текст",
    "Matn tarixi": "История текста", "Mavzu": "Тема", "Maxsus widget": "Пользовательский виджет",
    "Maxsus widget…": "Пользовательский виджет…", "Ma’lumot eskirgan": "Данные устарели",
    "Ma’lumot manbasi": "Источник данных", "Musiqa": "Музыка", "Musiqa kuzatuvi": "Отслеживание музыки",
    "Musiqa kuzatuvi o‘chiq": "Отслеживание музыки выключено", "Nimani bilishingiz kerak": "Что следует знать",
    "Nomi": "Название", "Notch paneli": "Панель выреза", "Ob-havo": "Погода",
    "Ob-havo yuklanmoqda": "Загрузка погоды", "Ob-havo yuklanmadi: %@": "Не удалось загрузить погоду: %@",
    "Ochiq panel uslubi": "Стиль открытой панели", "Ochish": "Открыть", "Olib tashlash": "Удалить",
    "Orolcha": "Островок", "Panel ko‘rinadigan ekran": "Экран для панели",
    "Panel o‘lchami": "Размер панели", "Panelda hozir hech qaysi widget ko‘rinmaydi": "Сейчас на панели нет видимых виджетов",
    "Panelda ko‘rinadi": "Виден на панели", "Panelni ochish/yopish": "Открыть/закрыть панель",
    "Pastga": "Вниз", "Protsessor (CPU)": "Процессор (CPU)", "Qaytarish": "Отменить действие",
    "Qorong‘i": "Тёмная", "Raqam": "Число", "Ruxsat": "Разрешение", "Ruxsat berish": "Разрешить",
    "Saqlash": "Сохранить", "Shahar": "Город", "Shahar tanlanmagan": "Город не выбран",
    "Shell buyrug‘i": "Команда Shell", "Sinab ko‘rish": "Проверить", "Sinov": "Проверка",
    "Sozlash": "Настроить", "Sozlash kerak: \\(reason)": "Нужна настройка: \\(reason)",
    "Sozlamalarda o‘chirilgan": "Отключено в настройках", "Standart": "Стандартный",
    "Standartga qaytarish": "Сбросить по умолчанию", "Suzuvchi": "Плавающий", "Tablar": "Вкладки",
    "Tanlangan ekran (ulanmagan)": "Выбранный экран (отключён)", "Tarmoq": "Сеть",
    "Tarixni tozalash": "Очистить историю", "Tarixni yoqish": "Включить историю", "Til": "Язык",
    "Til va mavzu": "Язык и тема", "Tizim ko‘rinishi": "Системное оформление",
    "Tizim sozlamalari": "Системные настройки", "Tizim tili": "Системный язык",
    "Tokcha": "Полка", "Tokchadan olib tashlash": "Убрать с полки",
    "TopNest panelini ochish": "Открыть панель TopNest", "TopNest’dan chiqish": "Выйти из TopNest",
    "TopNest’ga xush kelibsiz": "Добро пожаловать в TopNest", "Tozalash": "Очистить", "Tushunarli": "Понятно",
    "Ulangan": "Подключено", "Ulanishni uzish": "Отключить", "Umumiy": "Основные",
    "URL (sayt yoki API)": "URL (сайт или API)", "Versiya": "Версия",
    "Widget qo‘shish": "Добавить виджет", "Widgetlar": "Виджеты",
    "Xotira (RAM)": "Память (RAM)", "Xush kelibsiz": "Добро пожаловать",
    "Yashirin: \\(reason)": "Скрыт: \\(reason)", "Yopiq holat shakli": "Форма закрытой панели",
    "Yopish": "Закрыть", "Yopishgan": "Прикреплённый", "Yorug‘": "Светлая",
    "Yorliq ko‘rinishi": "Вид подписей вкладок", "Yozuvni o‘chirish": "Удалить запись",
    "Yuqoriga": "Вверх", "O‘rta": "Средний", "Birlashgan": "Слитный",
    "Grafika (GPU)": "Графика (GPU)", "Ikonka va matn": "Значок и текст",
    "Faqat ikonka": "Только значок", "Faqat matn": "Только текст",
    "Panel ostida": "Под панелью", "Panel tepasida": "Над панелью",
    "Kalendarga ruxsat kerak": "Нужен доступ к календарю", "Kalendar ruxsati rad etilgan": "Доступ к календарю отклонён",
    "Automation ruxsati yo‘q": "Нет разрешения Automation", "Codex CLI topilmadi": "Codex CLI не найден",
    "Limitlar yuklanmoqda": "Загрузка лимитов", "Claude Code ulanmagan": "Claude Code не подключён",
    "Claude Code ishlatilgach limitlar paydo bo‘ladi": "Лимиты появятся после использования Claude Code",
    "Widget ta’rifi yo‘q": "Нет описания виджета", "Yaqin 2 kunda uchrashuv yo‘q": "Встреч в ближайшие два дня нет",
    "Hali nusxalangan matn yo‘q": "Пока нет скопированного текста",
}

EN.update({
    "Barcha playerlarni ko‘rsatish (kengaytirilgan rejim)": "Show all players (extended mode)",
    "Bu macOS versiyasida ishlamadi — standart rejim ishlatilmoqda": "Unavailable on this macOS version — using standard mode",
    "Buyruq sizning hisobingiz nomidan bajariladi. Faqat o‘zingiz ishonadigan buyruqlarni yozing.": "The command runs under your account. Enter only commands you trust.",
    "Claude Code status line orqali limitlar olinadi. Mavjud status line bo‘lsa, u saqlanadi: TopNest limitlarni o‘qiydi va uning chiqishini o‘zgarishsiz ko‘rsatadi. Uzilganda asl sozlama qaytariladi.": "Limits are read through the Claude Code status line. An existing status line is preserved: TopNest reads limits and displays its output unchanged. The original setting is restored when disconnected.",
    "Claude Code xabarlarini ko‘rsatish": "Show Claude Code notices",
    "Claude Code’ni ulash": "Connect Claude Code",
    "Codex hook’ini yoqqach, Codex’da /hooks orqali TopNest hook’ini ko‘rib, ishonchli deb belgilang.": "After enabling the Codex hook, open /hooks in Codex and mark the TopNest hook as trusted.",
    "Codex limitlarini ko‘rsatish": "Show Codex limits",
    "Codex ruxsat xabarlarini ko‘rsatish": "Show Codex permission notices",
    "Faqat notchli ekranda ko‘rsatish": "Show only on a notched display",
    "Fayllar ko‘chirilmaydi — tokcha ularga havolani eslab qoladi. Keyin ularni istalgan ilovaga sudrab olib o‘tish yoki AirDrop qilish mumkin.": "Files are not moved — the shelf remembers links to them. You can later drag them to any app or share them with AirDrop.",
    "Fayllarni shu yerga yoki notchga sudrab tashlang": "Drag files here or onto the notch",
    "Fullscreen ilovalar ustida yashirish": "Hide over full-screen apps",
    "Halqa (qiymat / maksimum)": "Ring (value / maximum)",
    "Har bir limit davrida bir marta xabar beriladi. Kam qolgan limit bu sozlamadan qat’i nazar notch yonida ko‘rinadi.": "A notice appears once per limit period. A low limit still appears next to the notch regardless of this setting.",
    "Hook orqali JSON yubora oladigan lokal AI dasturlari shu buyruqqa ulanishi mumkin. TopNest ularning nomidan javob bermaydi.": "Local AI apps that can send JSON through a hook can connect to this command. TopNest does not answer on their behalf.",
    "Hover bilan ochilgan panel kursor chiqqach yopiladi. Panelni bosib ham ochish mumkin; Esc yoki tashqariga bosish uni yopadi.": "A panel opened by hovering closes when the pointer leaves. You can also click the panel to open it; Esc or a click outside closes it.",
    "Integratsiyalar": "Integrations",
    "JSON yo‘li (ixtiyoriy, masalan data.items[0].price)": "JSON path (optional, e.g. data.items[0].price)",
    "Keyidan (masalan, °C)": "Suffix (e.g. °C)",
    "Kulrang ramka — panel ochilganda birdaniga ko‘rinadigan 4 ustun. Undan o‘ngdagi widgetlarga panelda gorizontal siljitib yoki ‹ › tugmalari bilan o‘tiladi. Uzuq chiziqli katak — sozlash kutayotgan widget.": "The gray frame marks the four columns visible when the panel opens. Scroll horizontally or use ‹ › to reach widgets to the right. A dashed tile needs setup.",
    "Kursorni kapsulaga olib borganda ochish": "Open when the pointer reaches the capsule",
    "Limit \\(AppState.lowLimitThreshold)% yoki kam qolganda xabar berish": "Notify when a limit reaches \\(AppState.lowLimitThreshold)% or less",
    "Mahkamlangan yozuvlar (\\(state.clipboard.pinned.count)) qayta ishga tushirishda saqlanishi uchun faqat sizning hisobingizda o‘qiladigan faylga yoziladi.": "Pinned items (\\(state.clipboard.pinned.count)) are stored in a file readable only by your account so they survive restarts.",
    "Matndan qidirish · Enter — birinchisini nusxalash": "Search text · Enter copies the first result",
    "Nusxalash: \\(item.text.prefix(80))": "Copy: \\(item.text.prefix(80))",
    "Oldidan (masalan, $)": "Prefix (e.g. $)",
    "O‘rnatilgan Codex CLI orqali limitlarni o‘qiydi. Hisob ma’lumotlari TopNest’da saqlanmaydi.": "Reads limits through the installed Codex CLI. Account credentials are not stored in TopNest.",
    "Panel animatsiyalarini o‘chiradi. macOS’dagi “Reduce motion” yoqilgan bo‘lsa, bu avtomatik qo‘llanadi.": "Turns off panel animations. This is applied automatically when Reduce Motion is enabled in macOS.",
    "SF Symbol ikonka nomi": "SF Symbol icon name",
    "Shahar nomi ob-havo ma’lumoti uchun Open-Meteo xizmatiga yuboriladi.": "The city name is sent to Open-Meteo for weather data.",
    "Standart rejim: Spotify va Apple Music treklari rasmiy AppleScript orqali ko‘rsatiladi va boshqariladi. Birinchi ulanishda macOS Automation ruxsatini so‘rashi mumkin.": "Standard mode: Spotify and Apple Music tracks are shown and controlled through AppleScript. macOS may request Automation permission on first use.",
    "Tanlangan ekran uzilsa (masalan, qopqoq yopilganda) avtomatik tanlovga qaytiladi. Notchsiz ekranda panel 220 × 32 kapsula ko‘rinishida bo‘ladi; “Faqat notchli ekran” yoqilsa, u yerda yashiriladi va faqat yorliq yoki menu bar orqali ochiladi.": "If the selected display disconnects (for example, when the lid closes), automatic selection resumes. On a display without a notch, the panel is a 220 × 32 capsule. If show only on a notched display is enabled, it stays hidden there and opens only with the shortcut or menu bar.",
    "Tarix faqat ilova xotirasida turadi va TopNest yopilganda o‘chadi. Parol menejerlari belgilagan maxfiy yozuvlar tarixga tushmaydi; barcha maxfiy matnlarni avtomatik aniqlash mumkin emas.": "History stays in app memory and is erased when TopNest closes. Secret entries marked by password managers are excluded; not all sensitive text can be detected automatically.",
    "Tartibni sudrab, ↑ ↓ tugmalari yoki qatorning kontekst menyusi orqali o‘zgartiring. Kichik — 1 katak, o‘rta — 2, katta — 4. Ma’lumoti yo‘q widget panelda yashiriladi; sababi qator ostida yozilgan.": "Reorder by dragging, using ↑ ↓, or the row context menu. Small uses 1 cell, medium 2, large 4. Widgets without data are hidden from the panel; the reason appears below each row.",
    "Tizim ko‘rinishi tanlansa, yorug‘ va qorong‘i rejim macOS bilan birga almashadi.": "With System Appearance, light and dark mode follow macOS.",
    "Tizimga kirganda TopNest’ni ochish": "Open TopNest at login",
    "Tokcha · \\(shelf.items.count)/\\(ShelfService.limit)": "Shelf · \\(shelf.items.count)/\\(ShelfService.limit)",
    "TopNest faqat macOS bildirishnomasini ko‘rsatadi. Savolga javob va ruxsat qarori Claude Code yoki Codex oynasida qabul qilinadi; TopNest ularning ishini to‘xtatmaydi.": "TopNest only shows a macOS notification. Answer questions and grant permissions in Claude Code or Codex; TopNest does not interrupt their work.",
    "Uchrashuvdan 5 daqiqa oldin notch yonida ogohlantirish chiqadi. Zoom, Google Meet, Teams, Webex havolalari tadbir izohi yoki joyidan topilib, “Qo‘shilish” tugmasi ko‘rsatiladi.": "A notice appears next to the notch five minutes before a meeting. Zoom, Google Meet, Teams and Webex links are found in the event notes or location, with a Join button.",
    "Widgetlar joylashuvi sxemasi: \\(entries.count) ta widget panelda ko‘rinadi": "Widget layout: \\(entries.count) widgets visible in the panel",
    "Widgetlar ma’lumot paydo bo‘lganda chiqadi. Qaysi widget nega yashirinligini sozlamalarda ko‘rish mumkin.": "Widgets appear when data becomes available. Settings shows why each hidden widget is unavailable.",
    "Xotirada \\(clipboard.items.count)/\\(ClipboardService.limit)": "In memory \\(clipboard.items.count)/\\(ClipboardService.limit)",
    "Yaqinlashayotgan uchrashuvlarni ko‘rsatish uchun kalendarga ruxsat kerak.": "Calendar access is required to show upcoming meetings.",
    "Yoqilgach, yangi nusxalangan matnlar faqat ilova xotirasida saqlanadi.": "When enabled, newly copied text is stored only in app memory.",
    "Yoqilsa nima o‘zgaradi": "What changes when enabled",
    "Zaryadga ulanganda notch yonida ko‘rsatish": "Show next to the notch when charging",
    "macOS notch uchun native dastur prototipi.": "A native app prototype for the macOS notch.",
    "“Birlashgan” uslubda panel ekran tepasiga botiq burchaklar bilan qo‘shilib ketadi; “Suzuvchi” uslubda ekran chetidan ajralib turadi. Birlashgan va yopishgan uslublar faqat notchli ekranda qo‘llanadi.": "Blended joins the panel to the top of the display with curved corners; Floating leaves a gap from the edge. Blended and Attached apply only on notched displays.",
    "“\\(removed.widget.title)” olib tashlandi": "“\\(removed.widget.title)” removed",
})

RU.update({
    "Barcha playerlarni ko‘rsatish (kengaytirilgan rejim)": "Показывать все проигрыватели (расширенный режим)",
    "Bu macOS versiyasida ishlamadi — standart rejim ishlatilmoqda": "Недоступно в этой версии macOS — используется стандартный режим",
    "Buyruq sizning hisobingiz nomidan bajariladi. Faqat o‘zingiz ishonadigan buyruqlarni yozing.": "Команда выполняется от имени вашей учётной записи. Вводите только те команды, которым доверяете.",
    "Claude Code status line orqali limitlar olinadi. Mavjud status line bo‘lsa, u saqlanadi: TopNest limitlarni o‘qiydi va uning chiqishini o‘zgarishsiz ko‘rsatadi. Uzilganda asl sozlama qaytariladi.": "Лимиты считываются через строку состояния Claude Code. Существующая строка сохраняется: TopNest считывает лимиты и показывает её вывод без изменений. При отключении прежняя настройка восстанавливается.",
    "Claude Code xabarlarini ko‘rsatish": "Показывать уведомления Claude Code",
    "Claude Code’ni ulash": "Подключить Claude Code",
    "Codex hook’ini yoqqach, Codex’da /hooks orqali TopNest hook’ini ko‘rib, ishonchli deb belgilang.": "После включения хука Codex откройте /hooks в Codex и отметьте хук TopNest как доверенный.",
    "Codex limitlarini ko‘rsatish": "Показывать лимиты Codex",
    "Codex ruxsat xabarlarini ko‘rsatish": "Показывать запросы доступа Codex",
    "Faqat notchli ekranda ko‘rsatish": "Показывать только на экране с вырезом",
    "Fayllar ko‘chirilmaydi — tokcha ularga havolani eslab qoladi. Keyin ularni istalgan ilovaga sudrab olib o‘tish yoki AirDrop qilish mumkin.": "Файлы не перемещаются — полка запоминает ссылки на них. Позже их можно перетащить в любое приложение или отправить через AirDrop.",
    "Fayllarni shu yerga yoki notchga sudrab tashlang": "Перетащите файлы сюда или на вырез",
    "Fullscreen ilovalar ustida yashirish": "Скрывать поверх полноэкранных приложений",
    "Halqa (qiymat / maksimum)": "Кольцо (значение / максимум)",
    "Har bir limit davrida bir marta xabar beriladi. Kam qolgan limit bu sozlamadan qat’i nazar notch yonida ko‘rinadi.": "Уведомление показывается один раз за период лимита. Низкий остаток всё равно отображается рядом с вырезом.",
    "Hook orqali JSON yubora oladigan lokal AI dasturlari shu buyruqqa ulanishi mumkin. TopNest ularning nomidan javob bermaydi.": "Локальные ИИ-приложения, отправляющие JSON через хук, могут подключиться к этой команде. TopNest не отвечает от их имени.",
    "Hover bilan ochilgan panel kursor chiqqach yopiladi. Panelni bosib ham ochish mumkin; Esc yoki tashqariga bosish uni yopadi.": "Панель, открытая наведением, закроется, когда курсор уйдёт. Её также можно открыть нажатием; Esc или щелчок снаружи закроет её.",
    "Integratsiyalar": "Интеграции",
    "JSON yo‘li (ixtiyoriy, masalan data.items[0].price)": "Путь JSON (необязательно, например data.items[0].price)",
    "Keyidan (masalan, °C)": "Суффикс (например, °C)",
    "Kulrang ramka — panel ochilganda birdaniga ko‘rinadigan 4 ustun. Undan o‘ngdagi widgetlarga panelda gorizontal siljitib yoki ‹ › tugmalari bilan o‘tiladi. Uzuq chiziqli katak — sozlash kutayotgan widget.": "Серая рамка показывает четыре столбца, видимые при открытии панели. До виджетов справа можно добраться горизонтальной прокруткой или кнопками ‹ ›. Плитке с пунктирной рамкой нужна настройка.",
    "Kursorni kapsulaga olib borganda ochish": "Открывать при наведении на капсулу",
    "Limit \\(AppState.lowLimitThreshold)% yoki kam qolganda xabar berish": "Уведомлять, когда остаётся \\(AppState.lowLimitThreshold)% лимита или меньше",
    "Mahkamlangan yozuvlar (\\(state.clipboard.pinned.count)) qayta ishga tushirishda saqlanishi uchun faqat sizning hisobingizda o‘qiladigan faylga yoziladi.": "Закреплённые записи (\\(state.clipboard.pinned.count)) сохраняются в файл, доступный только вашей учётной записи, чтобы пережить перезапуск.",
    "Matndan qidirish · Enter — birinchisini nusxalash": "Поиск по тексту · Enter копирует первый результат",
    "Nusxalash: \\(item.text.prefix(80))": "Копировать: \\(item.text.prefix(80))",
    "Oldidan (masalan, $)": "Префикс (например, $)",
    "O‘rnatilgan Codex CLI orqali limitlarni o‘qiydi. Hisob ma’lumotlari TopNest’da saqlanmaydi.": "Лимиты считываются через установленный Codex CLI. Учётные данные не сохраняются в TopNest.",
    "Panel animatsiyalarini o‘chiradi. macOS’dagi “Reduce motion” yoqilgan bo‘lsa, bu avtomatik qo‘llanadi.": "Отключает анимацию панели. Применяется автоматически, если в macOS включено уменьшение движения.",
    "SF Symbol ikonka nomi": "Имя значка SF Symbol",
    "Shahar nomi ob-havo ma’lumoti uchun Open-Meteo xizmatiga yuboriladi.": "Название города отправляется в Open-Meteo для получения прогноза погоды.",
    "Standart rejim: Spotify va Apple Music treklari rasmiy AppleScript orqali ko‘rsatiladi va boshqariladi. Birinchi ulanishda macOS Automation ruxsatini so‘rashi mumkin.": "Стандартный режим: треки Spotify и Apple Music показываются и управляются через AppleScript. При первом использовании macOS может запросить разрешение Automation.",
    "Tanlangan ekran uzilsa (masalan, qopqoq yopilganda) avtomatik tanlovga qaytiladi. Notchsiz ekranda panel 220 × 32 kapsula ko‘rinishida bo‘ladi; “Faqat notchli ekran” yoqilsa, u yerda yashiriladi va faqat yorliq yoki menu bar orqali ochiladi.": "Если выбранный экран отключится (например, при закрытии крышки), снова включится автоматический выбор. На экране без выреза панель имеет форму капсулы 220 × 32. Если выбран показ только на экране с вырезом, открыть её там можно лишь сочетанием клавиш или через строку меню.",
    "Tarix faqat ilova xotirasida turadi va TopNest yopilganda o‘chadi. Parol menejerlari belgilagan maxfiy yozuvlar tarixga tushmaydi; barcha maxfiy matnlarni avtomatik aniqlash mumkin emas.": "История хранится только в памяти приложения и удаляется при закрытии TopNest. Секретные записи, помеченные менеджерами паролей, исключаются; не весь конфиденциальный текст можно обнаружить автоматически.",
    "Tartibni sudrab, ↑ ↓ tugmalari yoki qatorning kontekst menyusi orqali o‘zgartiring. Kichik — 1 katak, o‘rta — 2, katta — 4. Ma’lumoti yo‘q widget panelda yashiriladi; sababi qator ostida yozilgan.": "Меняйте порядок перетаскиванием, кнопками ↑ ↓ или меню строки. Малый виджет занимает 1 ячейку, средний — 2, большой — 4. Виджет без данных скрыт с панели; причина указана под строкой.",
    "Tizim ko‘rinishi tanlansa, yorug‘ va qorong‘i rejim macOS bilan birga almashadi.": "При выборе системного оформления светлая и тёмная темы переключаются вместе с macOS.",
    "Tizimga kirganda TopNest’ni ochish": "Открывать TopNest при входе",
    "Tokcha · \\(shelf.items.count)/\\(ShelfService.limit)": "Полка · \\(shelf.items.count)/\\(ShelfService.limit)",
    "TopNest faqat macOS bildirishnomasini ko‘rsatadi. Savolga javob va ruxsat qarori Claude Code yoki Codex oynasida qabul qilinadi; TopNest ularning ishini to‘xtatmaydi.": "TopNest лишь показывает уведомление macOS. Отвечайте на вопросы и давайте разрешения в окне Claude Code или Codex; TopNest не прерывает их работу.",
    "Uchrashuvdan 5 daqiqa oldin notch yonida ogohlantirish chiqadi. Zoom, Google Meet, Teams, Webex havolalari tadbir izohi yoki joyidan topilib, “Qo‘shilish” tugmasi ko‘rsatiladi.": "За пять минут до встречи рядом с вырезом появляется уведомление. Ссылки Zoom, Google Meet, Teams и Webex находятся в заметках или месте события; показывается кнопка «Присоединиться».",
    "Widgetlar joylashuvi sxemasi: \\(entries.count) ta widget panelda ko‘rinadi": "Расположение виджетов: \\(entries.count) виджетов видно на панели",
    "Widgetlar ma’lumot paydo bo‘lganda chiqadi. Qaysi widget nega yashirinligini sozlamalarda ko‘rish mumkin.": "Виджеты появляются при наличии данных. Причина скрытия каждого виджета указана в настройках.",
    "Xotirada \\(clipboard.items.count)/\\(ClipboardService.limit)": "В памяти \\(clipboard.items.count)/\\(ClipboardService.limit)",
    "Yaqinlashayotgan uchrashuvlarni ko‘rsatish uchun kalendarga ruxsat kerak.": "Для показа предстоящих встреч нужен доступ к календарю.",
    "Yoqilgach, yangi nusxalangan matnlar faqat ilova xotirasida saqlanadi.": "После включения новый скопированный текст сохраняется только в памяти приложения.",
    "Yoqilsa nima o‘zgaradi": "Что изменится после включения",
    "Zaryadga ulanganda notch yonida ko‘rsatish": "Показывать рядом с вырезом при зарядке",
    "macOS notch uchun native dastur prototipi.": "Прототип нативного приложения для выреза macOS.",
    "“Birlashgan” uslubda panel ekran tepasiga botiq burchaklar bilan qo‘shilib ketadi; “Suzuvchi” uslubda ekran chetidan ajralib turadi. Birlashgan va yopishgan uslublar faqat notchli ekranda qo‘llanadi.": "Слитный стиль соединяет панель с верхним краем экрана изогнутыми углами; плавающий оставляет зазор. Слитный и прикреплённый стили доступны только на экранах с вырезом.",
    "“\\(removed.widget.title)” olib tashlandi": "«\\(removed.widget.title)» удалён",
})

EXTRA_KEYS = {
    "Widgetlarni sozlash", "Yondagi kartalarda “Sozlash” bilan kerakli imkoniyatni yoqing.",
    "Musiqa va clipboard faqat siz yoqsangiz kuzatiladi.",
    "Widgetlar tartibi va o‘lchami — Sozlamalar → Widgetlar.",
    "Oldingi widgetlar", "Keyingi widgetlar", "Pauza", "Ijro etish", "Oldingi trek", "Keyingi trek",
    "Kengaytirilgan rejim ishlamadi", "Spotify va Music standart rejimda ko‘rsatiladi.",
    "Ulanmoqda…", "Playerlar bilan aloqa o‘rnatilmoqda.", "Hech narsa ijro etilmayapti",
    "Istalgan playerda trek qo‘ying.", "Spotify yoki Music’da trek qo‘ying.",
    "Hammasi", "Qo‘shilish", "Havola", "Qo‘shimcha", "5 soat", "7 kun", "Tiklangan",
    "Ma’lumot yo‘q", "Panelni yopish", "Panelni ochish",
    "Claude sozlamasi shu orada o‘zgardi. Fayl o‘zgartirilmadi, qayta urinib ko‘ring.",
    "Claude sozlamasini o‘qib bo‘lmadi. Fayl o‘zgartirilmadi.",
    "Claude status line’i tanish formatda emas. Uni almashtirmadik.",
    "Ilova yo‘li topilmadi.", "Mavjud status line’ni saqlab bo‘lmadi. Fayl o‘zgartirilmadi.",
    "Codex PermissionRequest hook tuzilmasi tanilmadi; u o‘zgartirilmadi.",
    "Codex hooks.json JSON formatida emas; u o‘zgartirilmadi.",
    "Codex hooks.json faylini o‘qib bo‘lmadi; u o‘zgartirilmadi.",
    "Codex hooks.json shu orada o‘zgardi. Qayta urinib ko‘ring.",
    "Codex hooks.json tuzilmasi tanilmadi; u o‘zgartirilmadi.",
    "TopNest ilova yo‘li topilmadi.",
    "Ba’zi yorliqlarni ro‘yxatdan o‘tkazib bo‘lmadi; ular boshqa ilova tomonidan band bo‘lishi mumkin.",
    "Tizim sozlamalari → Login Items bo‘limida TopNest’ga ruxsat bering.",
    "Faqat https:// manzil qo‘llanadi", "Javob juda katta", "Vaqt tugadi",
    "Internet yo‘q", "Sayt topilmadi", "Tarmoq xatosi", "Buyruq bajarilmadi",
    "JSON emas", "Qiymat topilmadi", "Ba’zi fayllar qo‘shilmadi (format noto‘g‘ri yoki rad etildi).",
    "Codex’da /hooks orqali yangi TopNest hook’ini ko‘rib, ishonchli deb belgilang.",
}
keys.update(EXTRA_KEYS)
EN.update({
    "Widgetlarni sozlash": "Set up widgets", "Yondagi kartalarda “Sozlash” bilan kerakli imkoniyatni yoqing.": "Use Set up on the nearby cards to enable the features you need.",
    "Musiqa va clipboard faqat siz yoqsangiz kuzatiladi.": "Music and the clipboard are monitored only when you enable them.",
    "Widgetlar tartibi va o‘lchami — Sozlamalar → Widgetlar.": "Change widget order and size in Settings → Widgets.",
    "Oldingi widgetlar": "Previous widgets", "Keyingi widgetlar": "Next widgets", "Pauza": "Pause", "Ijro etish": "Play",
    "Oldingi trek": "Previous track", "Keyingi trek": "Next track",
    "Kengaytirilgan rejim ishlamadi": "Extended mode is unavailable", "Spotify va Music standart rejimda ko‘rsatiladi.": "Spotify and Music are shown in standard mode.",
    "Ulanmoqda…": "Connecting…", "Playerlar bilan aloqa o‘rnatilmoqda.": "Connecting to players.",
    "Hech narsa ijro etilmayapti": "Nothing is playing", "Istalgan playerda trek qo‘ying.": "Play a track in any player.",
    "Spotify yoki Music’da trek qo‘ying.": "Play a track in Spotify or Music.", "Hammasi": "All",
    "Qo‘shilish": "Join", "Havola": "Link", "Qo‘shimcha": "Secondary", "5 soat": "5 hours", "7 kun": "7 days",
    "Tiklangan": "Reset", "Ma’lumot yo‘q": "No data", "Panelni yopish": "Close panel", "Panelni ochish": "Open panel",
    "Widgetlar joyini almashtirish uchun sxemada bir kartani boshqasiga sudrang. Kulrang ramka panel ochilganda ko‘rinadigan 4 ustunni bildiradi; o‘ngdagi widgetlarga gorizontal siljitib o‘tiladi. Uzuq chiziqli katak sozlash kutmoqda.": "Drag one card onto another in the preview to swap widgets. The gray frame marks the four columns visible when the panel opens; scroll horizontally to reach widgets on the right. A dashed tile needs setup.",
    "“%@” olib tashlandi": "“%@” removed", "Yashirin: %@": "Hidden: %@", "Sozlash kerak: %@": "Needs setup: %@",
    "Widgetlar joylashuvi sxemasi: %d ta widget panelda ko‘rinadi": "Widget layout: %d widgets visible in the panel",
    "Limit %d%% yoki kam qolganda xabar berish": "Notify when a limit reaches %d%% or less",
    "Claude sozlamasi shu orada o‘zgardi. Fayl o‘zgartirilmadi, qayta urinib ko‘ring.": "Claude settings changed in the meantime. The file was not changed; try again.",
    "Claude sozlamasini o‘qib bo‘lmadi. Fayl o‘zgartirilmadi.": "Could not read Claude settings. The file was not changed.",
    "Claude status line’i tanish formatda emas. Uni almashtirmadik.": "Claude's status line has an unrecognized format. It was not replaced.",
    "Ilova yo‘li topilmadi.": "App path not found.",
    "Mavjud status line’ni saqlab bo‘lmadi. Fayl o‘zgartirilmadi.": "Could not save the existing status line. The file was not changed.",
    "Codex PermissionRequest hook tuzilmasi tanilmadi; u o‘zgartirilmadi.": "The Codex PermissionRequest hook has an unrecognized structure; it was not changed.",
    "Codex hooks.json JSON formatida emas; u o‘zgartirilmadi.": "Codex hooks.json is not valid JSON; it was not changed.",
    "Codex hooks.json faylini o‘qib bo‘lmadi; u o‘zgartirilmadi.": "Could not read Codex hooks.json; it was not changed.",
    "Codex hooks.json shu orada o‘zgardi. Qayta urinib ko‘ring.": "Codex hooks.json changed in the meantime. Try again.",
    "Codex hooks.json tuzilmasi tanilmadi; u o‘zgartirilmadi.": "Codex hooks.json has an unrecognized structure; it was not changed.",
    "TopNest ilova yo‘li topilmadi.": "TopNest app path not found.",
    "Ba’zi yorliqlarni ro‘yxatdan o‘tkazib bo‘lmadi; ular boshqa ilova tomonidan band bo‘lishi mumkin.": "Some shortcuts could not be registered; another app may be using them.",
    "Tizim sozlamalari → Login Items bo‘limida TopNest’ga ruxsat bering.": "Allow TopNest in System Settings → Login Items.",
    "%@: %d%% qoldi.": "%@: %d%% remaining.", " Tiklanish: %@.": " Resets: %@.",
    "%@ limiti kam qoldi": "%@ limit is running low", "%@ savol berdi": "%@ asked a question",
    "%@ reja bo‘yicha javob kutmoqda": "%@ is waiting for plan feedback",
    "%@ e’tibor kutmoqda": "%@ needs attention", "%@ ruxsat kutmoqda": "%@ is waiting for permission",
    "Codex hisobiga kirilmagan yoki limit ma’lumoti mavjud emas.": "Not signed in to Codex, or limit data is unavailable.",
    "Codex javob bermadi.": "Codex did not respond.", "Codex bilan ulanishda xato.": "Could not connect to Codex.",
    "Shahar topilmadi.": "City not found.", "Ob-havo xizmati javob bermadi.": "Weather service did not respond.",
    "Codex CLI topilmadi.": "Codex CLI not found.",
    "Oxirgi ma’lumot: %@": "Last data: %@", "Yangilangan: %@": "Updated: %@",
    "%@ keyin tiklanadi": "Resets in %@", "%d%% qoldi": "%d%% remaining",
    ", %@ keyin tiklanadi": ", resets in %@", "%d kun %d soat": "%d days %d hours",
    "%d soat %d daq": "%d hours %d minutes", "%d daq": "%d minutes",
    "Server xatosi (%d)": "Server error (%d)", "Faylni saqlab bo‘lmadi: %@": "Could not save file: %@",
    "Faqat https:// manzil qo‘llanadi": "Only https:// URLs are supported", "Javob juda katta": "Response is too large",
    "Vaqt tugadi": "Timed out", "Internet yo‘q": "No internet connection", "Sayt topilmadi": "Site not found",
    "Tarmoq xatosi": "Network error", "Buyruq bajarilmadi": "Command failed", "JSON emas": "Not JSON",
    "Qiymat topilmadi": "Value not found", "Ba’zi fayllar qo‘shilmadi (format noto‘g‘ri yoki rad etildi).": "Some files were not added (invalid format or declined).",
    "Claude sozlamasini saqlab bo‘lmadi: %@": "Could not save Claude settings: %@",
    "Codex hook’ini saqlab bo‘lmadi: %@": "Could not save the Codex hook: %@",
    "Codex’da /hooks orqali yangi TopNest hook’ini ko‘rib, ishonchli deb belgilang.": "Open /hooks in Codex and mark the new TopNest hook as trusted.",
})
RU.update({
    "Widgetlarni sozlash": "Настроить виджеты", "Yondagi kartalarda “Sozlash” bilan kerakli imkoniyatni yoqing.": "Включите нужные функции кнопкой «Настроить» на соседних карточках.",
    "Musiqa va clipboard faqat siz yoqsangiz kuzatiladi.": "Музыка и буфер обмена отслеживаются только после вашего включения.",
    "Widgetlar tartibi va o‘lchami — Sozlamalar → Widgetlar.": "Порядок и размер виджетов меняются в Настройки → Виджеты.",
    "Oldingi widgetlar": "Предыдущие виджеты", "Keyingi widgetlar": "Следующие виджеты", "Pauza": "Пауза", "Ijro etish": "Воспроизвести",
    "Oldingi trek": "Предыдущий трек", "Keyingi trek": "Следующий трек",
    "Kengaytirilgan rejim ishlamadi": "Расширенный режим недоступен", "Spotify va Music standart rejimda ko‘rsatiladi.": "Spotify и Music отображаются в стандартном режиме.",
    "Ulanmoqda…": "Подключение…", "Playerlar bilan aloqa o‘rnatilmoqda.": "Подключение к проигрывателям.",
    "Hech narsa ijro etilmayapti": "Ничего не воспроизводится", "Istalgan playerda trek qo‘ying.": "Запустите трек в любом проигрывателе.",
    "Spotify yoki Music’da trek qo‘ying.": "Запустите трек в Spotify или Music.", "Hammasi": "Все",
    "Qo‘shilish": "Присоединиться", "Havola": "Ссылка", "Qo‘shimcha": "Дополнительно", "5 soat": "5 часов", "7 kun": "7 дней",
    "Tiklangan": "Сброшено", "Ma’lumot yo‘q": "Нет данных", "Panelni yopish": "Закрыть панель", "Panelni ochish": "Открыть панель",
    "Widgetlar joyini almashtirish uchun sxemada bir kartani boshqasiga sudrang. Kulrang ramka panel ochilganda ko‘rinadigan 4 ustunni bildiradi; o‘ngdagi widgetlarga gorizontal siljitib o‘tiladi. Uzuq chiziqli katak sozlash kutmoqda.": "Перетащите карточку на другую в схеме, чтобы поменять виджеты местами. Серая рамка показывает четыре столбца, видимые при открытии панели; до виджетов справа можно добраться горизонтальной прокруткой. Плитке с пунктиром нужна настройка.",
    "“%@” olib tashlandi": "«%@» удалён", "Yashirin: %@": "Скрыт: %@", "Sozlash kerak: %@": "Нужна настройка: %@",
    "Widgetlar joylashuvi sxemasi: %d ta widget panelda ko‘rinadi": "Расположение виджетов: %d виджетов видно на панели",
    "Limit %d%% yoki kam qolganda xabar berish": "Уведомлять, когда остаётся %d%% лимита или меньше",
    "Claude sozlamasi shu orada o‘zgardi. Fayl o‘zgartirilmadi, qayta urinib ko‘ring.": "Настройки Claude тем временем изменились. Файл не изменён, повторите попытку.",
    "Claude sozlamasini o‘qib bo‘lmadi. Fayl o‘zgartirilmadi.": "Не удалось прочитать настройки Claude. Файл не изменён.",
    "Claude status line’i tanish formatda emas. Uni almashtirmadik.": "У строки состояния Claude неизвестный формат. Она не заменена.",
    "Ilova yo‘li topilmadi.": "Путь к приложению не найден.",
    "Mavjud status line’ni saqlab bo‘lmadi. Fayl o‘zgartirilmadi.": "Не удалось сохранить текущую строку состояния. Файл не изменён.",
    "Codex PermissionRequest hook tuzilmasi tanilmadi; u o‘zgartirilmadi.": "Неизвестная структура хука Codex PermissionRequest; изменения не внесены.",
    "Codex hooks.json JSON formatida emas; u o‘zgartirilmadi.": "Codex hooks.json не является корректным JSON; изменения не внесены.",
    "Codex hooks.json faylini o‘qib bo‘lmadi; u o‘zgartirilmadi.": "Не удалось прочитать Codex hooks.json; изменения не внесены.",
    "Codex hooks.json shu orada o‘zgardi. Qayta urinib ko‘ring.": "Codex hooks.json тем временем изменился. Повторите попытку.",
    "Codex hooks.json tuzilmasi tanilmadi; u o‘zgartirilmadi.": "Неизвестная структура Codex hooks.json; изменения не внесены.",
    "TopNest ilova yo‘li topilmadi.": "Путь к приложению TopNest не найден.",
    "Ba’zi yorliqlarni ro‘yxatdan o‘tkazib bo‘lmadi; ular boshqa ilova tomonidan band bo‘lishi mumkin.": "Не удалось зарегистрировать некоторые сочетания клавиш; возможно, их использует другое приложение.",
    "Tizim sozlamalari → Login Items bo‘limida TopNest’ga ruxsat bering.": "Разрешите TopNest в Системные настройки → Объекты входа.",
    "%@: %d%% qoldi.": "%@: осталось %d%%.", " Tiklanish: %@.": " Сброс: %@.",
    "%@ limiti kam qoldi": "Лимит %@ почти исчерпан", "%@ savol berdi": "%@ задал вопрос",
    "%@ reja bo‘yicha javob kutmoqda": "%@ ждёт ответа по плану",
    "%@ e’tibor kutmoqda": "%@ требует внимания", "%@ ruxsat kutmoqda": "%@ ждёт разрешения",
    "Codex hisobiga kirilmagan yoki limit ma’lumoti mavjud emas.": "Нет входа в Codex или данные о лимитах недоступны.",
    "Codex javob bermadi.": "Codex не отвечает.", "Codex bilan ulanishda xato.": "Не удалось подключиться к Codex.",
    "Shahar topilmadi.": "Город не найден.", "Ob-havo xizmati javob bermadi.": "Сервис погоды не отвечает.",
    "Codex CLI topilmadi.": "Codex CLI не найден.",
    "Oxirgi ma’lumot: %@": "Последние данные: %@", "Yangilangan: %@": "Обновлено: %@",
    "%@ keyin tiklanadi": "Сброс через %@", "%d%% qoldi": "Осталось %d%%",
    ", %@ keyin tiklanadi": ", сброс через %@", "%d kun %d soat": "%d дней %d часов",
    "%d soat %d daq": "%d часов %d минут", "%d daq": "%d минут",
    "Server xatosi (%d)": "Ошибка сервера (%d)", "Faylni saqlab bo‘lmadi: %@": "Не удалось сохранить файл: %@",
    "Faqat https:// manzil qo‘llanadi": "Поддерживаются только адреса https://", "Javob juda katta": "Ответ слишком большой",
    "Vaqt tugadi": "Время ожидания истекло", "Internet yo‘q": "Нет подключения к интернету", "Sayt topilmadi": "Сайт не найден",
    "Tarmoq xatosi": "Ошибка сети", "Buyruq bajarilmadi": "Команда не выполнена", "JSON emas": "Это не JSON",
    "Qiymat topilmadi": "Значение не найдено", "Ba’zi fayllar qo‘shilmadi (format noto‘g‘ri yoki rad etildi).": "Некоторые файлы не добавлены (неверный формат или отказ).",
    "Claude sozlamasini saqlab bo‘lmadi: %@": "Не удалось сохранить настройки Claude: %@",
    "Codex hook’ini saqlab bo‘lmadi: %@": "Не удалось сохранить хук Codex: %@",
    "Codex’da /hooks orqali yangi TopNest hook’ini ko‘rib, ishonchli deb belgilang.": "Откройте /hooks в Codex и отметьте новый хук TopNest как доверенный.",
})

EN.update({
    "Barcha qo‘shilgan va maxsus widgetlar o‘chiriladi. Maxsus widgetlarni avval faylga eksport qilib qo‘yishingiz mumkin.": "All added and custom widgets will be removed. You can export custom widgets to files first.",
    "Bu rejim Apple macOS 15.4 dan beri uchinchi tomon ilovalariga yopgan “Hozir ijroda” ma’lumotini tizimdagi /usr/bin/perl orqali oladi. Bu Apple’ning rasmiy yo‘li emas va macOS yangilanganda ishlamay qolishi mumkin (unda TopNest standart rejimga qaytadi). Ma’lumot kompyuteringizdan chiqmaydi. Rejimni istalgan vaqtda sozlamalarda o‘chirish mumkin.": "This mode reads Now Playing data, which Apple has blocked for third-party apps since macOS 15.4, through the system /usr/bin/perl. This is not an official Apple method and may stop working after a macOS update; TopNest will then return to standard mode. Data stays on your computer. You can turn the mode off in Settings at any time.",
    "Faylga eksport": "Export to file", "Joyini almashtirish uchun boshqa widget ustiga sudrang": "Drag onto another widget to swap positions",
    "Kengaytirilgan musiqa rejimini yoqasizmi?": "Enable extended music mode?", "Qo‘shish": "Add",
    "Quyidagi buyruq sizning hisobingiz nomidan har %d soniyada ishga tushadi. Faqat ishonchli manbadan olingan bo‘lsa qo‘shing.": "The following command will run under your account every %d seconds. Add it only if it comes from a trusted source.",
    "Roziman, yoqish": "I agree, enable", "Sozlamalar…": "Settings…", "Tahrirlash": "Edit",
    "TopNest sozlamalari": "TopNest Settings", "Widgetlarni standart holatga qaytarasizmi?": "Reset widgets to defaults?",
    "“%@” widgeti buyruq bajaradi": "The “%@” widget runs a command",
})
RU.update({
    "Barcha qo‘shilgan va maxsus widgetlar o‘chiriladi. Maxsus widgetlarni avval faylga eksport qilib qo‘yishingiz mumkin.": "Все добавленные и пользовательские виджеты будут удалены. Сначала их можно экспортировать в файлы.",
    "Bu rejim Apple macOS 15.4 dan beri uchinchi tomon ilovalariga yopgan “Hozir ijroda” ma’lumotini tizimdagi /usr/bin/perl orqali oladi. Bu Apple’ning rasmiy yo‘li emas va macOS yangilanganda ishlamay qolishi mumkin (unda TopNest standart rejimga qaytadi). Ma’lumot kompyuteringizdan chiqmaydi. Rejimni istalgan vaqtda sozlamalarda o‘chirish mumkin.": "Режим получает данные о текущем воспроизведении, закрытые Apple для сторонних приложений с macOS 15.4, через системный /usr/bin/perl. Это не официальный способ Apple; после обновления macOS он может перестать работать. Тогда TopNest вернётся в стандартный режим. Данные остаются на компьютере. Режим можно отключить в настройках в любой момент.",
    "Faylga eksport": "Экспорт в файл", "Joyini almashtirish uchun boshqa widget ustiga sudrang": "Перетащите на другой виджет, чтобы поменять их местами",
    "Kengaytirilgan musiqa rejimini yoqasizmi?": "Включить расширенный музыкальный режим?", "Qo‘shish": "Добавить",
    "Quyidagi buyruq sizning hisobingiz nomidan har %d soniyada ishga tushadi. Faqat ishonchli manbadan olingan bo‘lsa qo‘shing.": "Следующая команда будет выполняться от имени вашей учётной записи каждые %d секунд. Добавляйте её только из доверенного источника.",
    "Roziman, yoqish": "Согласен, включить", "Sozlamalar…": "Настройки…", "Tahrirlash": "Изменить",
    "TopNest sozlamalari": "Настройки TopNest", "Widgetlarni standart holatga qaytarasizmi?": "Сбросить виджеты по умолчанию?",
    "“%@” widgeti buyruq bajaradi": "Виджет «%@» выполняет команду",
})

EN.update({
    "• Brauzer (YouTube va boshqalar), Yandex Music, VLC va boshqa istalgan player treki ko‘rinadi.\\n• Albom rasmi, aniq progress va progressni bosib o‘tkazish ishlaydi.\\n• AppleScript va Automation ruxsati kerak bo‘lmaydi.":
        "• Shows tracks from browsers (YouTube and others), Yandex Music, VLC and other players.\\n• Album art, exact progress and seeking are available.\\n• AppleScript and Automation permission are not needed.",
    "• Apple macOS 15.4 dan boshlab “Hozir ijroda” ma’lumotini (MediaRemote) uchinchi tomon ilovalariga yopgan. Bu rejim cheklovni chetlab o‘tadi: TopNest’ning kichik yordamchisi tizimdagi /usr/bin/perl ichida ishga tushadi va ma’lumotni shu yo‘l bilan oladi.\\n• Bu Apple’ning rasmiy yo‘li emas: macOS yangilanganda ishlamay qolishi mumkin. Unda TopNest avtomatik ravishda standart rejimga qaytadi.\\n• Ma’lumot faqat kompyuteringizda qoladi, hech qayerga yuborilmaydi. Rejimni istalgan vaqtda shu yerda o‘chirishingiz mumkin.":
        "• Since macOS 15.4, Apple has blocked third-party apps from Now Playing data (MediaRemote). This mode works around that restriction by running a small TopNest helper inside the system /usr/bin/perl process.\\n• This is not an official Apple method and may stop working after a macOS update. TopNest then returns to standard mode automatically.\\n• Data stays on your computer and is not sent anywhere. You can turn this mode off here at any time.",
})
RU.update({
    "• Brauzer (YouTube va boshqalar), Yandex Music, VLC va boshqa istalgan player treki ko‘rinadi.\\n• Albom rasmi, aniq progress va progressni bosib o‘tkazish ishlaydi.\\n• AppleScript va Automation ruxsati kerak bo‘lmaydi.":
        "• Показываются треки из браузеров (YouTube и других), Yandex Music, VLC и других проигрывателей.\\n• Доступны обложка, точное положение и перемотка.\\n• Разрешения AppleScript и Automation не нужны.",
    "• Apple macOS 15.4 dan boshlab “Hozir ijroda” ma’lumotini (MediaRemote) uchinchi tomon ilovalariga yopgan. Bu rejim cheklovni chetlab o‘tadi: TopNest’ning kichik yordamchisi tizimdagi /usr/bin/perl ichida ishga tushadi va ma’lumotni shu yo‘l bilan oladi.\\n• Bu Apple’ning rasmiy yo‘li emas: macOS yangilanganda ishlamay qolishi mumkin. Unda TopNest avtomatik ravishda standart rejimga qaytadi.\\n• Ma’lumot faqat kompyuteringizda qoladi, hech qayerga yuborilmaydi. Rejimni istalgan vaqtda shu yerda o‘chirishingiz mumkin.":
        "• Начиная с macOS 15.4 Apple закрыла сторонним приложениям доступ к данным о текущем воспроизведении (MediaRemote). В этом режиме небольшой помощник TopNest запускается внутри системного /usr/bin/perl.\\n• Это не официальный способ Apple; после обновления macOS он может перестать работать. Тогда TopNest автоматически вернётся в стандартный режим.\\n• Данные остаются на вашем компьютере и никуда не отправляются. Режим можно отключить здесь в любой момент.",
})

EN.update({
    "Barcha ekranlarda ko‘rsatish": "Show on all displays",
    "Barcha ekranlar yoqilsa, har bir mos ekranda kapsula chiqadi. Bosilgan ekranda panel ochiladi. “Faqat notchli ekranda” tanlovi ham amal qiladi.": "When enabled, a capsule appears on every eligible display. The panel opens on the display you click. The notched display restriction still applies.",
})
RU.update({
    "Barcha ekranlarda ko‘rsatish": "Показывать на всех экранах",
    "Barcha ekranlar yoqilsa, har bir mos ekranda kapsula chiqadi. Bosilgan ekranda panel ochiladi. “Faqat notchli ekranda” tanlovi ham amal qiladi.": "Если включено, капсула появится на каждом подходящем экране. Панель откроется на том экране, где вы нажали. Ограничение для экранов с вырезом продолжает действовать.",
})

def swift_unescape(value: str) -> str:
    return value.replace("\\n", "\n").replace('\\"', '"')

keys = {swift_unescape(key) for key in keys}
keys.discard('"\\(executable)" \\(ClaudePermissionBridge.genericFlag) "AI nomi"')
keys.discard('v\\(SettingsWindowView.appVersion)')
EN = {swift_unescape(key): swift_unescape(value) for key, value in EN.items()}
RU = {swift_unescape(key): swift_unescape(value) for key, value in RU.items()}


def uz_cyrillic(text: str) -> str:
    # Uzbek Latin spelling, including typographic apostrophes used in UI copy.
    pairs = [
        ("O‘", "Ў"), ("O'", "Ў"), ("o‘", "ў"), ("o'", "ў"),
        ("G‘", "Ғ"), ("G'", "Ғ"), ("g‘", "ғ"), ("g'", "ғ"),
        ("Sh", "Ш"), ("sh", "ш"), ("Ch", "Ч"), ("ch", "ч"),
        ("Yo", "Ё"), ("yo", "ё"), ("Yu", "Ю"), ("yu", "ю"),
        ("Ya", "Я"), ("ya", "я"), ("Ye", "Е"), ("ye", "е"),
        ("Ng", "Нг"), ("ng", "нг"),
    ]
    letters = {
        "A": "А", "B": "Б", "C": "С", "D": "Д", "E": "Е", "F": "Ф", "G": "Г",
        "H": "Ҳ", "I": "И", "J": "Ж", "K": "К", "L": "Л", "M": "М", "N": "Н",
        "O": "О", "P": "П", "Q": "Қ", "R": "Р", "S": "С", "T": "Т", "U": "У",
        "V": "В", "W": "В", "X": "Х", "Y": "Й", "Z": "З",
    }
    letters.update({key.lower(): value.lower() for key, value in list(letters.items())})
    protected = re.compile(r'\\\([^)]*\)|%[0-9.]*[@diuf]|TopNest|Codex|Claude(?: Code)?|macOS|AppleScript|MediaRemote|Spotify|Finder|AirDrop|Open-Meteo|JSON|API|CPU|RAM|GPU|URL|SF Symbol|Zoom|Google Meet|Teams|Webex|Yandex Music|VLC|Shell|Enter|Esc|Fullscreen|Automation|AI|CLI')
    parts = protected.split(text)
    matches = protected.findall(text)
    def convert(part: str) -> str:
        part = part.replace("Clipboard", "Буфер алмашинуви").replace("clipboard", "буфер алмашинуви")
        part = re.sub(r'(?<![A-Za-z])E', 'Э', part)
        part = re.sub(r'(?<![A-Za-z])e', 'э', part)
        for latin, cyrillic in pairs:
            part = part.replace(latin, cyrillic)
        result = "".join(letters.get(char, char) for char in part)
        result = result.replace("Видгет", "Виджет").replace("видгет", "виджет").replace("плаер", "плеер")
        return re.sub(r'(?<=[А-Яа-яЁёЎўҒғҚқҲҳ])’(?=[А-Яа-яЁёЎўҒғҚқҲҳ])', 'ъ', result)
    output = convert(parts[0])
    for match, part in zip(matches, parts[1:]):
        output += match + convert(part)
    return output


def escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


for locale, translations in [("uz", {}), ("uz-Cyrl", {}), ("en", EN), ("ru", RU)]:
    folder = root / "Resources" / f"{locale}.lproj"
    folder.mkdir(parents=True, exist_ok=True)
    def localized(key: str) -> str:
        if locale == "uz-Cyrl":
            return uz_cyrillic(key)
        return translations.get(key, key)
    (folder / "Localizable.strings").write_text(
        "/* Generated from SwiftUI source labels. */\n" +
        "".join(f'"{escape(key)}" = "{escape(localized(key))}";\n' for key in sorted(keys))
    )
    privacy = {
        "uz": (
            "Yaqinlashayotgan uchrashuvlarni notch panelida ko‘rsatish uchun kalendarni o‘qish kerak.",
            "Ijrodagi musiqani ko‘rsatish va boshqarish uchun Music yoki Spotify bilan aloqa kerak.",
        ),
        "uz-Cyrl": (
            "Яқинлашаётган учрашувларни нотч панелида кўрсатиш учун календарни ўқиш керак.",
            "Ижродаги мусиқани кўрсатиш ва бошқариш учун Music ёки Spotify билан алоқа керак.",
        ),
        "en": (
            "Calendar access is needed to show upcoming meetings in the notch panel.",
            "Access to Music or Spotify is needed to show and control the music now playing.",
        ),
        "ru": (
            "Доступ к календарю нужен для показа предстоящих встреч на панели выреза.",
            "Доступ к Music или Spotify нужен для показа и управления воспроизведением музыки.",
        ),
    }[locale]
    (folder / "InfoPlist.strings").write_text(
        f'"NSCalendarsFullAccessUsageDescription" = "{escape(privacy[0])}";\n'
        f'"NSAppleEventsUsageDescription" = "{escape(privacy[1])}";\n'
    )

for locale, translations in [("en", EN), ("ru", RU)]:
    missing = sorted(key for key in keys if key not in translations and any(c.isalpha() for c in key)
                     and key not in {"TopNest", "Codex", "Claude Code", "AirDrop", "Live activity"})
    print(f"{locale}: {len(keys) - len(missing)}/{len(keys)} translated; {len(missing)} need review")
    for key in missing:
        print(f"  {key}")
