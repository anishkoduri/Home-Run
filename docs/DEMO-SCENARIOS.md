# Home Run presenter scenarios

The primary customer on this build is displayed as Anish Koduri. The stored id is still `demo-maya` and the email is `maya@demo.local`. The master specification still says Maya Chen. Do not treat the display name as a change to the spec.

Payments, payouts, and tracking stay simulated. Google map, live search, photos, and routes stay pending until they are exercised inside the running app.

## Five-minute walkthrough

1. Open the app. Read “By Aggies, for Aggies.” Accept the unchecked demo terms only after opening them. Say this is a student demo, not a university service, and that no card is charged.
2. Home shows trips to College Station. Discover: confirm the pickup city, search a place, open a trip, enter an item and weight, keep Campus Library Plaza, and submit. The stored quote comes from `PricingPolicy`.
3. Profile → Demo people → Jordan Ellis. Requests shows the same order. Accept, confirm pickup, mark picked up, start travel. Switch back to Anish Koduri, read the code, switch to Jordan, and complete delivery. Earnings shows the simulated share.
4. For the detour, use a Dallas request whose extra distance and time price to $15.50. For a custom price, Jordan sends a counteroffer and the customer approves it. Profile → Demo controls can publish a San Antonio trip after a saved request, or cancel a trip before pickup so the ledger refunds.
5. Earnings → Simulate payout. It is labeled demo and is not a bank transfer. Demo controls → Reset demo records restores the fictional baseline and leaves Account 1 alone.

## Scenarios

1. **From Houston, with dinner.** Anish Koduri, Jordan’s Houston trip, a light confirmed item, Campus Library Plaza. A route inside 1 mile and 5 minutes quotes $8 and a $6.40 simulated share. Submit, accept, pickup, PIN, history.
2. **Worth the detour.** Dallas, 6 extra miles and 12 extra minutes. Quote $15.50, share $12.40.
3. **A little heavier.** Austin, 35 lb on a standard route quotes $15 / $12. Unknown weight or over 50 lb stays in review and is never $0. Sam’s trip allows a 60 lb item and 75 lb total; a counteroffer still cannot pass those limits. An $18 approved counteroffer records a $14.40 share.
4. **One stop, two orders.** Anish and Alex can request the same trip. Each order has its own code. The shared-stop discount of $2 is defined and switched off.
5. **Catch the next trip.** San Antonio has no published trip. Save a request. Demo controls → Publish a matching trip. One notice. Nothing is booked or charged.
6. **Plans change.** Cancel a runner trip before pickup. Uncollected orders release or refund and the other person is notified.
7. **The last spot.** Acceptance checks remaining capacity. A full trip returns an error and does not capture another fee.
8. **Make it right.** After delivery, Get help opens a case. Switch to Taylor Brooks in Demo people. Resolve does not refund. Simulate full refund does, and the order stays delivered.
9. **Welcome, Aggie.** A fresh demo person sees unchecked terms. The version is `demo-1`. Role switching and the demo clock survive relaunch. Forgot password says no email was sent.
10. **Offline, still presentable.** With no Places key, Discover uses the labeled sample catalog. A straight-line route is not given a delivery fee. Reset restores the baseline trips.

## Controls added in this pass

| Control | Where | Result |
| --- | --- | --- |
| 1 · Houston dinner through 10 · Offline | Profile → Demo controls | Resets fictional demo records and leaves the shared state for that scenario. Does not tap the scenario for you. |
| Edit trip / Edit this date | My trips | City, departure, cutoff, arrival, spots, extra miles and minutes, weight limits, custom items, notes, and stops. This date does not change the series. |
| Add stop, Up, Down, Remove | Edit trip | Reorders planned stops. An accepted pickup's stop cannot be removed. Open quotes expire. |
| Notifications bell | Home, runner header, Profile | Opens the in-app inbox |
| Decline / Counter | Runner request | Reason required; counteroffer is $1–$250 and waits for the customer |
| Approve price / Keep earlier terms | Customer order | Captures the approved total once, or restores the earlier quote |
| Cancel delivery | Order, before pickup | Confirmation states release or full refund |
| Get help | Order, after pickup or delivery | Opens a support case |
| Report a delay | Runner delivery | One in-app notice |
| Repeat weekly | My trips | Draft copies for the next 28 days, same template is not duplicated |
| Simulate payout | Earnings | Moves a simulated earning to paid once |
| Saved requests | Profile | No booking |
| Demo controls | Profile | Clock +5, +15, +1 day; publish a city; confirmed reset |
| Forgot password | Sign in | States that no email was sent |
