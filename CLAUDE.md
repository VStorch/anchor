# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`anchor` — a Brazilian personal-finance app (Flutter 3.32.3 / Dart 3.8.1, Android-only). The user tracks
expenses, the money sources they are paid from, and what is left in each source per month. **UI copy,
enum labels and test names are in pt-BR; code identifiers are in English.** Money is BRL, dates use the
`pt_BR` locale (`initializeDateFormatting('pt_BR')` runs in `main`).

## Commands

```bash
flutter pub get
flutter run
flutter analyze                       # must stay at "No issues found"
dart format lib test
flutter test
flutter test test/app/expense_flow_test.dart
flutter test --plain-name 'nome do teste'
flutter build apk
```

### Android build requires JDK 21

Gradle 8.12 cannot parse the Java 25 runtime that `flutter doctor` picks up from Android Studio, and the
build fails with a bare `* What went wrong: 25.0.2`. Fix it once, at user level (not in the repo):

```bash
flutter config --jdk-dir=/usr/lib/jvm/java-21-openjdk-amd64
```

Never commit `org.gradle.java.home` into `android/gradle.properties` — it is machine-specific.

## Architecture

MVVM, feature-first. Each feature owns `models/`, `repositories/`, `viewmodels/`, `views/` (+ `views/widgets/`).
Wiring is `provider`; persistence is `sqflite`.

### The two cross-cutting pieces

The dashboard stacks three blocks that never share a figure. **Você tem hoje** (`TodayCard`) is
`BudgetSnapshot.walletsBalance`, the money that exists, whatever month is on screen; when the current
month has receipts still `predicted` it adds a "Confirmar R$ X" button (`awaitingConfirmation`) that
leads to Carteiras. **Previsão até o fim de <mês>** (`ForecastCard`) renders `BudgetSnapshot.forecast`,
a `MonthForecast` built in `features/budget` only for the current month or a later one: per wallet,
today's balance plus what is still expected in (`predicted` receipts, overdue or not, and active
payouts with no receipt yet) minus the `remaining` of the occurrences planned on it, over every month
from the current one to the one on screen; bills with no wallet go to `unassignedToPay`. It is
outlined and coloured `MoneyColors.predicted`, and holds no real number. **<Mês> até agora** (current
month) or **<Mês>** (past; hidden for a future month) is `MonthSoFarCard`: `Entrou`/`Saiu`/`Diferença`,
confirmed money only, so `totalReceived - totalSpent == difference` reconciles on screen.
`MonthSummary` carries no planned income; the payout calendar's total lives on `Wallet.monthlyIncome`
and is shown only on the Carteiras tab, labelled "por mês". **Never put a planned figure next to a
real one in the same block.**

"Today" is injectable: `MonthSummary.build(today:)` keeps it in `summary.today`, and
`BudgetService.loadSnapshot(month, now:)` passes the same instant to `registerDuePayouts(now:)`, the
summaries and the forecast, so a service test pins the date instead of reading the clock.

- **`features/budget/`** is not a screen. It is the aggregation layer every other feature reads:
  `BudgetService.loadSnapshot(month)` reads all four repositories and returns a `BudgetSnapshot`
  (`MonthSummary` + `WalletSummary` per wallet + raw lists). Dashboard, Expenses and Wallets all render
  from a snapshot, so **totals are computed in one place** — add derived numbers to `MonthSummary`/
  `WalletSummary`, never in a view.
- **`core/state/`** holds the two notifiers shared by all view models: `DataChanges` (repositories call
  `publish()` after every write) and `MonthSelection` (the month the whole app is showing).
  `ReactiveViewModel` subscribes to `DataChanges` and re-runs `loadData()`, which is why a write in one
  tab refreshes the others with no manual plumbing.

**Never save a parent row with `ConflictAlgorithm.replace`.** SQLite implements it as delete + insert,
so the `ON DELETE CASCADE` fires and editing a wallet wipes its payouts and receipts (an expense, its
payments). The repositories update by `id` when there is one and insert otherwise.

`loadSnapshot` also calls `registerDuePayouts` — this is what "the app credits your salary on payday"
means in practice. Several view models load concurrently, so that insert uses
`ConflictAlgorithm.ignore` against the `(payout_id, month_key)` unique index; keep it idempotent.

### Domain model

An **expense** is a rule, not a row per month. `Expense.occurrenceIn(Month)` projects it into an
`ExpenseOccurrence` (or null):

