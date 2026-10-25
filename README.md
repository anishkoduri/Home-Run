# Home Run for iOS

Students post a drive to College Station, other students request a restaurant pickup, and the driver walks the order from requested to delivered. Accounts, trips, and orders stay on the phone.

## Run it

Open `HomeRun.xcodeproj` in Xcode and run the HomeRun scheme on an iPhone simulator or a phone.

Google keys go in `Config/Local.xcconfig`, which Git ignores. See `Config/Local.xcconfig.example`. The Maps SDK key, the Places API (New) key, and the Routes API key are separate. With Places unset, search uses the labeled sample catalog. With Routes unset, routing uses OSRM. Map tiles use Apple Maps until the Maps SDK key is present.

The delivery fee is a simulated quote. A short detour with a light confirmed item is $8, and the runner's simulated share is 80 percent. Home Run does not take payment.

Not affiliated with Texas A&M University.
