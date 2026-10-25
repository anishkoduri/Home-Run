# Home Run — complete Cursor demo implementation prompt (revised: discovery restoration and full interaction map)

Priority correction: restore the missing pickup-city selector, working restaurant/store results, and Google place photos. A fixture-only implementation is not a fix for the existing Google integration. Read section 8A and the interaction contract before implementing.

Continue the EXISTING native iOS app at https://github.com/anishkoduri/Home-Run. Implement a complete, connected demonstration of its student-to-student intercity pickup marketplace. This is ONE complete prompt. No second part is coming. These instructions supersede conflicts in earlier master prompts, particularly live payments, production deployment, web-stack assumptions, and waiting for Part 2.

## 1. Mission, boundaries, execution

Home Run connects College Station customers with students already driving back from other cities who can bring food, groceries, packaged goods, and forgotten belongings. Optimize existing journeys, not instant courier dispatch. Availability and earnings are never guaranteed.

Use the exact slogan **“By Aggies, for Aggies.”** beneath the brand during onboarding and in About. Keep Home Run as the product name. Do not claim official university affiliation or verified enrollment. Preserve the existing logo and app icon artwork completely unchanged.

This is a DEMO, not a launch-ready financial platform. Core workflows must operate end to end, persist across relaunch, and be resettable. Disconnected UI mocks and buttons that only change their own label do not satisfy implementation.

Proceed through audit, implementation, integration, and validation without routine phase approvals. Do not stop at recommendations. Preserve uncommitted work and current architecture. Local code, tests, fixture assets, documentation, and additive migration files are authorized. Do not commit, push, deploy, contact real recipients, buy goods, move real money, alter external permissions, or execute remote database migrations. Avoid new dependencies; request approval if an essential one is needed.

Complete independent work when credentials/tools are unavailable and report unrun checks accurately. Do not claim an invented completion percentage.

## 2. Audit and architectural continuity

Read repository instructions. Inspect actual app entry points, Xcode targets, Swift version, deployment target, architecture, storage, authentication, Google integration, any Supabase backend/schema, navigation, design system, assets, and tests. Do not assume the original website's TypeScript/backend exists in this extracted iOS repository.

Create a requirement-to-file map using real paths: reusable, partial, missing, blocked. Follow existing patterns instead of imposing a new architecture, database, or authentication system. Reconcile changed models with persisted data.

Maintain a progress document with decisions, finished work, exact remaining tasks, failures, and validation commands so another Cursor session can continue reliably.

## 3. Demo environment and provider rules

Demo must start without Stripe, bank accounts, APNs, Google credentials, paid product metadata, email/SMS, identity verification, or other security-service integrations.

- Use existing environment configuration to isolate demo from real sessions, storage, identifiers, and provider calls. Never silently switch a real session into demo on error.
- One persistent demo store owns users, trips, stops, items, quotes, orders, messages, notifications, support, and simulated financial records. Customer and runner screens read the SAME linked records, not view-specific arrays.
- Show “Demo • sample data • no real charges” on entry and Settings, with compact indicators on transactional/earnings/simulated-tracking views. Avoid long repetitive disclaimers.
- Default demo providers never contact merchants, process money, upload private information, send external messages, or request background location.
- Restore and verify the existing Google discovery/photo integration, preserving its configuration and callbacks. With valid configured access, use real Places search/photos by default for discovery while payments remain simulated. Keep an explicit offline sample mode for no-credential presentation. A named “Google discovery + demo transactions” mode may combine real place browsing with simulated users/orders, but must label simulated trips/transactions, preserve place provenance, and never imply a real merchant partnership or fulfilled purchase. Real route measurements require configured routing; otherwise use manual review or explicitly labeled demonstrator-supplied measurements, not fictional live quotes.
- Do not seed production. Optional multi-device sync requires an explicitly selected development environment with existing ownership controls. Single-device persona switching must work without it.
- Reuse current repository/service boundaries. Introduce only necessary provider seams, not speculative frameworks.
- Keep existing authentication, authorization, RLS, secret protection, and secure storage. Excluding security integrations means no new KYC/ID/biometrics/fraud vendor, not disabling basic access controls.
- No real card/bank forms, payouts, hosted financial onboarding, webhook setup, or payment credentials. Existing live integrations remain inactive in demo.

Do not turn off functioning Google calls merely because payment mode is simulated. Content provider and transaction provider are separate capabilities. Only call read-only configured Google services; do not alter Cloud billing, keys, quotas, or permissions. If access is missing, document the exact configuration blocker and keep the explicit offline mode usable.

Service status and missing API keys belong in developer settings, not customer copy. Preserve required provider/photo attribution.

## 4. Shared code and UI foundations

Centralize semantic colors, actual registered font families and text roles, spacing, textures/materials, illustrated line weights, button treatments, and motion in the existing theme. Centralize shared copy/status labels and currency/date/unit formatting.

Reuse headers, buttons, fields, trip cards, quote breakdowns, timelines, sheets, and loading/empty/error/success states. Customer and runner screens must not independently implement the same business rules or theme constants.

One domain policy each handles pricing, order transitions, trip/capacity changes, and simulated payments. Separate internal status from user-facing wording. Views render state and dispatch commands; they do not calculate authoritative fees or mutate private mock datasets.

Use stable IDs, consistent relationships, serialized/transactional mutations appropriate to the existing architecture, and persistent drafts. Keep networking/heavy work outside view rendering. Document where future font/color/material/control changes propagate app-wide.

## 5. Demo control center and time

Provide a Demo Control Center through Settings and demo entry:
- Switch fictional actor and customer/runner mode without resetting data.
- Load named scenarios/reset local demo after confirmation describing the data being replaced.
- Advance the injected clock by 5 minutes, 15 minutes, or 1 day.
- Trigger next valid delivery step, delay, matching-trip publication, and controlled failure through normal domain commands.
- Inspect integration mode and sanitized event history.

