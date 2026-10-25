# Home Run demo progress

Marketplace checkpoint: customers post with Post pickup request and cannot address it to a runner or a trip. The server rejects a trip id on a new request. Discover trip rows are open drives only. Runners use Available requests, sorted Latest, Closest, or Recommended, and claim. Closest and the claim quote use approximate geographic distance and are labeled as not a driving route. A fee the customer has not already approved is a 15-minute offer. Requests already assigned to a runner stay on Deliveries. Text entry goes through `EntryField`. No Xcode console error was captured for the earlier tap failure. `LaunchSlide` follows the slide in `a5091dd` and also shows the mark on the first frame. Google Maps startup runs in `RootView.task`, not `App.init`. Live Google checks remain pending.

`xcodebuild test -only-testing:HomeRunTests` on scheme HomeRun, iPhone 17 `C7D34B0F-ABB5-4641-97C3-11DB5357DFE0`, derived data `/tmp/HomeRunDD`: TEST SUCCEEDED. That run includes `MarketplaceTests` (post without a runner, a trip id on a new request is rejected, one active claim, a second runner blocked, no self-claim, incremental distance is not the whole drive, Latest by timestamp then id, Closest by geographic distance, Recommended preferring the selected area) plus the existing journey, purchase, trip-edit, pricing, vision, and demo-rule tests.

`xcodebuild test -only-testing:HomeRunUITests` on the same destination: TEST SUCCEEDED. `LaunchSmokeTests` covers demo entry, the four customer tabs, Bring food and Get food, and scenario 1. `testTypingAPickupRequestAndATripNote` types a home-pickup description, leaves that form by tapping Orders, Discover, Home, and Profile, then types a trip note. It does not measure the system maroon launch interval, does not prove a road route, and does not prove live Google search, photos, maps, or routes.

Earlier product-vision notes: intentional city picker, sample sign-in, both roles, tab roots, pickup-limit wording, editorial discovery, a visible home pickup, the primary demo email, and Active / Past / My Faves. An earlier unit run failed `race.title.contains("last spot")` because scenario 7 is titled “The last pickup”; that expectation was updated before the succeeding runs.

## Where to paste the Maps SDK key

Paste it locally in `Config/Local.xcconfig`, on the `GOOGLE_MAPS_IOS_API_KEY` line, after the equals sign. No quotes. That file is listed in `.gitignore`. Do not paste the key into `HomeRun/Info.plist`, Swift source, or chat.

The HomeRun target loads `Config/Shared.xcconfig` for Debug and Release. That file includes `Local.xcconfig` when it exists and writes the values into the built Info.plist as `GOOGLE_MAPS_IOS_API_KEY`, `GOOGLE_PLACES_API_KEY`, `GOOGLE_ROUTES_API_KEY`, and the legacy `GOOGLE_MAPS_API_KEY`. `RootView.task` calls `GoogleMapsStartup.start()` after the first frame, then restores the session. `App.init` does not. A missing or blank key does not call the Maps SDK, and the existing Apple map stays.

`GoogleCredentials` never prints a key. Profile shows only “configured” or “missing” in Debug builds.

## What each Google call actually is

There is no backend and no Places SDK.

| Capability | Implementation | Key field | Cloud API restriction | Application restriction |
| --- | --- | --- | --- | --- |
| Map tiles | Maps SDK for iOS (`GoogleMaps`), `GMSServices.provideAPIKey` in `HomeRunApp.init`, `GoogleRouteMap` | `GOOGLE_MAPS_IOS_API_KEY` | Maps SDK for iOS | iOS apps, bundle ID `com.homerun.ios` |
| Restaurant search and place photos | Direct REST to Places API (New): `places.googleapis.com/v1/places:searchText` and `places.googleapis.com/v1/{photo}/media` in `HomeRun/Places.swift` | `GOOGLE_PLACES_API_KEY` | Places API (New) | iOS apps, same bundle ID. The app sends `X-Ios-Bundle-Identifier`. |
| Road distance and duration | Direct REST to Routes API: `routes.googleapis.com/directions/v2:computeRoutes` in `HomeRun/Places.swift` | `GOOGLE_ROUTES_API_KEY` | Routes API | iOS apps, same bundle ID, plus the same bundle header |

The Maps SDK key does not authorize Places or Routes. Leave those two lines blank until separate keys allow those APIs. Search then stays on the labeled sample catalog. Routing stays on OSRM. The legacy `GOOGLE_MAPS_API_KEY` still feeds all three if it is set, so an older single key keeps working. Do not put a Maps-SDK-only key in that legacy field.

## Requirement map

