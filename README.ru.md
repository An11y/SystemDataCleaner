# System Data Cleaner

[English](README.md) · **Русский**

Освободите загадочный блок **«Системные данные»** на Mac.

Когда в «Об этом Mac → Хранилище» висят десятки гигабайт «Системных данных», это обычно кэши, остатки Xcode, браузерный мусор, Docker и скрытые папки Library — а не сама ОС. **System Data Cleaner** находит этот хлам, показывает размеры и удаляет только то, что вы отметили.

Интерфейс приложения следует **языку системы macOS** (английский / русский).

![Главное окно](docs/screenshots/main.png)

## Скачать для Mac

[![Download](https://img.shields.io/github/v/release/An11y/SystemDataCleaner?label=Download&logo=apple)](https://github.com/An11y/SystemDataCleaner/releases/latest)

1. Откройте последний **[Release](https://github.com/An11y/SystemDataCleaner/releases/latest)**
2. Скачайте **`System-Data-Cleaner-*-macOS.dmg`** (или `.zip`)
3. Откройте DMG и перетащите **System Data Cleaner** в **Applications**  
   (из ZIP: распакуйте и перетащите `.app` так же)
4. Первый запуск: **ПКМ → Открыть** (Gatekeeper; ad‑hoc подпись)
5. При необходимости выдайте **Full Disk Access** (ниже)

Universal binary: Apple Silicon + Intel · macOS 14+

## Знакомая проблема — понятное решение

Вы уже это видели:

- Диск почти полный, а что съело место — непонятно  
- «Системные данные» растут после Xcode, Docker, браузеров или AI-инструментов  
- Не хочется чёрный ящик, который всё сносит без спроса  

System Data Cleaner для этого момента: скан → просмотр → подтверждение → свободное место.

Обычно находит:

- кэши приложений и браузеров  
- Xcode DerivedData / DeviceSupport / симуляторы  
- Docker, npm, pip, Gradle и другие dev-кэши  
- Group Containers, sandbox-кэши, старые crash-отчёты  
- артефакты проектов (`node_modules`, `.next`, `target`, …)

Ничего не удаляется, пока вы не отметите и не подтвердите.

## Возможности

| Возможность | Что даёт |
|---|---|
| **110+ категорий** | Система · Разработка · Приложения · Скрытое |
| **Умная очистка** | Безопасные + крупные «осторожные», без опасных (⌘⇧2) |
| **Живой скан** | Результаты по мере поиска · 8 потоков · кэш размеров |
| **Подпапки** | Галочки на отдельных папках/файлах |
| **Риски** | Безопасно / осторожно / риск · confirm по группам |
| **Тема системы** | Светлая и тёмная как в macOS |
| **Full Disk Access** | Понятная подсказка, когда нужен доступ |

Опасные категории (Корзина, бэкапы, Archives, Document Revisions и т.п.) **выключены по умолчанию**. Всегда проверяйте пункты с меткой **риск**.

## Full Disk Access

**Системные настройки → Конфиденциальность и безопасность → Полный доступ к диску** → добавить *System Data Cleaner*.

Без этого Mail, Messages и многие Containers могут выглядеть пустыми.

## Как пользоваться

1. **Сканировать** (⌘R) — найти мусор  
2. **Умная** (⌘⇧2) — безопасный выбор или вручную  
3. **Удалить** (⌘⌫) — подтвердить в диалоге  

Также: ⌘F поиск · ⌘⇧1 только безопасные · ⌘⇧0 снять всё · Esc свернуть детали.

## Скриншоты

| Главное окно | Подтверждение |
|---|---|
| ![main](docs/screenshots/main.png) | ![confirm](docs/screenshots/confirm.png) |

## Сборка из исходников

```bash
git clone https://github.com/An11y/SystemDataCleaner.git
cd SystemDataCleaner
./build_app.sh
```

Ставит в **`/Applications/System Data Cleaner.app`**.

```bash
open -a "System Data Cleaner"

./build_app.sh --no-install   # только локальный .app
./build_app.sh --package      # ZIP + DMG в dist/
```

## Требования

- macOS 14+ (Apple Silicon и Intel)
- Для сборки: Swift 5.9+ (Command Line Tools / Xcode)

## Лицензия

[MIT](LICENSE)

«Как есть». Удаление необратимо — проверяйте категории с меткой **риск**.