Actor switching preserves data. Replacing a scenario requires confirmation. Reset never touches real data.

Seed departures relative to the demo day. Inject clock/IDs/randomness. Store absolute timestamps and display trip times in America/Chicago. Cutoffs, expiration, recurrence, and notifications use the same clock. Do not wait real minutes to demo expiry.

Persist selected scenario, clock, and edits across relaunch. Version seed/schema and implement recovery/migration. Do not silently erase data after decoding failure. Stable seed IDs and deterministic scenarios support reproducible tests.

## 6. Complete fictional seed content

Create explicitly fictional demo users/businesses, initials or licensed avatar art, bundled licensed images, and source=DEMO provenance. No real private contacts, invented ratings, verified badges, real merchant availability, or unsupported merchandise prices.

Dual-role personas:
- Maya Chen: primary customer; preferred “Campus Library Plaza — demo location.”
- Jordan Ellis: Houston runner, 4 slots, 50 lb total capacity, 50 lb/item maximum, 30-minute/15-mile detour limits.
- Avery Patel: Dallas runner, 3 slots, 60 lb total, 50 lb/item, 20-minute/15-mile limits.
- Sam Rivera: Austin runner, custom requests enabled, 2 slots, 75 lb total, 60 lb/item, 45-minute/25-mile limits.
- Alex Morgan: secondary customer for shared-stop/capacity scenarios.
- Taylor Brooks: support actor selectable ONLY in demo tools; selecting them must never grant real account privileges.

Each gets a short bio, home city, preferences, and linked history. One account can use both roles.

Fictional places:
- Houston: Bayou Bowl Kitchen, Bayou Market, Bayou Coffee Counter.
- Dallas: North Loop Pantry, North Loop Sandwich Co., North Loop Supply.
- Austin: Cedar Trail Market, Cedar Trail Kitchen, Cedar Trail Goods.
- San Antonio: Mission Table, Mission Pantry.
- College Station: Campus Library Plaza and Student Center East Entrance, explicitly fictional demo meetups.

Each place has stable ID, city, category, sample address label, plausible illustrative coordinates, bundled image/illustration, accessibility description, and source/license metadata. Coordinates do not establish real business presence or road distance. Sample hours, if included, must be labeled sample. No private home addresses.

Fixture items: rice bowl, sandwich box, snack bundle, sealed groceries, a 24-bottle water case (28 lb total), boxed household item (35 lb), bulky chair (20 lb), forgotten backpack (8 lb), and one unknown-weight custom item. Provide quantities, descriptions, packing notes, sample merchant references, weight/dimensions where known, confidence/source, and confirmation. Quantity changes total weight. Light items have explicit fixture/customer-confirmed weights rather than zero assumptions.

Photos are illustrative, not integrated menus. Bundle essential assets so network loss does not empty the interface. Record licenses/sources. Do not scrape Google Images. If suitable images cannot be obtained, use intentional local illustrations, report the asset limitation, and never claim nonexistent photos were included.

Baseline trips (times America/Chicago):
- Jordan: Houston → College Station tomorrow 16:00–18:00, cutoff 15:00, Bayou Bowl Kitchen stop, 4 slots.
- Avery: Dallas → College Station tomorrow 13:00–16:00, cutoff 12:00, North Loop Pantry stop, 3 slots.
- Sam: Austin → College Station in 2 days 15:00–17:00, cutoff 14:00, Cedar Trail Market stop, 2 slots.
- Another Houston published trip in 4 days for date filtering.
- Driver-only draft; completed historical trip with delivered orders/earnings; cancelled historical trip with resolved cancellations/refunds.
- No published San Antonio trip initially.
- Weekly Houston recurrence template initially disabled.

Provide linked pending, accepted, manual-review, counteroffer, delivered, and cancelled examples in scenario datasets. Derive remaining capacity, earnings, unread counts, and history from records. The main baseline is populated but leaves capacity for new requests.

Seed useful short messages: “The order is under Maya. Pickup reference HR-DEMO-104.” / “Got it. I’ll message when I leave the stop.” / “Traffic added about 10 minutes. I’ve updated the arrival window.” Scripted replies/delays occur only through explicit demo actions, never fake human activity.

## 7. Accounts, legal drafts, settings, voice

“Explore demo” selects a persona without collecting real passwords. Preserve functioning real signup/login/reset/session behavior separately. Simulated reset says no email was sent.

Implement profile/avatar editing, preferred meetup, saved cities/places, notification preferences, histories, logout, and demo account-deletion requests. Financial settings expose simulation, no real inputs. Deleting a demo account is blocked while it has active commitments; instruct the user to resolve them, then remove/anonymize only demo profile data while preserving required linked demo history. Do not touch real accounts.

Terms acceptance starts unchecked, documents open, and actor/document versions/trusted demo timestamp persist. All fresh demo onboarding paths enforce it; updated required versions gate transactions until reaccepted. This is demo acceptance, not production server enforcement.

Write usable bundled Terms/Privacy drafts and FAQ, not lorem ipsum. Terms/Privacy cover account accuracy, marketplace nature/no availability guarantee, participant responsibilities, prohibited unsafe/unlawful goods/no unsupported age-restricted flow, delays, separate merchant purchases, simulated fees/refunds/support, local demo storage, optional configured provider transmission, and user requests. Mark drafts for legal review before launch. Do not invent a company, support email, university endorsement, retention promise, or unimplemented privacy practice. Link to in-app help/support.

FAQ answers: how existing-trip pickups work; delivery versus merchant payment; availability; meetup selection; cancellations; delays; confirmation PIN; simulated money/tracking. Keep financial/safety/legal disclaimers honest and compact.

