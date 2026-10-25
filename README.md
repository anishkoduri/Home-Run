# Home Run for iOS

Students post a drive to College Station, other students request a restaurant pickup, and the driver walks the order from requested to delivered. Accounts, trips, and orders stay on the phone.

## Run it

Open `HomeRun.xcodeproj` in Xcode and run the HomeRun scheme on an iPhone simulator or a phone.

Restaurant and address search uses Google Places when `GOOGLE_MAPS_API_KEY` is set in `HomeRun/Info.plist`. Enable Places API (New) and Routes API on that key. With the key empty, search uses OpenStreetMap and routing uses OSRM.

The delivery fee is `$8 + $0.50` per added minute, rounded up to `$0.50`. Home Run does not take payment.

Not affiliated with Texas A&M University.
