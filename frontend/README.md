# Flutter client

Flutter-клиент будет добавлен следующим этапом. Планируемая структура уже заложена в репозитории:

- `lib/core/api`
- `lib/core/theme`
- `lib/features/auth`
- `lib/features/portfolio`
- `lib/features/assets`
- `lib/features/analytics`
- `lib/features/alerts`
- `lib/features/news`
- `lib/features/settings`
- `lib/shared/widgets`
- `lib/shared/models`

## v3: портфель и сделки

В этой версии экран портфеля визуально приближен к мобильному макету: карточка стоимости, таблица позиций, круглая кнопка добавления сделки и нижняя навигация.

Для Flutter Web используется API URL:

```dart
http://localhost:8080
```

Если запускаете Android Emulator, замените baseUrl в `lib/core/api/api_client.dart` на:

```dart
http://10.0.2.2:8080
```

Кнопка `+` открывает экран добавления сделки. После сохранения сделка отправляется в backend по endpoint:

```http
POST /portfolios/{id}/transactions
```

После успешного сохранения экран портфеля автоматически обновляет summary и позиции.
