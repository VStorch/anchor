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
leads to Carteiras. **Até o fim de <mês>** (`ForecastCard`) renders `BudgetSnapshot.forecast`,
a `MonthForecast` built in `features/budget` only for the current month or a later one: per wallet,
today's balance plus what is still expected in (`predicted` receipts, overdue or not, and active
payouts with no receipt yet) minus the `remaining` of the occurrences planned on it, over every month
from the current one to the one on screen; bills with no wallet go to `unassignedToPay`. The
wallets are split by `WalletKind` into two `ForecastGroup`s — `freeMoney` (salaries, which also carry
`unassignedToPay`) and `benefits` — and **the two groups are never added up on screen**: a meal
voucher does not pay the rent. The headline is "Dinheiro livre vai sobrar/faltar R$ X" ("Nos
benefícios vai sobrar" when there is no salary), the line under it "Benefícios: R$ X"
or "No VR vai faltar R$ X" (`shortBenefits`), then, for the current month only, "Por dia: R$ X ·
R$ Y no VR" (`dailyAllowance`; the title already names the month). "Como chegamos nisso" opens one
block per group that has something to show, and each block reads as a sum: "Você tem hoje"
(`startBalance`), "A receber", "Contas a pagar", "Reserva" (split by month from `reserveShares` when
the month on screen is a later one: "R$ 300 em setembro + R$ 600 em outubro"), "Contas sem carteira",
and ends on "Vai sobrar/Vai faltar" with the figure the title shows; a term that is zero is left out,
as in `TodayCard`. Once a reserve exists, "Reserva: R$ 600/mês"
under the headline edits it. `ForecastGroup.reserveState` (`ReserveState`) says what limits this
month's share, from the two terms each wallet keeps (`reserveLeft`, `reservePace`): `usedUp` (the
month's spending took the whole reserve — the daily line reads "Por dia: reserva de setembro usada"),
`paceExceeded` (today's spending passed the day's pace while the month still has reserve — "Por
dia: passou do ritmo hoje"), `byDaysLeft` (the explanation says "13 de 30 dias", "1 de 30 dias") or
`byWhatIsLeft` ("o que resta"). The card is outlined and coloured `MoneyColors.predicted`, and its
headline and summary lines hold no real figure; "Como chegamos nisso" may start from "Você tem hoje"
because today's balance is the base of the sum being explained, not a figure set beside a planned
one, and may note "Hoje já saiu R$ 25,00" under the reserve as plain text, outside the sum. The Resumo's wallet strip
shows balances only — no "a pagar" beside them. **<Mês> até agora** (current
month) or **<Mês>** (past; hidden for a future month) is `MonthSoFarCard`: `Entrou` and `Saiu`,
confirmed money only. `MonthSummary` carries no planned income; the payout calendar's total lives
on `Wallet.monthlyIncome` and is shown only on the Carteiras tab, labelled "por mês". **Never put a planned figure next to a
real one in the same block** — the only real figures a forecast shows are inside its own explanation:
the starting term and today's spending note.

A salary may set aside a **reserve for everyday spending** (`wallets.monthly_reserve`, schema v13,
null by default and never read for a benefit, whose balance already is what is left for food). It is
`WalletForecast.reserve`, subtracted from `endBalance` and kept as `reserveShares`, one per month so
the screen can say where it comes from: in the current month
`max(0, min(reserve − everyday spending of the month, reserve × daysLeft / daysInMonth − spent today))`
— a reserve set on the 16th only takes the days still ahead (`daysLeft` counts today), and a spending
launched today comes out of today's part instead of being counted on top of it — plus the whole
reserve for every later month up to the one on screen. The explanation says where the current share
comes from with `daysLeftInCurrentMonth`/`daysInCurrentMonth` ("Reserva · 13 de 30 dias", or
"R$ 235 em setembro (13 de 30 dias) + R$ 600 em outubro"), and `ForecastGroup.spentToday` adds
"Hoje já saiu R$ 25,00" under that line — in the explanation, never beside the daily figure. Everyday spending is `EverydaySpending.collect`: the wallet's
outflows and the one-off (`single`) card purchases whose card is paid by that wallet, on their
`purchased_at` day — a purchase in parcels was planned, so it stays a bill. While no salary has one,
`ForecastGroup.lacksReserve` shows "Reservar gasto do dia a dia" under the headline; the
`DailySpendingSheet` ("Reserva do dia a dia", the same name the wallet form and the onboarding use) saves it through `WalletRepository.saveMonthlyReserve` (one UPDATE, one publish;
"Sai de" with two or more salaries, "Não usar reserva" clears it) and suggests "Usar a média" from
`OutflowAverage` (`BudgetSnapshot.outflowAverageOf`): the last three complete months before the
current one with any everyday spending, months before the wallet was created included. The wallet form and the onboarding's "Quanto tem hoje?"
step ask it too, both optional. The wallet form carries the stored value, so editing a wallet never
wipes it.

`ForecastGroup.dailyAllowance` answers "how much can I spend per day": only for the current month
(`MonthForecast.daysLeft` is null for a later one), it takes what the month leaves before the reserve
(`endBalance + reserve`, bills with no wallet included for free money) and, when the group has a
reserve, caps it at what is left of the reserve — the plan is to live on the reserve and keep the
leftover — then divides by `daysLeft`; never below zero.

The two real blocks reconcile with the balance instead of contradicting it. `TodayCard` opens
"De onde vem esse valor" and reads each wallet's balance as
`checkAmount + receivedSinceCheck - spentSinceCheck` (`WalletSummary`, the same folds that build
`balance`, so the invariant holds by construction): "Saldo de 15/09, 9h04" — the hour only
when the check does not close the day (`closesDay`) — then "Entrou depois" and "Saiu depois", a zero
line dropped and "Nada lançado depois" when both are. A wallet with no check starts at "Cadastro
em 13/09". `MonthSoFarCard` shows a third figure, `MonthReconciliation.balanceChange`
("Somou ao saldo"/"Tirou do saldo"), **only when nothing of the month is inside an informed balance**
— a payment counts in the month of the bill, so with a check inside the month the subtraction would
count money twice. Otherwise it shows one line with `receivedBeforeCheck`/`spentBeforeCheck` and the
`coveringChecks` that hold them: "Já no saldo de 15/09: entrou R$ X · saiu R$ Y" ("Já nos saldos de
12/09 (VR) e 15/09 (Salário): …" when the checks fall on different days). `MonthReconciliation` (`features/budget/models/`) is built by
`BudgetService` from the `WalletSummary` list — `MonthSummary` knows nothing of wallets or checks —
and `MonthSummary.difference` stays for the tests only: no view reads it.

"Today" is injectable: `MonthSummary.build(today:)` keeps it in `summary.today`, and
`BudgetService.loadSnapshot(month, now:)` passes the same instant to `registerDuePayouts(now:)`, the
summaries and the forecast, so a service test pins the date instead of reading the clock. The whole
app can be pinned too: `AnchorApp(clock:)` (a `Clock`, `core/utils/clock.dart`, also provided) feeds
`BudgetService(clock:)`, `MonthSelection(clock:)`, `RemindersViewModel` and the onboarding. Widgets
that pick dates (`pickMovementDate`, `Month.suggestedDate`, the "Hoje" button) still read the device
clock.

- **`features/budget/`** is not a screen. It is the aggregation layer every other feature reads:
  `BudgetService.loadSnapshot(month)` reads all four repositories and returns a `BudgetSnapshot`
  (`MonthSummary` + `WalletSummary` per wallet + raw lists). Dashboard, Expenses and Wallets all render
  from a snapshot, so **totals are computed in one place** — add derived numbers to `MonthSummary`/
  `WalletSummary`, never in a view.
- **`core/state/`** holds the two notifiers shared by all view models: `DataChanges` (repositories call
  `publish()` after every write) and `MonthSelection` (the month the whole app is showing).
  `ReactiveViewModel` subscribes to `DataChanges` and re-runs `loadData()`, which is why a write in one
  tab refreshes the others with no manual plumbing. `DataChanges.hold(action)` keeps every `publish()`
  inside it pending (reentrant) and notifies once when the outermost hold ends, even if it throws — a
  composed action that goes through several repositories reloads the app, and reschedules the
  reminders, once. It groups the notifications, not the writes: it is no transaction.

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
| `recurring` | Todo mês | every month from `startMonth` until `endMonth` (null = forever) |
| `installment` | Parcelada | `settledInstallments + monthsSince(startMonth) + 1`, while ≤ `totalInstallments` |
| `single` | Só uma vez | only `startMonth` |

A new installment expense assumes no count: "Total de parcelas" is a number field, empty until the
user types it, and the save button reads "Informe o total de parcelas" meanwhile. It takes 2 to 480;
anything else stays exactly as typed, with a field error and the button saying what is wrong, never
clamped into another number. "Parcelas já pagas" and the total preview ("Ainda falta pagar", shown
for installments only — for the other types it would repeat the amount typed) only show once the
count is valid (`ExpenseFormViewModel.showsInstallmentPlan`). An expense on a
card is a purchase (`ExpenseFormViewModel.isPurchase`): the fields read "O que comprou" and "Como
pagou", the types "À vista" (`single`), "Parcelado" (`installment`) and "Todo mês" (`recurring`, a
subscription on the card); a new one starts à vista, titled "Nova compra no Nubank" and saved with
"Salvar compra" (`isNewPurchase`), and picking a card for a new "Todo mês" expense keeps it
recurring. A purchase in parcels is typed by its total price ("Valor total da compra"); the parcel
stored is the total over the count rounded to the cent, and the preview is honest about it: "3x de
R$ 333,33 (total R$ 999,99)" whenever the parcels do not add back to the typed total
(`storedTotal`), which is also what `_TotalPreview` shows. "Informar valor da parcela" switches to
typing the parcel and converts the value (parcel × n one way, total / n the other); switching a
purchase, new or existing, from à vista to Parcelado carries the amount into the total, and back.
Loose expenses keep their wording.

`settledInstallments` is what makes "12x, 5 already paid" work: `startMonth` is the month of the *next*
unpaid parcel, so the projection resumes at number 6 and stops after 12. The form names that month
by type ("Começa em", "Próxima parcela", "Vence em") and previews the parcel the month on screen gets
(`ExpenseFormViewModel.installmentPreview`: "Setembro de 2026 será a parcela 4 de 10").

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
  outside ones in the same transaction, so the bills it paid stay paid. Its confirmation dialog says
  what goes with it from `BudgetSnapshot.deletionImpactOf` (`WalletDeletionImpact`): the receipts,
  outflows and balance checks the CASCADE deletes, the bills that stay paid as "Outro dinheiro", and
  the bills and cards left with no wallet — one line per non-zero count.

  `paid_at` is chosen, not stamped, and never in the future: "Marcar como paga" uses
  `Payable.suggestedPaidAt` (the due day for a past month, now for the current or a later one — the
  `month_key` stays the occurrence's), and `PaySheet` ("Outro valor ou data") picks wallet or "Outro
  dinheiro", amount and day through `stampFor`. Every movement date picker (`pickMovementDate`:
  payments, receipts, outflows, card purchases) stops at today. When the wallet's latest balance check
  was informed after the bill fell due and nothing was paid on it (`checkCoveringDue`), the one tap,
  the first amount typed in the table's "Pago" cell and the `PaySheet` (until a day is picked by
  hand) all ask "Já tinha saído do saldo de 15/09?" ("do saldo das 9h04" when the bill is due today);
  "Já tinha saído" (the other answer is "Paguei agora") dates it just inside the check
  (`Payable.paidBefore`), so the informed balance does not move.
- **`expense_months`** holds the amount this particular month really cost (light bill, groceries). A
  missing row means "use the rule's amount"; deleting the row is the "back to the rule" action.
  When `PaySheet` records less than a recurring or one-off bill off any card still owes (not an
  invoice, a card purchase, a parcel or an off-rule month — those cost what was agreed, so less is
  simply a part), it asks "A conta deste mês foi R$ X" (the default: the light bill was just smaller) or "Paguei só uma
  parte (falta R$ Y)"; the first saves the payment and sets the month amount to everything paid, in
  one transaction (`ExpenseRepository.savePaymentClosingMonth`). The one tap pays the whole
  remainder, and the table's "Pago" cell stays partial — the "Valor" cell is right beside it.

`MonthSummary.build` drops a projection that falls before the month the expense was registered
(`Expense.projectsBackIntoPast`) unless that month already has a payment or a month amount. Without
it, a recurring rule saved today with a start month in January billed — and flagged overdue — every
month before the user had the app. `single` is exempt: its month is an explicit choice. The wallet
side mirrors this, since `registerDuePayouts` starts at the later of the wallet's and the payout's
`createdAt` month, so a payout added today to an old wallet does not credit the months already gone;
to fill in a past month the user navigates to it, and the receipt and outflow sheets default to a date
inside the month on screen (`Month.suggestedDate`), not to today — except a future month, which gets
today.

Changing a rule never rewrites history. When `occurrenceIn(month)` is null but the month has payments
for the expense (the rule was ended, its start moved, its parcels cut or its type changed),
`MonthSummary.build` adds an `ExpenseOccurrence.offRule` — it owes nothing: `amount` is what was paid
(a month amount stored earlier is kept but ignored, and `setMonthAmount` refuses it), `remaining` is 0
and it is never overdue, and `projectsBackIntoPast` does not apply — so the list, `totalExpenses` and
`Saiu` keep matching the payments. The tile and ledger label it "Fora da regra atual" (the ledger
footer reads "Fora da regra atual · R$ X pagos" and hides the month amount); removing its payments is
what makes it go away. The expense form only warns (`ExpenseFormViewModel.monthsLeftOffRule`, paid
months the edit newly leaves out) and refuses an end month before the start; deleting an expense with
payments says how many the CASCADE takes. "Encerrar neste mês", in the ledger menu and that dialog,
needs `Expense.canEndIn(month)` — a recurring rule that still bills the month — and
`endRecurringExpense` refuses it otherwise, so it never writes an end before the start nor reopens
months after an old end.

`ExpenseOccurrence` is where the two meet: `amount` (month value), `paidAmount`, `remaining`, `isPaid`,
`isPartlyPaid`. Views read those — never re-derive them. The same goes for the date: `Payable.dueState`
(`DueState`: paid, offRule, overdue, today, tomorrow, upcoming, in that precedence) is read against the
`today` `MonthSummary.build` injects into every occurrence and invoice, so a test pins the day and no
view compares dates. `isOverdue` is `dueState == DueState.overdue`; the tile paints "Atrasada",
"Vence hoje" (`MoneyColors.spending`, badge included) and "Vence amanhã" from it, the dashboard's
"A pagar" counts `overduePayables` and `dueTodayPayables`, and the "já tinha saído?" question is
worded by the hour of the check when the bill is due today.

A **credit card** (`features/cards/`) is not a money source and has no balance: its purchases are
ordinary expenses carrying `card_id`. `CardRepository.saveCard` copies the card's due day and paying
wallet onto them, so occurrences, reminders, the agenda and wallet commitments keep reading those from
the expense with no card awareness. `MonthSummary.invoices` groups a month's occurrences by card into
`CardInvoice`, and `MonthSummary.payables` is what the month owes — loose occurrences plus non-empty
invoices, both behind the `Payable` interface. Lists, the dashboard, the agenda and reminders render
`payables`; totals still sum `occurrences`, so an invoice never changes `totalExpenses`. The month
table stays per item. A purchase stores the day it was made (`expenses.purchased_at`, schema v10) and
the invoice month always comes from it through `CreditCard.invoiceMonthFor` — the form asks for
"Data da compra" (today by default) instead of a month, sets `startMonth` to that invoice plus the
parcels already paid, and warns when it differs from the invoice it was opened from ("Adicionar
compra", `ExpenseFormViewModel.leavesOpenedInvoice`), so a purchase made after the closing day never
lands on a statement that is already due. A purchase saved before v10 has no date and keeps its month
editable until one is picked. `CardInvoice` takes `today` from `MonthSummary` and reports
`InvoiceStatus` — paid, else overdue, else closed once `today` is past `CreditCard.closingDateOf`,
else open — shown as "Aberta · fecha 03/10", "Fechada · vence 10/10", "Atrasada" or "Paga"; its
`purchases` are ordered by purchase day — an invoice with no purchases says "Sem compras · fecha
03/10" instead, because it owes nothing. Deleting a card leaves its purchases as loose expenses
(`ON DELETE SET NULL`).

The Carteiras tab shows a card through `BudgetSnapshot.cardOverview` (`CardOverview`, built once
per snapshot): in the current
month, `shown` is the invoice a purchase made today lands on (`invoiceMonthFor(today)`, which can be
two months ahead) and `pending` holds the older invoices with purchases and still unpaid, up to 12
months back, oldest first; in any other month it is that month's invoice alone. Those invoices are
built on demand with `BudgetSnapshot.invoiceOf(cardId, month)` and `occurrenceOf(expenseId, month)`,
which rebuild a `MonthSummary` for that month from the raw lists **with the snapshot's own `today`**,
so nothing reads the clock again. `CardInvoiceSheet.show` and `ExpenseLedgerSheet.show` therefore
carry the month they were opened on, and `MonthSelection` never moves to show an invoice.

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
still owed on the rules". Each wallet's statement (`WalletDetailPage`, not the Carteiras tab, which
has no movement list) shows its receipts, expense payments and outflows together as
`WalletMovement`, with the balance checks; receipts, outflows and checks are editable there, and
what `WalletSummary.countsInBalance` leaves out shows faded as "antes do saldo informado".

Each wallet card carries the actions instead of hiding them: `WalletBalanceHeader` (the balance and
"Setembro: entrou … · saiu …", built from `WalletSummary`), `WalletActionButtons` (Gasto, Entrada,
Saldo in a `Wrap`, in that order on every wallet; TalkBack reads "Informar saldo do Salário") and,
for a benefit only, a bar of `WalletSummary.leftRatio` — the balance over the balance plus
`spentInCurrentMonth`, 0 with no balance — with no caption: its semantics label says "Saiu R$ 99,70
em setembro". The bar speaks of the month of the snapshot's `today` (`WalletSummary.currentMonth`),
whatever month is on screen, so it neither repeats the balance the header shows nor drains with
months long gone. Tapping the card opens `WalletDetailPage` — the same header, now with
`showBalanceLine` on ("Saldo de 15/09, 9h04: R$ 850,00 · −R$ 99,90 depois", which the card leaves to
the Resumo's "De onde vem esse valor" and to TalkBack), the same buttons, `MonthSwitcher` and the
statement of the month on screen (`WalletsViewModel.movementsOf`), with the pencil in its AppBar for
`WalletFormPage`; deleting the wallet leaves `summaryFor` null and the page pops itself.

The tab's FAB is **"Novo gasto"** (`heroTag: 'new-spending'`, and the Resumo has the same button as
`'dashboard-new-spending'`, both through `WalletActions.newSpending`): with a single wallet and no card it
opens the outflow sheet straight away, otherwise `SpendingSourceSheet` asks "De onde saiu o dinheiro?"
and returns a `SpendingSource` — `WalletSource` (outflow), `CardSource` (the expense form on that
card, "Entra na fatura de outubro" from `WalletsViewModel.invoiceMonthForToday`) or `BillSource` (the
expense form with no source). The Salário, Benefícios and Cartões sections are always there and each
ends with a full-width row — "Adicionar salário", "Adicionar benefício" (`WalletFormPage(initialKind:)`)
and "Adicionar cartão" — instead of a "+" in the header, which sat under the FAB; the empty tab has no
FAB, only "Cadastrar salário ou benefício".

A payout is scheduled either by fixed day or by business day (`PayoutSchedule`, `Payout.dateIn(month)`),
because the salary lands on the fifth business day. `Month.businessDay` counts Monday to Friday and skips the
national holidays (`BrazilianHolidays`, where November 20 only counts from 2024); state and city holidays
still need a manual correction. `PayoutSchedule.businessDaySaturday` ("Sábado conta como dia útil", a
switch under "Dia útil") counts Saturdays too, and a date that lands on one moves back to the bank business
day before it. A position below 1 reads as 1; `schedule_kind` is TEXT, so a new schedule needs no migration.

A **balance check** (`balance_checks`, `BalanceCheck`) is how the user says "this wallet really
holds X": it stores the *absolute* amount and the instant (`checked_at`), and whatever is dated up to
that instant is already inside the amount, so a movement is never discounted twice and a negative
balance is just a value. The Saldo sheet (`BalanceCheckSheet`) also lists this month's predicted
receipts due by then ("já caiu"), and `WalletRepository.saveBalanceCheck` confirms the ticked ones
in the same transaction and marks the unticked ones with the check (`receipts.pending_at_check_id`,
schema v11, `ON DELETE SET NULL`): a receipt left unticked had not arrived when the amount was
informed, so once confirmed it counts after that check whatever its date. The rule is
`WalletSummary.countsReceipt` — no check, dated after the latest one, or marked with the latest one —
while payments and outflows keep `countsInBalance(at)`. Checks migrated from v8 have no marks, so
their predictions stay inside the amount. A check for today is taken at `now`; one for a past day at the end of that
day (`WalletsViewModel.checkedAtFor`). Movements picked by day go through `stampFor`
(`core/utils/moment.dart`): today keeps the current time, another day becomes noon — so the order
against a check is deterministic. On the very day of the wallet's latest check (when it does not close
the day) the outflow, receipt and pay sheets ask "Foi antes ou depois de você informar o saldo
(13h)?" (`CheckSideSelector`, default "Depois") and save through `stampAround` — a second before or
after the check (`CheckSide`); the pay sheet asks it for the wallet picked, and only once the "já
tinha saído?" question is out of the way. Editing a movement without touching its day or side keeps
the stored instant. A past day holds one check per wallet: informing it again asks "Já existe um
saldo informado em 12/09 (R$ X). Substituir?" and edits that check (`WalletsViewModel.checkOnDay`,
which `saveBalanceCheck` also applies), while today may hold several. Editing a check that is not
the latest warns that it does not change today's balance. Checks never count in `receivedInMonth` or
`MonthSummary.totalReceived`. Schema v8 turned the old difference-based adjustments into checks
with the balance the user saw at the time; `receipts.kind` is vestigial (still in `_schema`, never
read or written).