| `ExpenseType` | pt-BR label | rule |
|---|---|---|
| `recurring` | Recorrente | every month from `startMonth` until `endMonth` (null = forever) |
| `installment` | Parcelada | `settledInstallments + monthsSince(startMonth) + 1`, while ≤ `totalInstallments` |
| `single` | Avulsa | only `startMonth` |

`settledInstallments` is what makes "12x, 5 already paid" work: `startMonth` is the month of the *next*
unpaid parcel, so the projection resumes at number 6 and stops after 12.

A month can diverge from the rule in two ways, and both live outside `expenses` so the rule is never
mutated:

- **`expense_payments`** holds *many* rows per expense per month — one per wallet the money came from.
  That is how "R$ 400 do vale + R$ 200 do salário" is stored. Quitada means
  `sum(payments) >= occurrence.amount`, compared with the half-cent tolerance in `coversAmount`
  (`core/utils/money.dart`). **A payment carries a wallet or `settled_outside = 1`, never neither**
  (`ExpensePayment` asserts `settledOutside == (walletId == null)`; build one from a `PaymentOrigin`
  with `ExpensePayment.fromOrigin`). `settled_outside` is "Outro dinheiro" — money the app does not
  follow, including "it was already paid": it settles the occurrence (`isPaid`, `totalPaid`) but
  stays out of every balance, `spentInMonth` and `MonthSummary.totalSpent`, which sums
  `paidFromWallets`. The default origin comes from `ExpensesViewModel.defaultOriginFor`, which falls
  back to the first wallet when the expense was saved as "Definir na hora". Schema v9 marked the
  null-wallet rows as outside, and `WalletRepository.deleteWallet` turns the wallet's payments into
  outside ones in the same transaction, so the bills it paid stay paid.

  `paid_at` is chosen, not stamped: "Marcar como paga" uses `Payable.suggestedPaidAt` (now in the
  current month, the due day in another), and `PaySheet` ("Outro valor ou data") picks wallet or
  "Outro dinheiro", amount and day through `stampFor`. When the wallet's latest balance check was
  informed after the bill fell due and nothing was paid on it (`checkCoveringDue`), the one tap asks
  whether the money had already left; "Sim" dates it just inside the check (`paidBeforeCheck`), so
  the informed balance does not move.
- **`expense_months`** holds the amount this particular month really cost (light bill, groceries). A
  missing row means "use the rule's amount"; deleting the row is the "back to the rule" action.

`MonthSummary.build` drops a projection that falls before the month the expense was registered
(`Expense.projectsBackIntoPast`) unless that month already has a payment or a month amount. Without
it, a recurring rule saved today with a start month in January billed — and flagged overdue — every
month before the user had the app. `single` is exempt: its month is an explicit choice. The wallet
side mirrors this, since `registerDuePayouts` starts at the later of the wallet's and the payout's
`createdAt` month, so a payout added today to an old wallet does not credit the months already gone;
to fill in a past month the user navigates to it, and the receipt and outflow sheets default to a date
inside the month on screen (`Month.suggestedDate`), not to today.

Changing a rule never rewrites history. When `occurrenceIn(month)` is null but the month has payments
for the expense (the rule was ended, its start moved, its parcels cut or its type changed),
`MonthSummary.build` adds an `ExpenseOccurrence.offRule` — `amount` is the month amount or else what
was paid, and `projectsBackIntoPast` does not apply — so the list, `totalExpenses` and `Saiu` keep
matching the payments. The tile and ledger label it "Fora da regra atual"; removing its payments is
what makes it go away. The expense form only warns (`ExpenseFormViewModel.monthsLeftOffRule`, paid
months the edit newly leaves out) and refuses an end month before the start; deleting an expense with
payments says how many the CASCADE takes and offers "Encerrar neste mês" for a recurring one.

`ExpenseOccurrence` is where the two meet: `amount` (month value), `paidAmount`, `remaining`, `isPaid`,
`isPartlyPaid`. Views read those — never re-derive them.

A **credit card** (`features/cards/`) is not a money source and has no balance: its purchases are
ordinary expenses carrying `card_id`. `CardRepository.saveCard` copies the card's due day and paying
wallet onto them, so occurrences, reminders, the agenda and wallet commitments keep reading those from
the expense with no card awareness. `MonthSummary.invoices` groups a month's occurrences by card into
`CardInvoice`, and `MonthSummary.payables` is what the month owes — loose occurrences plus non-empty
invoices, both behind the `Payable` interface. Lists, the dashboard, the agenda and reminders render
`payables`; totals still sum `occurrences`, so an invoice never changes `totalExpenses`. The month
table stays per item. `CreditCard.invoiceMonthFor` turns a purchase date into the invoice month from
the closing and due days; the expense form applies it when a card is picked, while "Adicionar compra"
from an invoice keeps that invoice's month. Deleting a card leaves its purchases as loose expenses
(`ON DELETE SET NULL`).

