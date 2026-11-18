# VoiceLedger

Speak it, confirm it, track it. VoiceLedger is a voice-first expense tracker
for Android: tap the big mic, say something like **"spent 200 on lunch"** or
**"paid 500 for petrol"**, check what the app understood, and save. No account,
no cloud — every expense lives in a local SQLite database on your phone.

## Features

- **Voice capture** — big mic button with on-device speech-to-text
  (`speech_to_text`). Live transcript while you speak.
- **Honest on-device parsing** — the built-in parser extracts the amount
  (digits, including `Rs 200`, `200 rupees`, `₹200`, decimals and commas,
  plus Indian number words like "two hundred" as a bonus) and maps keywords
  to categories: food, travel, shopping, bills, entertainment, health,
  education, other. Unknown words map to `other` — the parser never invents
  an amount. If it can't find one, it says so and asks you to fill it in.
- **Confirm before saving** — every voice-parsed expense is shown for review
  (amount, category, note, date) before anything is saved.
- **Optional Gemini parsing** — paste your own Gemini API key in Settings and
  the app can send the spoken text to Gemini for smarter parsing. The key is
  stored only on your device and is never in the repo. Without a key the
  on-device parser is used and the UI says so honestly. A Gemini failure
  always falls back to the on-device parser with an honest message.
- **Manual add / edit / delete** — amount, category, note and date.
- **Monthly view** — total spent this month, per-category pie chart
  (`fl_chart`), expense list, and navigation to previous months.
- **Export CSV** — export the current month or all expenses and share the
  file (`share_plus`).
- **First-run onboarding** — speak → confirm → track. The app starts empty:
  no sample expenses, ever.

## How parsing works

1. Speech is recognised on-device by the platform speech recogniser.
2. The on-device parser (`lib/services/expense_parser.dart`) runs first:
   it looks for a number near a currency marker (`Rs`, `₹`, `rupees`), falls
   back to the largest number in the sentence, and falls back again to
   number words ("two hundred"). Category is matched by keyword, longest
   keyword first (so "textbook" beats "book").
3. If a Gemini key is set, the spoken text is sent to Gemini 2.0 Flash for
   a second opinion; the result is still shown for confirmation, and any
   failure falls back to step 2.
4. Nothing is saved until you tap **Save expense**.

## Tech

- Flutter 3.50 / Dart, Android only
- `speech_to_text` for voice input, `permission_handler` for the mic
- `sqflite` for local storage
- `fl_chart` for the category pie chart
- `http` for the optional Gemini call, `shared_preferences` for the key
- `csv` + `path_provider` + `share_plus` for CSV export

## Build & run

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # on a connected device / emulator
flutter build apk --release
```

Microphone permission is requested at runtime before listening; the
`RECORD_AUDIO` and `INTERNET` permissions are declared in
`android/app/src/main/AndroidManifest.xml`. Internet is only needed for the
optional Gemini call — voice capture and on-device parsing work offline.

## License

MIT — see `LICENSE`.