Use “By Aggies, for Aggies.” on onboarding/About. Wording is consistent, engaging, friendly, semi-professional, and concise—no forced slang, repetitive baseball puns, filler testimonials, or API-key explanations. Keep trip/pickup/order/request/delivery terms consistent without collapsing distinct concepts.

## 8. Customer workflow

The primary ordering path is Home/new order → choose pickup city → search restaurant/store → place details → choose compatible trip → items/instructions → meetup/window → quote → review → submit → tracking/messages → completion/history. Also retain trip-first entry: city → trip → planned stop/place search → same order draft. Both paths converge on one shared flow.

- Data-driven cities; seeded cities are not an exhaustive enum.
- Filter city/date/arrival window/merchant/planned stop/detour/custom support; show active filters and clear action.
- Cards show driver, route, departure/arrival, real remaining capacity, cutoff/stops/detour support. “Delivery from $8” only when eligible; final fee requires a quote.
- Place search visibly uses the selected pickup city and active content provider: Google when configured, bundled sample catalog in explicit offline mode. No results offers a custom location with confirmation/manual routing review. Do not confuse pickup city with delivery destination.
- Place availability is separate from compatible trip availability; offer saved requests when none exist.
- Prevent own-trip, completed/cancelled/full/past-cutoff orders and invalid delivery windows.
- Collect items/positive quantities, descriptions, confirmed/unknown weight, bulky/fragile flags, pickup notes/reference, meetup/window. Internal actor/driver/trip IDs derive from session/selection, not form entry.
- Methods: “I order and pay the store separately” or “Personal item pickup.” No driver-fronted purchases, real merchant checkout, or invented merchandise charges. Show merchandise “Paid to the store separately.”
- Preserve drafts after failure/expiry/back navigation. Confirming creates ONE persisted request visible to the runner; success links to that order.

Saved requests: city, optional place, desired window, preferred maximum fee. Newly published compatible trip generates one in-app match, not booking/payment. Match city/window and specified place/planned stop. Claim within-budget only with valid measurement-backed pricing; otherwise “Price needs review.”

## 8A. Critical functionality restoration: city, Google search, Google images

These are explicit regression fixes, not optional future integrations. Inspect what exists, trace the complete broken path, and repair root causes before adding unrelated features. Do not claim the Google issue is fixed because sample businesses render.

### Pickup-city contract

Every order entry point must provide a visible pickup-city selector BEFORE restaurant/store search. No hidden Houston default. Show “Pickup city” and the selected city, with “Delivering to College Station” as a separate destination context.

- On first use require explicit selection or confirmation of a saved preferred city. Persist the preference without silently locking later orders to it.
- City selector offers Houston, Dallas, Austin, San Antonio and searchable additional Texas cities; resolve city/locality identifiers, state/country and coordinates/bounds. Do not treat a city substring as a safe geographic identity.
- A selected trip prepopulates its origin city, visibly editable through a change action. City changes invalidate incompatible place/trip/route/quote selections and release any unsubmitted draft reservation. Preserve reusable item notes and explain what needs reselection.
- Keep selected city visible in search/results/place/trip/review screens. Distinguish it from final meetup address and destination city.
- Shared draft state owns pickup city, place ID/source, selected trip, item lines, notes, meetup, quote and provenance. Views must not copy these into divergent state.

### Search implementation audit and repair

Inspect the configured Places SDK versus REST API version; follow that version's current official documentation. Preserve working SDK/auth paths and avoid arbitrary API migrations. Trace UI binding → debounced query → selected-city context → provider request → HTTP/SDK response → decoding → UI publication → list selection.

Check actual causes including target configuration/Info.plist or runtime config loading, API enablement/billing restrictions, correct client-versus-server key restrictions, field masks, requested data, response decoding, cancellation, main-actor state publication, and filtering that accidentally removes every result. Never print keys, remove key restrictions, enable billing, or change external account settings automatically. Reuse the intended SDK or trusted server boundary; never embed a server secret to make a request work.

Search behaviors:
- Opening a chosen city's Discover page loads suitable restaurant/store discovery results rather than an empty search-only screen when provider supports it. Offline mode loads that city's samples.
- Search supports business names and categories, e.g. “tacos,” “groceries,” “coffee.” Use explicit city/state context and appropriate geographic constraints supported by the selected endpoint. A location bias alone is not a strict city filter; handle out-of-area results honestly and never present another city's business as local.
- Category chips (“All,” “Food,” “Groceries,” “Stores”) map to supported provider categories/queries, update selection, and trigger correct results.
- Debounce typing around 300 ms, allow immediate keyboard/button submit, cancel superseded calls, and ignore late responses from old query/city/provider.
- Preserve drafts/result position when returning from place details. Clear search clears query and restores city discovery. Changing filters resets pagination. “Load more” or scrolling uses valid pagination without duplicates when supported.
- Each result has stable provider/place ID, name, address/city, category, photo status, and any genuinely available hours/rating. Do not fabricate missing fields. Ratings are optional; label no invented review counts.
- Return distinct states: initial, loading, results, successful zero results, offline, timeout, permission/configuration/API failure. Errors must not masquerade as “No restaurants.” Customer gets concise retry/change-city choices; diagnostics hold sanitized status/error codes.
- Searches should not require precise device location when the user selected a pickup city. Permission denial must not block city-based discovery.

### Photo pipeline

Google search data is not automatically image data. Request supported photo metadata, map it to the correct place, and resolve/load actual photo bytes using the appropriate SDK or Place Photos endpoint.

For Places API (New) REST, inspect photo resource names returned by Details/Search, request correct media endpoint and required size, and handle documented redirect/URI behavior. Do not pass a resource name directly to an image view as if it were a public image URL, or mix legacy photo references with New resource names. If the app uses the native SDK, use its corresponding photo-loading APIs instead.