A receipt carries a `ReceiptStatus`: `registerDuePayouts` creates it as `predicted` (it counts nowhere
real until confirmed — not in the balance, `receivedInMonth` or `totalReceived`; it only shows as
expected income, marked "a confirmar"; each wallet card offers a "Confirmar" button that opens the
`ReceiptSheet` of `WalletsViewModel.firstUnconfirmedOf`), the user confirms it with the real day and amount (the
`ReceiptSheet` of a prediction of the current month opens on now; one from a past month keeps its
calendar day), and `skipped` is how a calendar receipt is dismissed — deleting the row would only make
`registerDuePayouts` recreate it. A `predicted` receipt from a month before the current one is
confirmed by `registerDuePayouts` itself, in one idempotent UPDATE before it credits anything: once
its month is over it is assumed received ("Não recebi" still dismisses it), which is also what brings
back the numbers of a database that went through v8 with salaries never confirmed. Deleting the
payout itself keeps the money it already brought in: `deletePayout` removes only the rows still
`predicted` and lets `ON DELETE SET NULL` turn the confirmed ones into manual receipts. Deleting them
outright rewrote the balance of every past month. Rows still `predicted` are re-synced to the
payout's current amount and date, which is what makes editing the salary fix the current month.

`MonthAgendaPage` reads the receipts first and the payout calendar only for what has no receipt yet,
so a salary confirmed on the 4th shows on the 4th. Never place a payout by `payout.day` — that is the
*ordinal* under `PayoutSchedule.businessDay`; ask `payout.dateIn(month)`. Every title of a receipt —
agenda, Carteiras movements, the Saldo sheet — comes from `Wallet.titleFor(receipt)`: the wallet name
alone while the wallet has a single payout, `"Salário · Adiantamento"` (or `"Salário · dia 20"`,
`Payout.nameOrSchedule`) when there are more, and "Entrada extra" with no payout behind it, deleted
payouts included. A payout's `label` is an optional name, empty by default (v12 cleared the old
"Mensal"/"Recebimento"), and the movement subtitle drops the wallet name when
`Wallet.titleIsWalletName` already says it.

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
`RemindersViewModel` loads the current and next month (`loadSnapshot(month, now:)` with its clock),
`DueReminder.plan` turns each unpaid payable into a 9h notification on the due day ("vence hoje"), the
day before ("vence amanhã") or both, as the `ReminderLead` picked in Ajustes says (prefs
`reminders_lead`, default both). Bills sharing a due day and a lead share one notification, whose id is
`yyyymmdd * 10 + days ahead` — a bill due tomorrow and one due today never collide at the same 9h, and
the id stays below 2^31. `ReminderNotifications.replaceAll` cancels
everything and schedules the new list — so paying a bill is what cancels its reminder, with no
bookkeeping of notification ids. Android is asked for permission the first time there is something
to remind, never on its own again; a refusal turns the switch in Ajustes off.
`ReminderNotifications.areEnabled()` asks Android whether the app's notifications can show at all;
when the switch is on and they cannot (`RemindersViewModel.systemBlocked`), Ajustes and the
onboarding's Lembretes step show `NotificationsBlockedNotice`, which only says where to turn them on —
opening the system settings would take another plugin. `RemindersResumeWatcher`, around the whole
`MaterialApp`, calls `recheckSystem()` whenever the app resumes, so the notice goes away as soon as
the user comes back from turning them on. Scheduling is inexact
(`inexactAllowWhileIdle`), which needs no exact-alarm permission. The plugin requires core library
desugaring in `android/app/build.gradle.kts` and the two receivers in `AndroidManifest.xml`.