A **wallet** (`features/wallets/`) is a money source — salary or a benefit (VR/VA/mercado). It owns
`payouts` (the flexible calendar) which generate `receipts` (credits). A wallet's balance is its
latest **balance check** plus the confirmed receipts, minus the payments charged to it **and its
`outflows`**, counting only what is dated *after* that check (all of it when there is none), so it
carries across months; the month figures on `WalletSummary` are separate.

An **outflow** (`outflows`) is money spent straight from a wallet with no expense rule behind it —
the everyday spending that drains a benefit card. It exists because an `expense` is a *rule* with a
due day, which is the wrong shape for "gastei R$ 47 no mercado hoje". Outflows lower the wallet
balance and `spentInMonth`, and count in `MonthSummary.totalSpent` (hence in `difference`), but never in
`totalExpenses`/`totalPaid` — those stay about the bills, so `totalPending` keeps meaning "what is
still owed on the rules". The Carteiras tab lists receipts, expense payments and outflows together
as `WalletMovement`, with the balance checks; receipts, outflows and checks are editable there, and
what `WalletSummary.countsInBalance` leaves out shows faded as "antes do saldo informado".

A payout is scheduled either by fixed day or by business day (`PayoutSchedule`, `Payout.dateIn(month)`),
because the salary lands on the fifth business day. `Month.businessDay` counts Monday to Friday and skips the
national holidays (`BrazilianHolidays`); state and city holidays still need a manual correction.

A **balance check** (`balance_checks`, `BalanceCheck`) is how the user says "this wallet really
holds X": it stores the *absolute* amount and the instant (`checked_at`), and whatever is dated up to
that instant is already inside the amount, so a movement is never discounted twice and a negative
balance is just a value. The Saldo sheet (`BalanceCheckSheet`) also lists this month's predicted
receipts due by then ("já caiu"), and `WalletRepository.saveBalanceCheck` confirms the ticked ones
in the same transaction. A check for today is taken at `now`; one for a past day at the end of that
day (`WalletsViewModel.checkedAtFor`). Movements picked by day go through `stampFor`
(`core/utils/moment.dart`): today keeps the current time, another day becomes noon — so the order
against a check is deterministic. Checks never count in `receivedInMonth` or
`MonthSummary.totalReceived`. Schema v8 turned the old difference-based adjustments into checks
with the balance the user saw at the time; `receipts.kind` is vestigial (still in `_schema`, never
read or written).

A receipt carries a `ReceiptStatus`: `registerDuePayouts` creates it as `predicted` (it counts nowhere
real until confirmed — not in the balance, `receivedInMonth` or `totalReceived`; it only shows as
expected income, marked "a confirmar"), the user confirms it with the real day and amount, and
`skipped` is how a calendar receipt is dismissed — deleting the row would only make
`registerDuePayouts` recreate it. Deleting the payout itself keeps the money it already brought in:
`deletePayout` removes only the rows still `predicted` and lets `ON DELETE SET NULL` turn the
confirmed ones into manual receipts. Deleting them outright rewrote the balance of every past month. Rows still `predicted` are re-synced to the payout's current amount
and date, which is what makes editing the salary fix the current month.

`MonthAgendaPage` reads the receipts first and the payout calendar only for what has no receipt yet,
so a salary confirmed on the 4th shows on the 4th. Never place a payout by `payout.day` — that is the
*ordinal* under `PayoutSchedule.businessDay`; ask `payout.dateIn(month)`.

`Month` (`core/utils/month.dart`) is the value object used everywhere instead of `DateTime` — it has
comparison operators, `monthsSince`, `dayOf` (clamps day 31 to the real month length) and
`businessDay`.

The database is versioned: bump `AppDatabase.version`, add the statements to `_migrations`, and keep
`_schema` (fresh install) and the migrated result identical. `test/core/database/app_database_test.dart`
builds a v1 file and opens it to prove the upgrade keeps the data, and compares `PRAGMA table_info`,
`index_list`/`index_info` and `foreign_key_list` of every table between a fresh install and the migrated
file — a new column goes at the end of `_schema`'s table, with the same DEFAULT as its `ALTER TABLE`.