Show real Google place photos in result cards and detail galleries whenever available. Size requests for display/density, load asynchronously, cancel offscreen tasks, and keep scrolling smooth. Use stable image identity so cell reuse cannot show the previous restaurant's photo. Deduplicate concurrent requests where practical. Retry transient failures with limits; refresh expired metadata through documented mechanisms.

Separate missing photo, loading, and failed load. Use a tasteful branded fallback for no photo, not the same unrelated stock meal presented as every business's real photo. Photos may show storefront/interior/food; do not label them menu-item pictures without evidence.

Follow current attribution, permitted storage/caching, expiration, and display rules. Do not permanently bundle Google photos or persist their resource names as durable licensed assets. Keep offline licensed illustrations/photos separate. Display required Google and author attribution. Place data shown on maps must use the map/display arrangement allowed by the provider; do not automatically put Google Places content on an incompatible map.

Verify live search and photo loading with a configured read-only smoke check if permitted access exists. Otherwise finish code/tests and report LIVE GOOGLE SEARCH/PHOTOS UNVERIFIED or BLOCKED plus exact missing configuration. Mock tests alone do not establish a functioning integration.

Official references, select platform/API version matching the repository:
- https://developers.google.com/maps/documentation/places/web-service/text-search
- https://developers.google.com/maps/documentation/places/web-service/place-photos
- https://developers.google.com/maps/documentation/places/web-service/policies

### Food-ordering boundary

Offer familiar delivery-app browsing and review mechanics, but keep Home Run's actual marketplace model. Google Places does not supply guaranteed menus, merchandise inventory, checkout, or purchases. A result tap opens place details, then “Find a trip”/“Request a pickup,” not an invented merchant menu.

Customers enter their own item list and confirm they arrange/pay merchant purchases separately. External merchant website opens only a provider-returned valid URL after user action. Do not submit purchases. Fictional offline sample items remain labeled sample; no fake real-restaurant menu prices.

### Acceptance gate for these regressions

Do not consider discovery restored unless the ordering entry has a working city selector; selecting/changing city updates queries/results; restaurant/store names populate; tapping a result passes the correct place to the draft; available photos load on the correct cards/details; missing photos/errors have fallbacks; and both city-first and trip-first order paths remain functional. Demonstrate each with screenshots/logs/tests appropriate to available tooling and state what was not live-tested.

## 9. Trips and runner requests

Implement create/edit/publish, planned stops, preferences, inbox/accept/decline/counteroffer, deliveries, history, and simulated earnings.

Fields: origin/destination (College Station default), departure/ETA/cutoff, stop IDs/name/location/timing/type/availability, max extra miles/minutes, order slots, total/item weight limits, custom permission, notes, recurrence.

Trip sequence: DRAFT → PUBLISHED → ACCEPTING_REQUESTS → REQUESTS_CLOSED → IN_PROGRESS → COMPLETED; CANCELLED terminal before completion. Publish/open can be one atomic command recording both events. Reopen only while eligible before departure/cutoff. Complete only after all active orders are delivered or explicitly resolved. Closing requests does not cancel commitments.

Validate arrival after departure, cutoff before departure, positive capacities/nonnegative limits. Prevent edits that silently invalidate accepted route/window/capacity commitments. Pending requests/counteroffers do not reserve capacity. Acceptance atomically reserves slots/confirmed weight; cancellation releases once. Unknown weight must be agreed before acceptance.

Requests show pickup/meetup/items, timing, extra driving, handling, fee/share. No auto-accept. Decline requires a short reason and notifies customer.

Custom/manual-review counteroffers: positive integer cents within centralized demo range $1–$250, reason, expiry min(now+15 minutes, cutoff), explicit customer approval, previous quote retained. Customer acceptance rechecks eligibility/capacity/route and commits approved fee. Hard limits cannot be bypassed by offering more money.

Weekly/every-other-week recurrence: preview next 28 days, generate drafts, publish selected occurrences. Unique template+local occurrence prevents duplicates. Skip/edit safely without breaking accepted instances. Keep local departure time across timezone offsets; ambiguous/nonexistent times need an explicit selection/validation response.

## 10. Exact pricing policy

One centralized policy uses USD integer cents, Decimal/rational measurement conversion, half-up rounding PER fee component at the end. 1609.344 meters/mile; 60 seconds/minute. Store meters/seconds.

Defaults:
- Base 800 cents.
- Standard route tolerance ≤1 extra mile AND ≤5 extra minutes.
- Beyond EITHER tolerance: add ALL extra miles ×75 cents plus ALL extra minutes ×25 cents, not merely excess above tolerance.
- Weight ≤10 lb: 0; >10–25: 300; >25–50: 700; >50: manual review.
- Waiting first 5 minutes included, additional agreed minutes ×25 cents.
- Bulky 1000 cents.
- >30 extra driving minutes needs explicit review, still respecting hard trip limits.
- Quote validity 15 demo minutes.
- Runner share 8000 basis points (80%).
- Shared-stop discount 200 cents, implemented but OFF by default.
- Persist pricing version.

Resolve ambiguity: within BOTH route tolerances, route fee stays $8 even for heavy/bulky items; add confirmed handling fees separately. Weight alone must not trigger mileage/time charges. One pickup location per order, multiple items allowed; multiple orders per trip.

Unknown weight requires confirmation/review, never zero assumption. Item/trip limits remain hard. Enabled shared discount applies only to newly eligible quotes, must keep fee nonnegative and modeled contribution nonnegative, and never reduces accepted compensation retroactively.

Quote snapshots: owner/trip/pickup/meetup, pricing/route versions, tier, measurements/provenance, itemized fees, total/share, created/expiry/status. States: CALCULATING, QUOTED, MANUAL_REVIEW_REQUIRED, DRIVER_APPROVAL_PENDING, CUSTOMER_APPROVAL_PENDING, ACCEPTED, REJECTED, EXPIRED, SUPERSEDED; define allowed transitions centrally.

