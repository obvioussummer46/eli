# Verify: tip jar and widget pack retired, Pro repriced

Instructions for a Claude agent on a Mac with Xcode. Branch:
`claude/monetization-structure-planning-dfha6q`. Delete this file once
everything below passes and the branch is merged.

## What changed (read `git log -1 -p --stat` for the diff)

- `ProductID` has six cases left: four icon packs, `proLifetime`, `proYearly`.
  Tips (`tip.*`) and `widgets.pack` are gone.
- `Entitlements` lost `hasWidgetPack` and `hasTipped`; `unlocksPremiumWidgets == isPro`.
- `SupportView` deleted. No "Trinkgeld geben" row, no `schulportalmobile://tips`, no `-shot-tips`.
- Paywall: yearly (4,99 €, 7-day trial) is the prominent button, lifetime (14,99 €) below.
- "Unterstützer" icon is now Pro-gated in the icon picker.
- `Config/Products.storekit` mirrors all of that.

## 1. Build and test (must be green)

```sh
xcodegen generate   # only if the project is stale
xcodebuild -project SchulportalMobile.xcodeproj -scheme SchulportalMobile \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" \
  -derivedDataPath build/DerivedData test 2>&1 | grep -E "error:|warning: unused|Test Case .* (failed|passed)|TEST (SUCCEEDED|FAILED)"
python3 Tools/check-app-store-texts.py
```

Expected: `TEST SUCCEEDED`, no `error:`. Pay attention to
`EntitlementsTests` (rewritten) and `AppIconCatalogTests` (unchanged, must
still pass). Fix any compile error from a reference I missed; search
first: `grep -rn "hasTipped\|justTipped\|widgetPack\|isTip\|SupportView"`.

## 2. Run in the simulator with the local StoreKit config

The run scheme already loads `Config/Products.storekit`. Launch with `-demo`
(demo account, no login) and check in this order:

- [ ] **Mehr** shows a section headed "Ranzen Pro" with exactly two rows:
      "Ranzen Pro freischalten" and "App-Symbol". No "Trinkgeld geben".
- [ ] Paywall (`-shot-paywall` launch argument or the Mehr row): top button
      "Jährlich 4,99 € / Jahr" with "7 Tage kostenlos testen", below it
      "Einmal kaufen 14,99 €". Restore and "Code einlösen" links present.
- [ ] Buy yearly in the StoreKit sandbox. Paywall flips to "Ranzen Pro ist
      aktiv", Mehr shows "Aktiv".
- [ ] App-Symbol: every pack unlocked, the "Unterstützer" section unlocked,
      no Pro badge anywhere.
- [ ] Add the Aufgaben widget on the home screen: real widget, not the
      Pro placeholder.
- [ ] Debug > StoreKit > Manage Transactions: refund the yearly purchase.
      Widgets lock again, packs lock again, "Unterstützer" locks again,
      custom reminder times fall back to defaults.
- [ ] Buy a single icon pack (e.g. "Klassisch") without Pro: only that
      pack unlocks, widgets stay locked, "Unterstützer" stays locked.
- [ ] `xcrun simctl openurl booted schulportalmobile://tips` does nothing
      (no crash, no sheet). `://paywall` and `://icons` still open theirs.

## 3. Old entitlements file

Install the previous build (main) first, buy Pro there, then install this
branch on top. Pro must still be active and the app must not crash on
launch. Covered by `testOlderFilesWithRetiredFlagsStillDecode` in code;
this is the real-device confirmation.

## 4. Report

Reply with the test summary line, anything that failed, and screenshots
of the paywall and the Mehr store section. Do not change prices or
product ids; those are decided (`Docs/MONETIZATION.md`, top).
