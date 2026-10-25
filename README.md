# Home Run for iOS

SwiftUI client for the [Home Run](https://github.com/aaronjac2020/howdy-haul) server. Students post a drive to College Station, other students request a restaurant pickup, and the driver walks the order from requested to delivered.

This app does not keep its own database. It signs in to the Home Run server (`/api/store` for accounts, trips, and orders, `/api/geo` for restaurant search and detours).

## Run it

You need a Mac with Xcode 16 or newer. This project cannot be compiled on Windows.

1. Start the Home Run server on that Mac (`npm run dev` in the web repo). It listens at `http://127.0.0.1:5173`.
2. Open `HomeRun.xcodeproj` and run the HomeRun scheme on an iPhone simulator.
3. The simulator shares the Mac's localhost, so leave the server address as `http://127.0.0.1:5173`.

On a physical iPhone, set the server address to the Mac's LAN URL. The phone cannot reach `127.0.0.1` on the computer. The web dev server is bound to localhost unless you start it so other devices can connect.

The delivery fee is still `$8 + $0.50` per added minute, rounded up to `$0.50`. Home Run does not take payment.

Not affiliated with Texas A&M University.