Manual-review submissions create an unpriced request with no simulated authorization or capture. After an explicit price proposal and customer approval, the normal eligibility/capacity checks and simulated payment rules apply. Never display an unknown fee as $0.

Submitting consumes a valid quote into a fixed-price request with response deadline min(submission+15 minutes, cutoff). Pending expiry releases authorization/notifies. Accepted orders do not expire with their old quote. Stale-route submissions must revalidate/reprice with explicit reconfirmation. Never increase an accepted fee silently. Revised counteroffer acceptance commits only approved amounts.

Required examples:
- Ordinary 0 miles/0 minutes: $8; runner $6.40.
- Exactly 1 mile/5 minutes: $8.
- 6 miles/12 minutes: $15.50; runner $12.40.
- 35 lb, standard route: $15; runner $12.
- 20 lb bulky chair, standard route: $21; runner $16.80.
- 10 minutes total agreed waiting, standard/light: $9.25; runner $7.40.
- >50 lb/unconfirmed weight: manual review, no automatic final quote.

Extra actual waiting after acceptance creates a proposed revision, never automatic charge. No tips/coupons/taxes/hidden fees in this pass. Local demo domain service is authoritative for simulation; real backend mode must validate prices/permissions/transitions server-side, not trust the client.

## 11. Routes, shared stops, product estimates

Baseline includes committed planned stops, accepted pickups, and meetups. Proposed insertion includes BOTH pickup and meetup impact, preserves pickup-before-delivery/windows/commitments, respects limits, and clamps each negative delta to zero. Charge incremental impact, never the entire intercity journey.

Offline road fixtures provide specific baseline/proposed measurements, including +6 miles/+12 minutes. Label sample. Coordinates and straight-line distance are not road measurements. Unknown combinations require manual review or explicitly selected labeled fixture measurements through demo controls. Real provider failure offers retry/review, never fabricated flat pricing.

Compatible same-place/same-window pickups reuse stops but keep separate order histories and PINs. A second committed shared stop adds zero route impact only if meetup adds none. Keep prior accepted fees; no retroactive splitting. Removing one order must not delete a still-needed shared stop.

Use bundled product metadata/customer measurements by default. Track weight/dimensions/source/confidence/quantity/bulky/fragile/confirmation. Unknown measurements enter review. No paid product API or AI-invented verified dimensions required.

## 12. Fulfillment, tracking, PIN

Separate fulfillment, financial, and support states so delivered orders can be refunded/disputed without erasing delivery history.

Fulfillment: REQUESTED → DRIVER_ACCEPTED → MERCHANT_CONFIRMED → PICKED_UP → EN_ROUTE → ARRIVING → DELIVERED; personal items use “Pickup arranged” semantics. Explicit REJECTED/CANCELLED/FAILED outcomes. Map existing persisted representations compatibly.

Only assigned runners accept/decline/advance runner steps. Participants can view their own records/messages; authorized support access is explicit. Require pickup/reference confirmation when applicable. Starting a trip never marks uncollected orders picked up.

Normal delivery steps obey trip/arrival timing. A labeled demo “Next step” command may explicitly advance the injected clock to the next prerequisite, but must not bypass domain transitions or invent real elapsed travel.

Generate per-order one-use customer-side PIN. Runner enters it from ARRIVING. Inject generator in tests, limit failures, avoid scenario duplicates, invalidate on success, make repeat command safe. Never expose code on runner views/logs. This demonstrates controls, not production security certification.

Tracking shows linked locations, ETA, notes, delay, timestamped steps, and confirmation. Route progress is labeled simulated and explicitly advanced within fixture route. No claim of GPS tracking/background location.

## 13. Messages, notifications

Persist order conversations, participant access, timestamps, unread/read state, failed-send/retry, no mandatory phone exchange. Sample scripted replies require explicit demo actions.

In-app inbox notifications: request, accept/decline, counteroffer, pickup, delay, arrival, delivery, cancellation, simulated refund, saved match, changed commitment. Generate after committed events, deduplicate event+recipient+type, honor preferences, retain authoritative history. Deep links open real records with graceful inaccessible/deleted outcomes. No real push/email/SMS required or claimed.

## 14. Simulated ledger, earnings, cancellation

One “Demo balance — no real money” option, no real financial inputs. Append-only authorization/capture/release/refund/earning/payout events with unique operation keys.

Submission authorizes; runner acceptance captures once; approved counteroffer acceptance atomically releases/replaces old authorization and captures the approved total once. Reject/expire/cancel before acceptance releases once. Delivery credits earnings once. Explicit demo payout moves eligible completed earnings to simulated paid, no bank transfer.

Separate estimated, accepted/pending, earned, available demo balance, simulated paid, and refund adjustments. Historical fee/share snapshots do not change with configuration. Gross revenue=fee−share. Optional modeled processing 2.9%+$0.30 is labeled assumption; contribution subtracts modeled costs and is not revenue. Only show effort-hour metrics when positive measured driving/handling/waiting supports them; never guarantee wage.

Cancellation policy:
- Before acceptance: release authorization.
- Accepted/not picked up: full simulated delivery-fee refund, no penalty; merchant purchase remains separate.
- After pickup: support workflow, not instant refund/cancellation.
- Runner cancellation: resolve uncollected orders/refunds and notify participants; collected items go to support, no fake reassignment.
- Delivered: support may explicitly approve full fee refund while keeping DELIVERED fulfillment; partial refunds out of demo scope.
- Never refund more than captured. Reverse unpaid runner credit once; already simulated-paid amounts create visible adjustment/support accounting, not pretend bank clawback.

## 15. Support/admin

Cases: missing/damaged/incorrect item, failed pickup, missed meetup, customer/runner no-show, payment question, conduct, other. Persist actor/order/category/details/timestamps and OPEN → IN_REVIEW → RESOLVED/CLOSED. Keep reports private.

