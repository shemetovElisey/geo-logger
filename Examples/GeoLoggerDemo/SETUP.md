# Настройка GeoLogger Demo App

## Создание Xcode проекта

1. Откройте Xcode
2. Выберите File → New → Project
3. Выберите "App" под iOS
4. Заполните:
   - Product Name: `GeoLoggerDemo`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Minimum Deployment: `iOS 14.0`
5. Сохраните проект в папку `Examples/GeoLoggerDemo/`

## Добавление GeoLogger SDK

1. В Xcode выберите File → Add Package Dependencies...
2. Выберите "Add Local..." или добавьте путь к локальному пакету:
   - Укажите путь: `../../` (относительно папки проекта)
   - Или используйте URL репозитория, если SDK опубликован

## Замена файлов

Замените автоматически созданные файлы на файлы из папки `GeoLoggerDemo/`:
- `App.swift` → замените содержимое
- `ContentView.swift` → замените содержимое
- Добавьте `LocationViewModel.swift`
- Обновите `Info.plist` с разрешениями на геолокацию

## Настройка Info.plist

Убедитесь, что в `Info.plist` добавлены ключи:
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`

## Альтернативный способ (SPM Package)

Если хотите использовать Swift Package Manager напрямую, создайте `Package.swift` в корне проекта:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeoLoggerDemo",
    platforms: [.iOS(.v14)],
    products: [
        .executable(
            name: "GeoLoggerDemo",
            targets: ["GeoLoggerDemo"]
        )
    ],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "GeoLoggerDemo",
            dependencies: ["GeoLogger"]
        )
    ]
)
```

Однако для iOS приложения рекомендуется использовать Xcode проект.