| Area | Status | Evidence |
| --- | --- | --- |
| Gitignored local keys, Maps SDK init, Places and Routes REST split | Implemented. Live in-app checks still pending | `Config/Shared.xcconfig`, `HomeRun/GoogleCredentials.swift`, `HomeRun/Places.swift` |
| Pickup city before search, sample catalog only when the Places key is absent | Implemented. In-app Google results are not marked passed | `HomeRun/DiscoverView.swift`, `HomeRun/PlacePhoto.swift` |
| Cents pricing, 60% of the runner's time and distance, then plus 15% (Home Run keeps the 15%), shared-stop discount defined and off, over 30 extra minutes reviews | Implemented and unit-tested | `HomeRun/PricingPolicy.swift`, `HomeRunTests/` |
| Demo people, including Taylor Brooks in demo tools only, clock, Houston/Dallas/Austin trips, detour and weight limits | Implemented in the on-device store | `HomeRun/Store.swift` |
| Quote, submit, accept, PIN, messages, simulated share | Store journey test passed. Not tapped in the simulator | `HomeRunTests/JourneyTests.swift` |
| Counteroffer, decline reason, quote expiry, cancellation release/refund, append-only ledger, support refund, payout | Rules unit-tested. Journey test covers capture, one earning, and a failed second accept | `HomeRun/DemoRules.swift`, `HomeRun/Store.swift` |
| Multi-item lines, trip publish/draft/close/reopen/start/complete, arrival code, unread bell count | Implemented. Journey test checks item name, quantity, draft privacy, arrival PIN hidden from the runner, and unread messages | Discover request sheet, `DriveView`, `HomeView` |
| Own published trip visible, labeled “Your trip,” and not requestable by its owner | Journey test rejects the owner’s request. Another customer’s request reaches only that runner, newest first | `DiscoverView`, `Store.createOrder` |
| Saved requests, pause/delete, one match notice, inbox, delay notice | Implemented. Unverified in the simulator | `HomeRun/DemoScreens.swift` |
| Terms version demo-1, unchecked accept, FAQ, forgot-password copy | Terms screen confirmed by simulator screenshot. Accept tap was not available | `HomeRun/DemoScreens.swift`, `/tmp/homerun-shots/launch-terms.png` |
| Recurrence weekly and every other week, demo clock steps, confirmed reset, publish matching trip | Implemented. Unverified in the simulator | Profile → Demo controls, My trips |
| Extra Texas cities beyond Houston, plus a lookup for a city that is not in the starter list | Starter list expanded. Lookup code calls Nominatim. Not exercised live | `HomeRun/Logic.swift`, `HomeRun/Places.swift` |
| Historical delivered and cancelled demo records | Added when those ids are missing. Not inspected in the UI | `AppDatabase` init |
| Ten presenter scenarios and a five-minute walkthrough | Preparation is implemented and store-tested. The walkthrough itself was not performed | `docs/DEMO-SCENARIOS.md`, Demo controls |
| Photo gallery paging and attribution, saved-place bookmark and list, trip notes and capacity edit, demo deletion while a pickup is active, notification preference, receipt from the ledger | Implemented in the app. Bookmark toggle, capacity note, reset clearing saved places, and a muted notification are store-tested. Gallery paging was not tapped | `PlaceGallery`, `DiscoverView`, `SavedPlacesView`, `DriveView` edit sheet, `OrderDetailView`, `ProfileView`, `Store.swift` |
| Discover filters Apply/Reset/Clear all, pull to refresh, empty-trip Save a request, personal-item label, meetup directions, earnings period, recurrence date preview, skip a generated date, Order again opening Discover | Implemented. Not tapped | `DiscoverView`, `OrderDetailView`, `DriveView`, `HomeRunApp` |
| Editing or reordering stops after a trip is published, one-occurrence edit beyond skip, UI automation of every control | Stops can be added, reordered, and removed after publication. A stop tied to an accepted pickup cannot be removed. Unaccepted quotes expire and their authorization is released. An edited generated date stays separate from the series, and generating again does not duplicate it. | `Store.applyTripEdits`, `TripEditor`, `HomeRunTests/TripEditTests.swift` |
| Presenter scenario buttons | All ten scenarios have a Demo controls action. Each resets fictional records and leaves shared trips or orders for the normal screens. The store test calls all ten. None of the ten was tapped through in the simulator. | `DemoControlView`, `Store.prepareScenario`, `docs/DEMO-SCENARIOS.md` |
| XCUITest target | HomeRunUITests launched on the iPhone 17 simulator through `xcodebuild test` without Computer Use. The test accepts demo terms when they are shown, confirms Home, Discover, Orders, and Profile, opens Demo controls, and checks that scenario 1 prepares the Houston dinner instructions. It does not tap the ten order journeys. | `HomeRunUITests/LaunchSmokeTests.swift`. TEST SUCCEEDED on 2026-10-25. |

## Live checks

These stay pending. A build, a unit test, a REST smoke call, or a fixture is not a pass.

- Google map renders in the app: pending
- Pickup-city selection across Texas, exercised in the running app: pending
- Restaurant/store search returns real results for the selected city, on the Discover screen: pending
- Available Google photos load in the app with attribution: pending
- Route calculations from the configured Routes key, shown on a trip: pending
- Connected order flow tapped through in the simulator, payments simulated: pending

The earlier simulator launch showed the terms gate. That gate is no longer the entry. This correction pass has not yet recorded a new screenshot. This machine has no Simulator.app, and Computer Use was previously refused for Accessibility and Screen Recording. `xcodebuild` can still drive the simulator. Live Google checks stay pending.