No-show escalation after 10 demo minutes from arrival; no automatic penalties/completion. Support console only through demo tools; inspect trip/order/quote/ledger, audit resolutions. Resolution text alone does not refund; explicit domain action does. No production admin bypass or nonexistent email/call buttons.

## 16. Reliability and failure behavior

Atomically validate actor, capacity, quote/deadline, route version, and price consent. Disable duplicate taps AND enforce domain idempotency/reuse keys on retries. Persist commands and events together; persistence failure rolls back/prevents success. Relaunch reconciles interrupted work without orphan orders/captures/notifications.

Reject invalid/terminal actions outside UI too. Retry safe operations only; preserve inputs. Cancel superseded searches/ignore stale responses. Maintain pricing/event history. Provider failure never means free/flat fee. Sanitize logs; no secrets/PIN/private message contents. Inject route/photo/persistence/timeout/expiry/final-slot failures through demo controls.

Retain existing real access controls and constraints; add compatible backend enforcement only where backend actually participates. Local demo role checks are not production authorization.

## 17. Theme continuity

Do not restart the visual overhaul. Extend its shared typography, logo-matched maroon, unchanged logo, warm texture, sketch language, controls, timelines, navigation, and motion across all new customer/runner screens.

Continuous backgrounds behind system areas; safe-area/keyboard/Dynamic-Type-respecting content. Correct obvious title/search/photo/action ratios through shared layout, not giant spacers/stretched empty panels. One consistent voice. Native system controls may retain platform fonts when necessary; document exceptions.

Installed design/SwiftUI/animation/accessibility/performance skills may help. Watermelon UI, Skiper UI, motion.dev are references, not web runtime dependencies. Motion is purposeful, interruptible, Reduce-Motion-aware, and confirms success after commitment.

## 18. Required scenarios and presenter content

Each launcher uses normal shared domain records, not disconnected animations. Provide exact actor switches, controls, and expected outcomes.

1. **From Houston, with dinner:** Maya selects Jordan/Bayou Bowl Kitchen/light meal/Campus Library Plaza; $8; submits; Jordan accepts/confirms pickup/reference, picks up/travels/arrives; Maya reads PIN; Jordan completes; order history and $6.40 simulated earnings reconcile.
2. **Worth the detour:** Dallas +6 miles/+12 minutes, $15.50/$12.40, accept/complete.
3. **A little heavier:** Austin 35 lb standard route $15/$12; unknown/>50 manual review. A $18 custom counteroffer needs explicit approval, yields $14.40 share. Any >50 example must be within Sam's 60 lb/item and 75 lb total limits; otherwise block it.
4. **One stop, two orders:** Maya/Alex compatible pickup; separate orders/PINs, shared stop, no duplicated route impact.
5. **Catch the next trip:** San Antonio empty → save request → explicitly publish matching trip → one notification → trip details, no booking/charge.
6. **Plans change:** accepted/uncollected runner cancellation reconciles orders/capacity/notifications/refunds/history.
7. **The last spot:** two requests race for one slot, one succeeds, other recoverable error/no capture.
8. **Make it right:** delivered-order issue → private case → explicit support full simulated refund → preserved history/adjustments.
9. **Welcome, Aggie:** fresh entry, unchecked Terms/documents/version record, role/settings switches, relaunch persistence.
10. **Offline, still presentable:** essential assets/data work without network; injected quote failure shows retry/review; reset restores baseline.

Also support scenario checks for declined/expired counteroffer, wrong/reused PIN, cutoff/full trip/no results, image failure, and missing deep-link target. Keep demo data isolated.

Write a five-minute walkthrough: 30-second intro/slogan, two-minute standard request/actor switching, one-minute detour/counteroffer, one-minute matching or cancellation, 30-second earnings/history/reset. No live purchases or external recipients needed.

## 18A. Complete navigation and control contract

The objective is ordinary, intuitive delivery-app completeness within Home Run's trip-based scope. Do not clone DoorDash branding or invent dedicated couriers, instant delivery, merchant menus, loyalty programs, memberships, or real financial features. Every existing visible interactive element must have a defined destination/action, loading state, error/recovery, permission rule, and meaningful result.

Audit ALL current customer and runner screens. Create an interaction inventory with actual screen/control labels and source paths, destination/command, required selections, state mutation, success/error behavior, and test coverage. Repair existing controls even when they are not explicitly named below. Decorative elements must not look tappable. Disabled actions explain why. Unsupported external services are honest disabled information, not pretend success.

Use one typed/coordinated navigation system following existing architecture. Resolve route models by stable IDs; do not pass stale copies of an order across screens. Give major views stable accessibility identifiers for UI tests. Preserve each tab's stack, role/session boundaries, safe back behavior, and appropriate draft restoration.

### Entry, navigation, and shared controls
- “Explore demo”: persona chooser → Terms if needed → customer/runner home. Persona change stays inside isolated demo state.
- Real Sign in/Sign up/Forgot password: existing functioning auth flows with required validation; errors stay on form. Demo entry never demands real credentials.
- Terms/Privacy links open readable documents with Close/Back, never lose form input. Accept is unchecked; Continue validates acceptance.
- Customer tabs: Home, Discover, Orders, Profile. Runner tabs: Requests, Deliveries, My trips, Earnings. Reuse established equivalent labels rather than adding duplicate tabs.
- “Bring food” switches the same actor into runner mode at Requests/My trips as appropriate. Customer-side return says “Order food” or another clear consistent label; avoid ambiguous “Order” meaning a singular existing order.
- Notification bell/inbox opens actual notifications; badge derives unread count. Row opens accessible target, marks read; “Mark all read” updates store once.
- Back returns to originating screen with selections/scroll preserved. Close sheet dismisses it. Destructive exit asks whether to discard or keep draft. Avoid dismissal that silently submits.
- Logout clears authenticated navigation/participant data from visible state, preserves stored demo history, and returns to entry. Relaunch restores only the appropriate session.

