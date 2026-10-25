# Home Run for iOS

Home Run is a student-to-student pickup app for iPhone. A customer posts a request for a restaurant, a store, or a personal item without naming a runner. A runner browses open requests and claims one. The customer pays the store. Home Run's only charge is a simulated delivery fee.

One account can order and run. Ordering and Running stay available as separate workspaces.

## Run it

Open `HomeRun.xcodeproj` and run the HomeRun scheme on an iPhone simulator or a phone. The app targets iOS 17.

Google keys go in `Config/Local.xcconfig`, which Git ignores. Copy `Config/Local.xcconfig.example`. The Maps SDK key, the Places API (New) key, and the Routes API key are separate. With Places unset, search uses the labeled sample catalog. With Routes unset, routing uses the existing road fallback. Map tiles use Apple Maps until the Maps SDK key is present.

`Info.plist` holds build-setting placeholders only. Do not put keys in source, the plist, or a commit.

## Delivery fee

Quotes use policy `demo-2026-10-scale`. Amounts are cents and stay on this phone. No card is charged.

The runner's pay starts from a $2 stop, plus $0.40 per extra mile and $0.15 per extra minute, then weight, waiting, and a bulky-item amount when those apply. That total is scaled to 60 percent. The customer total is that runner amount plus 15 percent. The simulated ledger keeps the difference. Merchandise is paid to the store and is not runner earnings.

A request with no runner origin uses a short preliminary estimate. The claimed price uses that runner's detour.

## Notes

Accounts, trips, orders, and messages stay on the phone. Home Run is a student project and is not an official university service.