`HomeRunUITests` taps Explore the demo when that button is on screen, then confirms the customer tabs, Bring food, Get food, and scenario 1. It no longer requires the terms gate. The result is in the opening section. That UI test does not walk the ten order journeys.

## Journey now in the app

A returning session is restored. A signed-out launch shows Log in, Create account, and Explore the demo. Explore the demo signs in as Anish Koduri (`demo-maya`, `anishkoduri@tamu.edu`, password `demo`) on this phone and does not send email. Create account asks for an unchecked terms agreement. Bring food and Get food are available on every account. Profile → Demo people switches actors without deleting orders. Account 1 is not removed by demo reset.

Jordan, Avery, and Sam have the scheduled trips, plus a Houston draft, a completed Houston history trip with a delivered $8 order and a $6.40 earning, and a cancelled history trip whose authorization was released. San Antonio still has no trip until Demo controls publishes one. The pickup-city list also includes El Paso, Lubbock, Amarillo, Corpus Christi, Laredo, Midland, Beaumont, Tyler, Abilene, Plano, Arlington, Round Rock, and Galveston. A typed city that is not in that list can be looked up.

A new request is either Restaurant or store or Home or personal item. Home or personal item is on Home and on Discover, without choosing a restaurant first. Both share one Pickup details description. The customer pays the merchant; Home Run's simulated ledger is the delivery fee only. After the runner accepts, the customer adds confirmation and the runner reviews it before pickup. Older delivered history stays marked runner purchase and keeps its merchandise reimbursement. The store recomputes the delivery quote from the route and weight. A straight-line estimate stays unpriced. The runner can publish, save a draft, close and reopen requests, start, and complete a trip. Edit trip covers the driving city, departure, cutoff, arrival estimate, pickup limit, extra minutes and miles, item and total weight, custom items, notes, and planned stops. Stops can be added, moved, and removed. An accepted pickup keeps its stop, time, and limits. A generated date is edited on its own and is not duplicated when the series is generated again. Destination stays College Station. Delivery now has an Arriving step, and the code appears only for the customer. Decline requires a reason. A counteroffer from $1 to $250 waits for the customer. Cancel before pickup releases or refunds. After pickup the customer gets help instead. Taylor Brooks can refund a delivered order without changing it from delivered. Earnings can simulate a payout and filter this week or all time. Saved requests can be paused or deleted. Saved places toggle from a result and list under Profile and under Orders → My Faves. A place photo opens a paged gallery. The bell badge counts unread notices and messages. Demo reset also clears demo saved places. Reset still leaves Account 1 alone. Recommended browsing reorders a real Trader Joe’s branch and, in Houston, Aga’s Restaurant & Catering when those businesses are already in the results. A typed search keeps the result order.

The simulator showed the terms gate. The rest of the screens were not tapped. This Mac has no Simulator.app, and Computer Use was previously refused for Accessibility and Screen Recording.

## Exact next task

Accept the demo terms in the running app and walk one prepared scenario on the normal screens. Demo controls has a button for each of the ten scenarios. Those buttons prepare records. They do not perform the scenario. Then run the in-app Google checks listed above. Do not mark those checks passed from this document.

Live Google checks and a tapped walkthrough remain externally blocked on this machine: there is no Simulator.app, and Computer Use was refused for Accessibility and Screen Recording. `xcodebuild test` can still launch the simulator. The UI test target is HomeRunUITests. A full control-by-control UI inventory was not automated.

## Manual walkthrough

Preparation and performance are separate. Profile → Demo controls → the numbered scenario resets fictional demo data and shows the steps. Then use the normal tabs.

1. Houston dinner. Anish, Bayou Bowl Kitchen, Pickup details, Campus Library Plaza, $8 delivery fee. Jordan accepts. Anish adds store confirmation. Jordan reviews it, then completes the code. Earnings $6.40. No merchandise charge.
2. Worth the detour. Dallas, labeled 6 miles and 12 minutes. The runner earns the extra time and distance; the customer pays that plus 15%. Avery completes it.
3. A little heavier. Austin, Sam's trip. 35 lb is the runner amount plus 15%. Unknown or over 50 lb stays in review. An $18 counteroffer needs Anish's approval. The runner keeps the amount before the 15%.
4. One stop, two orders. Anish and Alex both request Bayou Bowl. Separate orders and codes. The $2 shared-stop discount stays off.
5. Catch the next trip. San Antonio has no trip. Save a request, publish a matching trip, see one notice, and do not get a charge.
6. Plans change. Jordan cancels the Houston trip. Anish's accepted order is refunded.
7. The last pickup. Jordan accepts one of the two waiting requests. The second accept fails and is not captured.
8. Make it right. Anish opens the delivered order and gets help. Taylor resolves without a refund, then simulates a full refund. The order stays delivered.
9. Welcome, Aggie. Create account shows unchecked terms, version demo-1. Explore the demo does not repeat that gate. Bring food and Get food switch sides. Relaunch keeps the session.
10. Offline. Discover shows the labeled sample catalog. A request stays in price review. Reset restores the baseline.

The five-minute talk is still the one at the top of `docs/DEMO-SCENARIOS.md`. It has not been performed.