### Home and Discover
- Pickup-city label/chevron opens city picker; search/list selection updates shared state and query. Cancel leaves previous choice unchanged.
- Home search field enters city-aware Discover with the typed query and active city. Arrow/Search/keyboard submit perform the SAME search, not navigation to an empty screen.
- Category/filter chips update results; filter button opens editable sheet with Apply/Reset/Cancel. “Clear all” removes filters but preserves city.
- Restaurant/store card and photo open the same place detail, no dead image area. Bookmark toggles saved place for the active user with persistent state and feedback; use it only if implemented.
- Trip card → actual trip details. “View all trips” opens filtered list in selected city. No-trip action “Save a request” opens prefilled saved-request form.
- Pull-to-refresh reloads current data with actual async state; no hardcoded delay pretending to refresh. Retry repeats the failed operation without clearing useful selections.

### Place and trip details
- Place details: photo gallery opens viewer with paging/close and attribution; address and hours expand when supplied; no invented metadata.
- “Website” opens valid merchant URL; absent URL hides/disables action clearly. No unsupported real phone calls or fake “Order from store” success.
- “Find a trip” loads compatible actual demo/development trips for that origin/place. Select a trip → detail → “Request pickup” → prefilled shared order flow.
- No compatible trip: show save-request and change-date/city actions, never a selectable nonexistent runner.
- Trip detail shows stops/windows/capacity/driver display profile. Runner profile reveals only appropriate public data; no private reports/contact info. Route control opens existing compatible map or accessible route summary.
- “Request pickup” confirms trip/place/city consistency. “Choose another trip/place” goes back to the correct picker and invalidates affected quotes.

### Item list, meetup, quote, review
- “Add item” opens item editor. Save validates name/positive quantity/weight status. Quantity +/- updates totals; Remove deletes with undo or confirmation. Edit reopens actual line. No unrelated sample products injected into live merchant content.
- Pickup instructions/reference fields persist with draft. Personal item mode changes required fields/labels appropriately.
- “Choose meetup” opens saved/demo-approved locations plus custom confirmation where supported; selection returns label/coordinates/source. Location permission is optional, with manual entry alternative.
- “Continue” validates current step inline and focuses first error. Previous steps remain editable. Back does not erase items.
- “Get delivery quote”/step transition invokes shared pricing once and shows real loading. Error offers retry/review; expiry offers “Refresh quote.” Never allow stale total at submission.
- Review shows pickup city/place, trip/runner, items/quantities, meetup/window, itemized delivery charge, separate merchandise-payment arrangement, and simulation indicator.
- Each “Edit” returns to corresponding step. Changes invalidate only affected quote/trip selections and require repricing/reconfirmation.
- “Submit pickup request” validates current quote and invokes one idempotent command. Disable during submit; retries reuse operation identity. Success opens confirmation with “View order,” then persists in Orders and runner Requests.
- Pending unknown/manual quotes show “Request a quote,” not a misleading charge/zero total. Customer price approval explicitly shows old/new amount.

### Customer Orders, tracking, history
- Active/Past filters show actual orders; row → correct detail with items, price snapshot, timeline, meetup, messages, and permitted actions.
- “Message runner” opens that order's authorized thread. Send validates nonempty message, preserves failed text, offers retry without duplicate sends. Returning maintains order state.
- “View pickup/meetup” opens map/summary appropriate to data provider. Simulation is visible; no fake live GPS.
- “View confirmation code” shows customer-only PIN at eligible stage. Hide/reveal respects privacy; code never appears on runner detail.
- “Cancel request” shows stage-specific effect and explicit confirmation; then domain cancellation and updated ledger/history/inboxes. After pickup it becomes “Get help,” not a forbidden cancel button.
- “Review counteroffer” opens breakdown/expiry and Accept/Decline. Accept revalidates and records approved price; decline/expiry updates both actors and releases applicable authorization.
- “Report an issue” opens category/details form tied to order → submitted case → case detail. “View receipt” shows delivery-fee simulation and actual recorded entries, not a real tax receipt.
- “Order again” copies reusable item/pickup preferences into a NEW draft and requires fresh city/trip/quote/availability checks. Never reuses old quotes or silently places an order.

### Runner Requests and Deliveries
- Incoming request row → actionable detail with fee/share/detour/handling/window. Accept uses atomic eligibility checks; Decline collects reason/confirmation; custom Counteroffer opens amount/reason with explicit submit/cancel.
- Accepted request moves into Deliveries and relevant trip manifest; customer detail updates from the same record. Repeated taps never create duplicate tasks.
- Active delivery row → delivery workflow. “Confirm pickup details,” “Picked up,” “Start travel,” and “Arriving” invoke permitted transitions and timestamps with necessary prerequisites. Buttons for invalid steps are absent/disabled with clear explanation.
- “Message customer” opens same authorized conversation. “Report delay” asks new ETA/reason and notifies once. “Meetup directions” uses valid map URL/provider; if unavailable, show address/route summary.
- “Complete delivery” opens PIN entry from ARRIVING. Wrong PIN shows recoverable error/attempt policy; valid PIN commits delivery/earnings once and shows completion summary.
- “Problem with delivery” creates support workflow; no shortcut around PIN or collected-item resolution.

### My trips, planned stops, recurrence
- “Post a trip” opens creation form; “Save draft” persists without publishing; “Publish trip” validates and exposes to discovery. Cancel/back preserves or explicitly discards draft.
- Stop search uses selected origin/route context and correct provider; selecting result adds actual stop. Stop edit/remove/reorder respects pickup-before-delivery and accepted commitments.
- Trip detail → Edit, Close requests, Reopen requests, Start trip, Complete trip, Cancel trip only when permitted. Confirmation explains affected orders. Invalid changes preserve original state.
- Manifest opens linked orders, not a static count. Capacity labels derive reservations.
- Recurrence switch reveals weekday/every-other-week controls; preview shows dates; Generate drafts idempotent; publish/skip/edit occurrence affects actual instance.

