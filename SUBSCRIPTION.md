# Subscription & free trial

## Payments: Apple In-App Purchase (not Stripe)

The Pinpoint app subscription **must** use Apple In-App Purchase (StoreKit).
App Store Review Guideline **3.1.1** requires IAP for unlocking digital
functionality used inside the app — Stripe and other external payment methods are
not allowed for that. Apple handles billing, renewals, receipts, refunds, and
Family Sharing, and takes 15% under the App Store Small Business Program
(< $1M/year) — 30% otherwise, dropping to 15% after a subscriber's first year.

**Where Stripe *does* belong:** selling the physical Pinpoint pin (retail, gym,
or your website). Physical goods are outside IAP — use Stripe / normal commerce
for the hardware. Keep the two flows separate: device = Stripe; app service = IAP.

## Product

- One auto-renewable subscription: **Pinpoint Pro**, annual, **$49.99/year**.
- Product ID: `fitness.pinpoint.annual` (`SubscriptionStore.annualProductID`).

## Model: free core + optional Pro

The **core app is free** with the pin — rep/set tracking, history, the workout
builder, gym profiles, and location are never gated. **Pinpoint Pro** ($49.99/yr)
adds value on top. This keeps the device fully useful out of the box (protecting
App Store ratings) while still earning recurring revenue from power users.

Gating is simply `subscriptions.isSubscribed`. A Pro-only action checks it and
shows `PaywallView` if false — see the **CSV export** button in Settings
(`SettingsView.proSection`) for the pattern. The candidate Pro features are in
[`PRO_FEATURES.md`](PRO_FEATURES.md).

## Code map

| Piece | File |
|-------|------|
| StoreKit 2 store (load, purchase, restore, entitlements) | `RST/Services/SubscriptionStore.swift` |
| Trial policy + access decision | `RST/Services/TrialStore.swift` |
| Paywall (with required auto-renewal disclosure + Terms/Privacy) | `RST/Views/Subscription/PaywallView.swift` |
| First-machine trial prompt | `RST/Views/Subscription/TrialPromptView.swift` |
| First-launch onboarding | `RST/Views/Onboarding/OnboardingView.swift` |
| Settings → Subscription | `RST/Views/Settings/SettingsView.swift` |

## Testing the purchase flow locally

No App Store Connect product is needed to test in Xcode:

1. `xcodegen generate` (the `Pinpoint.storekit` file is added to the project).
2. Edit Scheme → **Run → Options → StoreKit Configuration → `Pinpoint.storekit`**.
3. Run; the paywall loads the $49.99 product and `purchase()` completes against
   the local config. Use Xcode's **Debug → StoreKit → Manage Transactions** to
   clear/refund and re-test trial → subscribe transitions.

## Going live (App Store Connect)

1. Enroll in the Apple Developer Program; create the app record (bundle ID
   `fitness.pinpoint.app`).
2. **Monetization → Subscriptions** → create group "Pinpoint Pro" → add an
   auto-renewable subscription with Product ID `fitness.pinpoint.annual`, price
   $49.99, duration 1 year.
3. Add the required **Terms of Use (EULA)** and **Privacy Policy** URLs (the
   paywall already links to them — update the privacy URL to your real one).
4. Add the subscription to a build, submit for review with the app. Apple reviews
   the IAP alongside the app.
5. Sign the **Paid Applications Agreement** and add banking/tax info, or IAP
   won't load in production.
