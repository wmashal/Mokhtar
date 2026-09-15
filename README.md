# Mokhtar (مختار)

> A building management app for shared expenses, meter readings, and community communication. The name comes from "Mokhtar" — the person chosen by the neighborhood to manage its affairs, which is exactly the role of the building manager in our culture.

---

## 1. The Idea in Short

In every building there is a person (usually a resident) who manages shared expenses: collects the monthly fee from neighbors, and spends it on elevator maintenance, common electricity, cleaning, repairs, and any emergency fixes. Today this is managed manually (notebook, Excel, or a WhatsApp group), which causes:

- **No transparency**: residents don't know where the money went.
- **Collection problems**: who paid? who is late? how much do they owe?
- **Lost history**: no archive of expenses and maintenance.
- **Meter disputes**: reading per-apartment water sub-meters and calculating each share is done manually, causing errors and conflicts.

**Mokhtar** turns all of this into one app: transparent finances, photo-documented meter readings, meetings with reminders, and instant notifications.

---

## 2. Roles in the App

| Role | Description |
|---|---|
| **Mokhtar (Manager)** | A resident of the building with admin permissions: records expenses, collects fees, reads meters, schedules meetings, sends notifications. |
| **Resident** | Can view: their balance/debt, account statement, meter invoices, building announcements, meetings, and receives notifications. |
| **Building Owner (optional, later)** | Supervisory role over multiple buildings, or appointing/removing the Mokhtar. |

> Design note: The Mokhtar is also a resident — so every "manager" account carries both roles, and sees their own data as a resident just like everyone else (transparency).

---

## 3. Core Features

### 3.1 Financial Management (the beating heart)
- **Building fund**: current balance, income (fees) and expenses, with full transaction history.
- **Monthly fee**: fixed amount per unit (or customized per unit), auto-generated monthly charges.
- **Debt tracking**: who paid, who is late, how much they owe, partial or full payments, payment history.
- **Expense recording**: elevator maintenance, stair electricity, cleaning, repairs — with category, amount, date, and receipt/invoice photo attachment.
- **Transparency**: every resident sees the building's full statement (income/expenses) — nothing hidden.
- **Monthly reports**: automatic summary: collected X, spent Y, balance Z, outstanding debts W.

### 3.2 Smart Water Meters ⭐ (the killer feature)
The scenario: one main meter for the building + a temporary sub-meter per apartment.

Monthly reading cycle:
1. The Mokhtar opens a "new reading round" → sees the list of units.
2. For each unit: **takes a photo of the meter** from within the app + enters the current number (manually at first).
3. The app automatically shows: previous reading, the difference (consumption), and the calculated cost.
4. After completing all units: **issue invoices** → each resident gets a notification with their invoice and their meter photo as proof.
5. The invoice is automatically added to the resident's debt.

- **Photo = proof**: stored with every reading, ends any "that's not my meter number" dispute.
- **Unit price**: configurable per building (fixed, or tiered pricing later).
- **Later**: OCR to read the number from the photo automatically (ML Kit), the Mokhtar just confirms.

### 3.3 Voice Input (Arabic Speech-to-Action) 🎙️
The Mokhtar should be able to **speak instead of type** — most operations happen while walking around the building or standing at the meter.

Examples of voice commands in Arabic:
- "سجّل على أبو أحمد ٥٠ ألف" → records a 50,000 payment/debt for that resident
- "ضيف مصروف مصعد ٢٠٠" → adds an elevator expense of 200
- "ذكّرني باجتماع بكرة الساعة ٨" → creates a meeting reminder

How it works:
1. Tap the mic button → speak in Arabic (any dialect).
2. **Speech-to-text** on-device (Android `SpeechRecognizer` API with Arabic locale, or ML Kit).
3. **Command parsing**: extract intent (payment / expense / reminder / reading), the person name, and the amount.
4. Show a **confirmation card** with the parsed data → Mokhtar confirms with one tap → saved.
5. Fuzzy name matching against the building's residents (handles dialects and nicknames).

- **Confirmation before saving is mandatory** — voice is never trusted blindly.
- Works offline for recognition (on-device), syncs when online.
- Later: full conversational assistant ("كم عليه أبو أحمد؟" → answers with his balance).

### 3.4 Meetings & Reminders
- The Mokhtar creates a meeting: title, date, time, location (or link), agenda.
- Instant notification to all residents + automatic reminder before the meeting.
- Attendance confirmation (attending / not attending) — later: voting, decisions, and minutes.

### 3.5 Notifications & Announcements
- Automatic notifications: new fee due, water invoice, payment reminder, meeting, new expense recorded.
- General announcements from the Mokhtar to all residents (e.g., "elevator maintenance tomorrow 10–12").

### 3.6 Login
- **OTP via phone number only** — no passwords, suitable for all ages.
- First entry: the Mokhtar creates the building and adds unit phone numbers → each resident logs in with their number and is automatically linked to their unit.

---

## 4. Tech Stack

**Context**: this deployment targets **a single building** — self-hosted on a Raspberry Pi, with Flutter for the app (Android first, iOS for free later).

| Layer | Choice | Why |
|---|---|---|
| App | **Flutter (Dart)** | One codebase → Android + iOS, excellent RTL support |
| Backend | **FastAPI (Python)** or **Ktor (Kotlin)** | Lightweight REST/WebSocket API, runs great on Pi |
| Database | **PostgreSQL** (SQLite acceptable for one building) | Reliable, relational — fits the data model |
| Server hardware | **Raspberry Pi 4/5 (64-bit OS) + SSD** | One building = tiny load; 64-bit OS required; SSD because SD cards die |
| Auth | **OTP via SMS gateway** (Twilio / local provider) | Phone-number-only login, self-hosted verification logic |
| Photos | **Local storage on Pi SSD** | Meter and receipt photos |
| Notifications | **Firebase Cloud Messaging** (free tier) | Push notifications — the only managed service |
| Voice STT | **On-device speech recognition** (Android/iOS native APIs via Flutter plugin) | Arabic speech-to-text, works offline |
| Voice parsing | **Rule-based parser first** → fallback to **small local LLM** (Qwen2.5-3B via Ollama on Pi) | Structured commands don't need an LLM; LLM handles the rest |
| OCR (later) | **ML Kit Text Recognition** (on-device) | Read meter numbers from photos |