### Earnings, Profile, Saved, Help
- Earnings period selector changes derived ledger totals and list. Row → relevant order/entry breakdown. “Simulate payout” exists only in labeled demo tools or explicit demo panel, never a fake bank button.
- Profile → Edit profile, saved cities/places, meetups, saved requests, notification preferences, histories, Help, About, Terms/Privacy, Demo controls, Log out, deletion request. Each destination persists edits and returns coherently.
- Saved place opens detail; removal updates lists. Saved request detail permits edit/pause/delete; matched notification opens real compatible trip. No automatic purchase.
- Help → FAQ topics → answer; “Contact support” → in-app case form. Case list/detail shows actual progress and relevant order links.
- Admin/support tools remain demo-isolated with explicit audited actions, never visible as normal customer privilege.

### State preservation and actions without data

Keep per-actor favorites, preferences, histories and unread counts isolated. Global city selection affects discovery and new drafts; an existing draft keeps its own visible city until explicitly changed. Do not allow a tab change to silently rebind an in-progress order. Refresh shared records on role switch so stale screens cannot act on outdated state.

Every list must define loading, populated, zero-results, unavailable/error, retry, and refresh behavior. Every form defines field rules, keyboard/submit, busy state, error recovery, cancel/back, persistence, and success destination. Empty states link to the correct creation/discovery action. Missing-data deep links fail gracefully rather than crash.

### Interaction coverage acceptance gate

Audit and resolve every placeholder closure, TODO action, empty handler, hardcoded success, dead navigation link, disabled unexplained control, duplicated screen state, and unhandled routing case in the actual app. Do not delete required controls just to improve coverage.

Deliver the interaction inventory with each control marked implemented/tested, implemented/unverified, intentionally unavailable with reason, or incomplete. Critical paths cannot be counted complete with dead controls. Cover city selection → live/sample search → photo/detail → compatible trip → items → quote → submit → runner acceptance → messages → fulfillment/PIN → history/earnings plus cancel/counteroffer/support. UI tests use stable identifiers and explicit assertions, not screenshots alone. Report real-device/simulator checks separately from mocked integration tests.

## 19. Tests and validation

Use existing frameworks; inject clock/IDs/routes/ledger/persistence failures. Add tests alongside meaningful slices:
- Pricing examples/exact-above thresholds/weights 10,25,50,>50/quantities/fractions/half-up rounding/negative deltas/wait/bulky/invalid values/discount safeguards.
- Quote/request expiry, cutoffs, stale routes, manual review, revised consent, accepted snapshots.
- Trip/order transitions, hard limits, capacity race, shared-stop retention, recurrence idempotency/timezone handling.
- Actor access, own-trip exclusion, Terms versions, dual-role persistence, demo support isolation.
- Full standard/custom/counteroffer journeys on shared persisted records.
- Duplicate submit/accept/capture/PIN completion/refund/payout, retries/relaunch interruption.
- Wrong/reused PIN and no runner disclosure; message/unread access; notification dedup/deep links.
- Cancellation/support/refund and ledger reconciliation.
- Seed referential integrity, reset twice, clock advance, relaunch, stored migrations/recovery.
- Offline/provider/image/persistence failures and draft preservation.
- City-first and trip-first navigation; city changes invalidate stale selections/quotes; Google query city context/field decoding/pagination; photo metadata-to-image loading and attribution; missing photos; stale query/city races; every control in the interaction inventory.
- Configured Google live smoke-check separately from mocked tests; do not report fixture rendering as proof of Google functionality.

Run actual available app/backend checks only where components exist. No invented npm commands for Swift-only code, real transactions, or remote mutations. Inspect small/large iPhones, larger text, VoiceOver, Reduce Motion, keyboard, populated/empty/loading/error states and screenshots where possible. Without Mac/Xcode, mark build/UI runs unrun and give exact project/scheme commands discovered for Mac review.

## 20. Order of work and deliverables

Work in dependency order with tests alongside implementation:
1. Audit, environment isolation, shared state/service reconciliation.
2. Persistent store, fixtures, clock/IDs, actors/reset.
3. Restore pickup-city selection and Google restaurant/store search/photo pipeline first; implement Accounts/Terms, trips/discovery/places using the shared flow.
4. Pricing/routes/quotes/customer requests.
5. Runner acceptance/counteroffers/capacity/ledger.
6. Fulfillment/PIN/tracking/messages/notifications.
7. Cancellation/support/refunds/earnings/saved matching/recurrence.
8. App-wide shared-component/copy consistency, scenarios, validation.

No Kafka, microservices, speculative auth replacement, financial onboarding, or unrelated features.

Document in the existing docs location:
- Requirement/status/file map and complete screen/control interaction inventory with real paths.
- Discovery regression root causes, fixes, selected Google API/SDK version, configuration requirements, photo attribution/storage policy, and live versus mocked verification evidence.
- Setup/personas/scenarios/clock/reset/presenter script.
- Architecture/state transitions/pricing decisions/future real-provider boundaries.
- Theme guide identifying single points for future font/color/material changes.
- Asset sources/licenses, legal drafts, production limitations.
- Checks run/results/failures/unrun checks/outstanding work.

Final report distinguishes implemented/tested; simulated by design; implemented/unverified; optional real integration awaiting configuration; incomplete. Simulated is intentional; disconnected placeholders are not completion. If context/time runs short, save exact progress/next tasks and resume dependency order instead of silently dropping scope.

Begin with the actual repository audit, then implement the connected demo. No second part or routine phase approvals required.