A **backup** is the SQLite file itself (`DatabaseBackup`, `core/database/`), not an export format: a
copy saved by an older version goes through the same `_migrations` when restored, so there is nothing
extra to keep in sync when the schema changes. `restore` inspects the file first (SQLite header, the
`wallets`/`expenses` tables, `user_version` not newer than the app), swaps it in while
`AppDatabase.whileClosed` holds every other reader back, and puts the previous file back if opening
the new one fails. The file I/O there is synchronous on purpose — see the widget-test note below.
The system file dialogs sit behind `BackupFiles`, which `AnchorApp` takes so tests can fake them.

**Reminders** (`features/reminders/`) are rebuilt from scratch on every `DataChanges`:
`RemindersViewModel` loads the current and next month, `DueReminder.plan` turns each unpaid occurrence
into a 9h notification (one per day, id `yyyymmdd`), and `ReminderNotifications.replaceAll` cancels
everything and schedules the new list — so paying a bill is what cancels its reminder, with no
bookkeeping of notification ids. Android is asked for permission the first time there is something
to remind, never on its own again; a refusal turns the switch in Ajustes off. Scheduling is inexact
(`inexactAllowWhileIdle`), which needs no exact-alarm permission. The plugin requires core library
desugaring in `android/app/build.gradle.kts` and the two receivers in `AndroidManifest.xml`.

## Testing

`test/support/test_database.dart` gives repositories a real in-memory SQLite via
`sqflite_common_ffi`. Two details are load-bearing: it uses `databaseFactoryFfiNoIsolate` (the override
below does not cross isolates) and it opens `libsqlite3.so.0` explicitly, because this machine has no
`libsqlite3.so` symlink.

`test/app/` boots the whole app with `AnchorApp(database: …)` against that database, and must pass
`reminderNotifications: FakeReminderNotifications()` — the real plugin has no platform side in tests. When adding
widget tests: scope `find.byType(TextField)` to the sheet/page you mean (a sheet does not hide the form
behind it), scope tab taps to `NavigationBar` (feature icons collide with destination icons), and use the
concrete generic (`DropdownButtonFormField<ExpenseType>`).

`MoneyField` takes reais first (`MoneyInputFormatter`): digits grow the integer part and a comma or dot
opens up to two digits of cents, so a test types the amount as it reads — `enterText(field, '47,90')`,
not the old cents-only `'4790'`. `allowNegative` adds the "Trocar sinal" button.

A widget test that needs a real file database (`createFileDatabase`, as in `test/app/backup_test.dart`)
must let real async I/O run: sqflite checks the file with `File.exists()`, which never completes on
the fake clock. Seed with `tester.runAsync` and settle with `runAsync` + `pump` rounds before
`pumpAndSettle`.

## Conventions

- Clean Code: few comments, names that explain themselves.
- Theme lives in `app/theme/`; the palette is green tones (`AppPalette`) and the app must work in
  light, dark and system mode (`SettingsViewModel` persists the choice).
- Money figures take their colour from the `MoneyColors` theme extension (`app/theme/money_colors.dart`,
  `MoneyColors.of(context)`): `income`, `spending`, `neutral` and `predicted`, one set per brightness.
  `test/app/theme/money_colors_test.dart` holds every one of them at 4.5:1 or more against the surfaces.
- Every `FloatingActionButton` needs an explicit `heroTag` — pages stay alive in an `IndexedStack`.
- `FilledButton` is themed full-width (`minimumSize: Size.fromHeight(52)`), so it only goes inside a
  `Row` wrapped in `Expanded` — loose in a row it asks for infinite width and the layout throws.
- Nothing gets a hardcoded width or height that holds text: scale it with
  `MediaQuery.textScalerOf(context)` (the due badge, the wallet chips) or cap it against the incoming
  constraints (the expense tile's amount column). `test/app/responsive_test.dart` walks every tab at
  320dp and at 1.5x font — an overflow there fails the suite, which is how the layout stays honest.
- The logo is one anchor drawn with a single stroke weight: `assets/logo/anchor_logo.svg` is the master,
  `anchor_mark.png` is the white version the app tints per theme, and the launcher icon and both splash
  screens come from `res/drawable{,-night}/ic_logo_*.xml`. Change one, change them all.
- Commits follow Conventional Commits **in English and always with a scope** — `feat(wallets):`,
  `fix(expenses):`, `docs(readme):`. The scope is the feature folder, or `app` for cross-cutting work.
- Do not add `Co-Authored-By` trailers to commits.

## Git

The repository is rooted at this project and has no remote yet. It used to live at `/home/vinicius`
(the user's home), tracking a different app — that repository is gone, but keep scoping `git add` to
explicit paths anyway.