**Onboarding** (`features/onboarding/`) is the first run. `MaterialApp.home` is `FirstRunGate`
(`app/first_run_gate.dart`): with `SettingsViewModel.onboardingDone` (prefs `onboarding_done`) it is
the `AppShell`; otherwise it asks `OnboardingService.needsOnboarding(now)` once, which is
`BudgetSnapshot.isBlank` (no wallets, expenses or cards) — someone who already has data, like a user
updating from a version without onboarding, gets the flag saved and never sees it. `OnboardingPage`
walks `OnboardingStep`: welcome, "Quanto você recebe?" (salary plus any number of benefits, each added with "Adicionar benefício",
removable, keyed `income-benefit-<IncomeDraft.key>` and named once there are two; amount, "Dia
fixo"/"Nº dia útil" with the CLT Saturday switch, day, and "Em setembro cai ter, 8/set"), "Quanto tem
hoje?" (one amount per source; when the source's date this month has come,
`IncomeDraft.isDueBy`, "O salário de 8/set já está nesse valor?" [Sim]/[Ainda não caiu], no default),
"Contas de todo mês" (suggestion chips + "Outra", each with amount and a required due day; one already
past due asks "Já pagou a de setembro?", default Sim), "Compras parceladas" ("Qual parcela vence este
mês? [4] de [10]" → `settledInstallments = 3`), "Cartão de crédito" (optional, with the paying source)
and "Lembretes". Every step but the first and last has "Pular", and "Pular configuração" is always on
top; it saves nothing (it asks first when something was typed) and the dashboard's empty state stays
for whoever skipped. The disabled primary button reads what is missing (`OnboardingViewModel.blocker`).
The drafts (`models/onboarding_draft.dart`) are mutable and edited through `viewModel.edit(() => …)`;
a skipped step is left out of `viewModel.draft`, and skipping the income skips the balance step.
Days are picked through `DayButton`'s sheet, so the page keeps 48dp targets at 320dp.

Nothing is written until the end. On "Ativar lembretes" the view model sets the `ReminderLead` and
calls `RemindersViewModel.setEnabled(true)` — the only time Android's permission dialog shows with
context; "Agora não" turns reminders off, so the first bill does not trigger the dialog later. Then
`OnboardingService.apply(draft, now:)` runs inside `DataChanges.hold` with one `now`: wallets with
their payout (`createdAt = now`); `registerDuePayouts(now:)` creates this month's predicted receipts,
and each source with an amount gets `saveBalanceCheck` at `now`, confirming its receipt ("Sim", dated
on the payout day, inside the check) or marking it `pending_at_check_id` ("Ainda não caiu"); with no
amount the receipt stays predicted. Then the card, the bills (`recurring`, `startMonth` = current
month) and the installments, all charged to the first source (the salary), and a payment for each
"already paid" one dated by `Payable.paidBefore(check)` — the due day at noon, inside the balance, so
the amount typed is the amount shown. Every source, each benefit included, is its own wallet with its
own payout, check and receipt. `markOnboardingDone` swaps the gate to the Resumo. Bills are not
asked which wallet pays them; a partial failure leaves partial, editable data.

**Tips** (`AppTip`, `features/settings/`) are one line each at the top of Resumo, Despesas (list layout
only, as its first scrolling item, so the table keeps its height) and Carteiras, never over an empty
state. `TipCard` shows one until "Entendi"; `SettingsViewModel` keeps the seen ids in prefs
`seen_tips`, shows none before `onboarding_done`, and "Rever dicas" in Ajustes clears them.

## Testing

`test/support/test_database.dart` gives repositories a real in-memory SQLite via
`sqflite_common_ffi`. Two details are load-bearing: it uses `databaseFactoryFfiNoIsolate` (the override
below does not cross isolates) and it opens `libsqlite3.so.0` explicitly, because this machine has no
`libsqlite3.so` symlink.

`test/app/` boots the whole app with `AnchorApp(database: …)` against that database, and must pass
`reminderNotifications: FakeReminderNotifications()` — the real plugin has no platform side in tests.
Its `setUp` calls `mockPreferences()` (`test/support/preferences.dart`), which sets `onboarding_done`
so an empty database opens on the tabs instead of the first run, and marks every tip seen; extra prefs go in its map
(`mockPreferences({'theme_mode': theme})`). `FakeReminderNotifications` grants the permission and
reports the notifications enabled; `grantsPermission` and `systemEnabled` turn either off. `test/app/onboarding_flow_test.dart` starts without it and
pins `AnchorApp(clock:)` to 15/09/2026; `test/support/onboarding_driver.dart` fills the whole setup
and is reused by `responsive_test.dart`, which walks it at 320dp and 1.5x for overflow and, on a
320×2400 view (no target half scrolled out, which the guideline would measure as a sliver), checks
tap targets, labels and contrast in light and dark. When adding
widget tests: scope `find.byType(TextField)` to the sheet/page you mean (a sheet does not hide the form
behind it), scope tab taps to `NavigationBar` (feature icons collide with destination icons), and use the
concrete generic (`DropdownButtonFormField<ExpenseType>`).

`MoneyField` takes reais first (`MoneyInputFormatter`): digits grow the integer part and a comma or dot
opens up to two digits of cents, so a test types the amount as it reads — `enterText(field, '47,90')`,
not the old cents-only `'4790'`. `allowNegative` adds the "Trocar sinal" button and is the only way a
sign survives the formatter. The formatter tells three edits apart: typing or erasing at the end goes key
by key; an edit in the middle drops the dots (never decimals in our own text) and joins the digits, so
erasing the comma of "R$ 10,50" gives "R$ 1.050"; a paste into an empty field or over the whole selection
is read as foreign text — a comma is the decimal, and with none a dot followed by one or two digits at the
end is (`12.5` → "R$ 12,50"). The table cells never accept a negative amount. The typed value uses the theme's field text; `prominent`
(large and bold) is only for the sheets about one amount: outflow, receipt, balance check and pay.

A widget test that needs a real file database (`createFileDatabase`, as in `test/app/backup_test.dart`)
must let real async I/O run: sqflite checks the file with `File.exists()`, which never completes on
the fake clock. Seed with `tester.runAsync` and settle with `runAsync` + `pump` rounds before
`pumpAndSettle`.

## Conventions

- A new expense, card or payout starts with no day picked: `DayOfMonthPicker` takes a null
  `selectedDay`, and the save button stays disabled reading "Escolha o dia…" until one is chosen,
  so a default never slips into the data unnoticed. Widget tests that save one tap the day first.

- Wallet actions (the outflow, receipt, balance-check and confirm sheets) live in
  `wallets/views/wallet_actions.dart` and are shared by the Carteiras tab and `WalletDetailPage`;
  the movement line is `widgets/movement_tile.dart`. A page that opens with
  `ChangeNotifierProvider.value` keeps the app's `WalletsViewModel`, so the month stays shared.

- Clean Code: few comments, names that explain themselves.
- Theme lives in `app/theme/`; the palette is green tones (`AppPalette`) and the app must work in
  light, dark and system mode (`SettingsViewModel` persists the choice).
- Money figures take their colour from the `MoneyColors` theme extension (`app/theme/money_colors.dart`,
  `MoneyColors.of(context)`): `income`, `spending`, `neutral` and `predicted`, one set per brightness.
  `test/app/theme/money_colors_test.dart` holds every one of them at 4.5:1 or more against the surfaces.
  A movement is coloured by what it is — `income`, `spending`, `neutral` for a balance check,
  `predicted` for what has not happened (a receipt to confirm, a bill not yet paid) — and drawn with
  `MoneyIcons` (`app/theme/money_icons.dart`): down comes in, up goes out, in the Carteiras list, the
  agenda and the sheet titles (`MovementSheetTitle`). `wallet.color` paints avatars and bars only,
  never text: a balance is `onSurface`, or `error` when negative.
- Every `FloatingActionButton` needs an explicit `heroTag` — pages stay alive in an `IndexedStack`.
  A list under an extended FAB ends with `fabClearance(context)` of bottom padding
  (`core/widgets/fab_clearance.dart`), which scales with the font. The add buttons of Despesas,
  Carteiras, the Resumo and `WalletDetailPage` are `ScrollAwareFab` (`core/widgets/scroll_aware_fab.dart`),
  which wraps the page's `Scaffold` and hands its `builder` the button for
  `Scaffold.floatingActionButton` — so the Scaffold still lifts it above the gesture bar and
  snackbars. At rest the button sits over the right column, so it slides away while the list scrolls
  down, comes back on scrolling up, at the end, when the list cannot scroll or when `contentKey`
  changes (month, filter, layout, a reload — an empty state has nothing to scroll back up), shrinks
  to its icon once the list leaves the top (after a content change it rereads where the list it last
  heard from stands, so a reload over a scrolled list keeps it round), and is round from the start over the table. Tests find it by `heroTag`, since a
  collapsed button has no label. Scroll metrics arrive during layout, so it applies their changes
  after the frame. The month table is one vertical scroll —
  a `CustomScrollView` with the column titles in a `PinnedHeaderSliver`, every row, the Total as the
  last row, the legend "Valor em verde: mudou só neste mês" when a month amount (`expense_months`,
  painted `primary`) is on screen, and `fabClearance` below — so no row hides in a smaller inner
  scroll; the three columns of
  amounts scale with the font and scroll sideways together when the table is wider than the screen. Its headers say "Valor (R$)", "Pago (R$)" and "Falta (R$)", so no cell repeats
  the symbol: values and the Total go through `formatAmount`, and a cell is typed with
  `MoneyInputFormatter(symbol: false)`.
- Every day, date or month picker calls `releaseFocus()` (`core/widgets/dismiss_focus.dart`) before
  opening: a closing route gives the focus back to the field focused before it, and the keyboard
  would cover the answer. `DayButton` takes a `placeholder` that names which day it asks ("Dia em que
  a fatura fecha"), and after a pick scrolls itself up so a question that appears below is seen.
- Anything tappable is at least 48dp and says what it is to TalkBack (the colour dots are labelled
  buttons, the month title is a header). `responsive_test.dart` runs `androidTapTargetGuideline` and
  `textContrastGuideline` on every tab in light and dark, `labeledTapTargetGuideline` on the wallet
  form and the month table (whose name, Valor and Pago cells are 48dp and read "Pago de Luz: R$
  137,52" / "Pago de Luz: nada"), and checks the FAB never covers the last item at 320dp and 1.3x font.
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