### 4.1 Deployment Topology

```
Phones (Flutter app)
    │  REST/WebSocket — building Wi-Fi/LAN or internet via Cloudflare Tunnel
    ▼
Raspberry Pi 5 (8GB) + SSD
    ├── FastAPI/Ktor API server
    ├── PostgreSQL
    ├── Photo storage (SSD)
    ├── Ollama + Qwen2.5-3B (optional, voice command parsing)
    └── FCM client → push notifications
```

- **LAN-first**: if the Pi is on the building Wi-Fi, everything works locally; internet only needed for FCM push and remote access.
- **Remote access**: Cloudflare Tunnel or WireGuard — no port forwarding.
- **Backups**: nightly `pg_dump` + photo sync to an external drive or cloud.

### 4.2 Voice Pipeline (Pi-friendly)

```
Mic → on-device STT (Arabic) → text → Pi API
    → rule-based parser (fast path, ~90% of commands)
    → fallback: local LLM (Qwen2.5-3B, ~2-5s on Pi 5)
    → confirmation card → save
```

For a single building, a few voice commands per day — even a 3B model on a Pi is plenty.

---

## 5. Suggested Architecture

### 5.1 Flutter App

```
lib/
├── features/
│   ├── auth/          # OTP & login
│   ├── dashboard/     # Home (differs: manager / resident)
│   ├── finance/       # Fees, debts, expenses, fund
│   ├── meters/        # Reading rounds, camera, invoices
│   ├── voice/         # Mic UI, speech recognition, command confirmation
│   ├── meetings/      # Meetings & reminders
│   └── announcements/ # Announcements & notifications
├── core/
│   ├── data/          # API client, local cache (drift/SQLite)
│   ├── domain/        # Models + use cases
│   └── ui/            # Shared widgets, theme, RTL
├── l10n/              # ARB translation files (ar default)
└── main.dart
```

- **Riverpod** for state management, **go_router** for navigation, **drift** for offline cache.
- Arabic-first: `MaterialApp` with `locale: ar`, full RTL, all strings in ARB files.

### 5.2 Backend (on Pi)

```
server/
├── api/             # REST + WebSocket endpoints
├── services/        # business logic (billing, invoices, reminders)
├── voice/           # command parser (rules → LLM fallback)
├── db/              # PostgreSQL (SQLAlchemy/Exposed)
└── jobs/            # monthly charge generation, reminders (cron)
```

---

## 6. Data Model (initial, PostgreSQL)

```sql
buildings       → id, name, address, monthly_fee, water_unit_price
units           → id, building_id, unit_number, resident_name, phone, balance
users           → id, phone, unit_id, role (manager/resident)
transactions    → id, building_id, unit_id?, type (charge/payment/expense),
                  amount, category, note, receipt_photo_path, created_at
meter_rounds    → id, building_id, month, status (open/issued)
meter_readings  → id, round_id, unit_id, previous_value, current_value,
                  consumption, cost, photo_path
meetings        → id, building_id, title, starts_at, location, agenda
meeting_rsvps   → meeting_id, user_id, status (attending/not_attending)
announcements   → id, building_id, body, created_at
notifications   → id, user_id, type, payload, read_at
```

---

## 7. Internationalization (i18n) 🌐

- **Arabic is the default UI language from day one**, with **full RTL** layout.
- All user-facing strings live in ARB files (`l10n/`) — **no hardcoded strings in code**.
- The structure is ready for additional languages later (English, Kurdish, Turkish...) by simply adding a new translation file.
- Numbers, dates, and currency are formatted per device locale, with an in-app language switcher possible later.
- **Note**: all project documentation and code comments are written in English; only the app UI is Arabic-first.

---

## 8. Roadmap

### Phase 1 — MVP (the core)
- [ ] Phone OTP login
- [ ] Create building + add units and residents
- [ ] Monthly fee + payment/debt tracking
- [ ] Expense recording with receipt photos
- [ ] Transparent account statement for every resident

### Phase 2 — Meters
- [ ] Meter reading rounds + photo capture
- [ ] Consumption & cost calculation, invoice issuing
- [ ] Invoice notification to residents

### Phase 3 — Communication
- [ ] Meetings + reminders + attendance confirmation
- [ ] General announcements
- [ ] Monthly PDF reports

### Phase 4 — Intelligence & Expansion
- [ ] OCR for automatic meter reading from photos
- [ ] **Arabic voice commands** (rule-based parser → small LLM fallback on Pi)
- [ ] Conversational voice assistant (ask about balances, expenses)
- [ ] In-app electronic payments
- [ ] Voting & decisions in meetings
- [ ] iOS build (same Flutter codebase)
- [ ] Additional languages

---

## 9. Design Principles

1. **Transparency first**: every penny is visible to every resident — that's what sells the app.
2. **Mokhtar simplicity**: the Mokhtar is not an accountant; every operation should take at most three taps.
3. **Photo as evidence**: meter or invoice — take a photo and end the argument.
4. **Offline-first**: reading and recording work offline and sync later.
5. **Arabic-first UI**: RTL is not an afterthought — it's the foundation of the design.
