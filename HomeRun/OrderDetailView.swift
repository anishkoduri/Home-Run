import MapKit
import PhotosUI
import SwiftUI

struct OrderDetailView: View {
    @Environment(AppModel.self) private var model
    var id: String
    /// Opened from the runner's request list. Shows the accept screen, never the customer's detail form.
    var forRunner = false
    @State private var order: Order?
    @State private var error: String?
    @State private var busy = false
    @State private var pickupName = ""
    @State private var orderNumber = ""
    @State private var ready = Date().addingTimeInterval(3600)
    @State private var instructions = ""
    @State private var ordered = false
    @State private var confirmCancel = false
    @State private var routePath: [[Double]]?
    @State private var routeSource: String?
    @State private var pinEntry = ""
    @State private var messageText = ""
    @State private var messages: [OrderMessage] = []
    @State private var helpOpen = false
    @State private var helpDetails = ""
    @State private var receipt: [LedgerEntry] = []
    @State private var showReceipt = false
    @State private var basket: UIImage?
    @State private var showBasket = false
    @State private var actualAmount = ""
    @State private var collectionChecked = false
    @State private var referenceMissing = false
    @State private var readyConfirmed = false
    @State private var branchNote = ""
    @State private var pickupCode = ""
    @State private var windowChoice = "30 minutes before departure"
    @State private var editingHandoff = false
    @State private var detailsText = ""
    @State private var handoffPhoto: PhotosPickerItem?

    var body: some View {
        ScrollView {
            if let order {
                content(order)
            } else if let error {
                ErrorBanner(message: error).padding(20)
            } else {
                ProgressView("Loading order…").padding(40)
            }
        }
        .homeRunPage(road: forRunner)
        .environment(\.onTheRoad, forRunner)
        .background((forRunner ? Theme.runnerPaper : Theme.cream).ignoresSafeArea())
        .toolbarBackground(forRunner ? Theme.runnerPaper : Theme.orderingBar, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationTitle(order?.restaurantName ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .task { await watch { await load() } }
        .sheet(isPresented: $showBasket) {
            if let basket {
                NavigationStack {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: basket)
                            .resizable()
                            .scaledToFit()
                            .accessibilityLabel("Basket screenshot")
                    }
                    .homeRunPage(road: false)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showBasket = false } } }
                }
            }
        }
        .sheet(isPresented: $showReceipt) {
            NavigationStack {
                List(receipt) { entry in
                    VStack(alignment: .leading) {
                        Text(Self.ledgerTitle(entry.kind)).font(Theme.text(.body, weight: .semibold))
                        Text(Fees.money(Double(entry.cents) / 100)).font(Theme.text(.caption))
                    }
                }
                .navigationTitle("Simulated receipt")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showReceipt = false } } }
            }
        }
    }

    @ViewBuilder
    private func content(_ order: Order) -> some View {
        let role: String = {
            let driving = forRunner || model.side == .driving
            if driving, !order.driverId.isEmpty, order.driverId == model.user?.id { return "driver" }
            if driving, order.status == .requested, order.driverId.isEmpty { return "marketplace" }
            if driving { return order.driverId == model.user?.id ? "driver" : "marketplace" }
            if !order.driverId.isEmpty, order.driverId == model.user?.id { return "driver" }
            if order.customerId == model.user?.id { return "customer" }
            return "marketplace"
        }()
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text(role == "driver" ? "Delivery for \(order.customer?.displayName ?? "customer")" : "Order \(Format.shortId(order.id))")
                        .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                    Text(order.restaurantName).font(Theme.brand(.title2)).foregroundStyle(Theme.maroon)
                    Text("\(order.trip?.originCity ?? "") → \(order.destinationLabel)").foregroundStyle(Theme.muted)
                }
                Spacer()
                StatusPill(status: order.status, title: order.progressTitle)
            }
            if let error { ErrorBanner(message: error) }
            actions(order, role: role)
            if role == "customer", !order.driverId.isEmpty {
                DriverTrackMap(order: order)
            }
            timeline(order)
            facts(order, role: role)
            conversation
            if let trip = order.trip {
                RouteMap(path: routePath ?? [
                    [trip.originLat, trip.originLng],
                    [order.restaurantLat, order.restaurantLng],
                    [order.destinationLat, order.destinationLng],
                    [trip.destinationLat, trip.destinationLng],
                ])
                Text(routeCaption)
                    .font(Theme.text(.caption))
                    .foregroundStyle(Theme.muted)
                    .font(Theme.text(.caption))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(20)
        .onAppear {
            detailsText = order.itemSummary ?? ""
            pickupName = order.pickupName ?? ""
            orderNumber = order.restaurantOrderNumber ?? ""
            instructions = order.pickupInstructions ?? ""
            if let readyAt = order.pickupReadyAt, let date = Format.parse(readyAt) { ready = date }
            ordered = order.status == .restaurantConfirmed
        }
    }

    @ViewBuilder
    private func actions(_ order: Order, role: String) -> some View {
        Card {
            if role == "customer", order.driverId.isEmpty, let cents = order.offerCents {
                Text("A runner offered \(Fees.money(Double(cents) / 100)).")
                    .font(Theme.text(.headline, weight: .semibold))
                Text("The runner earns \(Fees.money(Double(order.offerShareCents ?? 0) / 100)). Home Run keeps the 15% difference. Merchandise is paid to the store, not to the runner.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                Text(RequestRanking.distanceCaption(kind: order.offerDistanceKind ?? "geographic"))
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                Text(order.offerIncremental == true ? "This is the extra distance off a route they are already taking." : "This is a short local estimate until a runner's location revises it. It is not the whole intercity drive.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                Text("The offer is held for 15 minutes. Approving locks this delivery fee.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                PrimaryButton(title: "Approve delivery fee", busy: busy) { Task { await decideOffer(order, "approve") } }
                Button("Decline offer") { Task { await decideOffer(order, "decline") } }
            } else if role == "marketplace", order.status == .requested {
                let preview = RequestRanking.payoutPreview(order, origin: model.runnerOrigin)
                Text("Accept pickup")
                    .font(Theme.text(.headline, weight: .semibold))
                    .accessibilityIdentifier("accept-screen")
                Text(order.itemSummary ?? "Pickup request")
                Text("You earn \(Fees.money(Double(preview.shareCents) / 100))")
                    .font(Theme.price(.title3))
                    .foregroundStyle(Theme.maroon)
                Text("Customer pays \(Fees.money(Double(preview.customerCents) / 100)). Home Run keeps \(Fees.money(Double(preview.customerCents - preview.shareCents) / 100)), which is 15%.")
                    .font(Theme.text(.subheadline))
                Text(preview.caption)
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                Text("Accepting sends this price to the customer. It locks when they approve.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                if order.customerId == model.user?.id {
                    Text("You posted this. Another runner can accept it.")
                        .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                } else {
                    PrimaryButton(title: "Accept", busy: busy) { Task { await claim(order) } }
                        .accessibilityIdentifier("claim-request")
                }
            } else if role == "driver" && order.status == .requested {
                Text("\(Format.firstName(order.customer?.displayName)) wants \(order.restaurantName).")
                Text("About \(Format.minutes(order.detourMinutes)) extra for \(Fees.money(order.deliveryFee)).")
                    .foregroundStyle(Theme.muted)
                PrimaryButton(title: "Accept request", busy: busy) { Task { await setStatus(order, .accepted) } }
                Button("Decline") { Task { await setStatus(order, .declined) } }.foregroundStyle(Theme.bad)
            } else if role == "driver", order.isRunnerPurchase, order.status == .accepted, order.purchaseState != "placed" {
                Text("Older runner-purchase record. It is not a new delivery request.")
                    .foregroundStyle(Theme.muted)
            } else if role == "driver", order.usesCustomerHandoff, order.pendingReadyAt != nil {
                Text("The customer asked for a new pickup time. The delivery fee stays the same until you agree.")
                Button("Agree to the new time") { Task { await decideWindow(order, "accept") } }.font(Theme.text(.body, weight: .semibold))
                Button("Keep the earlier time") { Task { await decideWindow(order, "decline") } }
            } else if role == "driver", order.usesCustomerHandoff, order.placeChangePending == true {
                Text(order.pendingRestaurantName ?? "The customer asked about a different branch.")
                Button("Agree, keep the delivery fee") { Task { await decidePlace(order) } }.font(Theme.text(.body, weight: .semibold))
            } else if role == "driver", order.usesCustomerHandoff, order.detailsNeedReview {
                Text("Review pickup details").font(Theme.text(.headline, weight: .semibold))
                Text("Customer submitted confirmation. This is not proof the merchant is ready.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                Button("Details received") { Task { await markReviewed(order) } }.font(Theme.text(.body, weight: .semibold))
                Button("Ask a question") { messageText = "" }
                    .font(Theme.text(.body, weight: .semibold))
            } else if role == "driver", order.usesCustomerHandoff, order.status == .accepted {
                Text("Waiting for pickup details. Do not collect this yet.")
                    .foregroundStyle(Theme.muted)
            } else if role == "driver", let next = order.driverAction {
                Text(next.1)
                if next.0 == .pickedUp && order.usesCustomerHandoff {
                    Toggle("The name or reference and the described items match what I am collecting", isOn: $collectionChecked)
                    PrimaryButton(title: next.1, busy: busy) { Task { await collect(order) } }
                        .disabled(!collectionChecked)
                } else {
                    PrimaryButton(title: next.1, busy: busy) { Task { await setStatus(order, next.0) } }
                }
            } else if role == "customer", order.isRunnerPurchase, order.purchaseState == "revision", let revised = order.revisionMerchandiseCents {
                Text("The store total is \(Fees.money(Double(revised) / 100)). You approved \(Fees.money(Double(order.merchandiseCents ?? 0) / 100)).")
                    .font(Theme.text(.body, weight: .semibold))
                Button("Approve new merchandise total") { Task { await revise(order, "accept") } }.font(Theme.text(.body, weight: .semibold))
                Button("Keep the approved total") { Task { await revise(order, "decline") } }
            } else if role == "customer", !forRunner, model.side != .driving, order.needsHandoffForm {
                if order.status == .requested && !order.isPersonalPickup {
                    Text("Wait for your runner to accept before ordering.")
                        .font(Theme.text(.body, weight: .semibold))
                    Text("If you already ordered, add the confirmation below. A runner is not guaranteed until acceptance, and Home Run cannot undo the store purchase.")
                        .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                } else if order.status == .accepted && !order.isPersonalPickup {
                    Text("Ready to place your order").font(Theme.text(.headline, weight: .semibold))
                    Text("Order directly from the store, then add your pickup confirmation here.")
                        .foregroundStyle(Theme.muted)
                } else if order.isPersonalPickup && order.status == .accepted {
                    Text("Confirm the item and contact will be ready during the window.")
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("A runner is not guaranteed until acceptance.")
                        .foregroundStyle(Theme.muted)
                }
                handoffForm(order)
            } else if role == "customer", order.canEditHandoff {
                Text("Customer submitted confirmation.")
                if order.detailsReviewedAt != nil && !order.detailsNeedReview {
                    Text("Runner reviewed details.").foregroundStyle(Theme.good)
                }
                Button(editingHandoff ? "Hide pickup form" : "Update pickup details") { editingHandoff.toggle() }
                if editingHandoff { handoffForm(order) }
            } else if role == "driver", order.status == .arriving {
                Text("Ask the customer for the confirmation code. It is not shown here.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                RequiredLabel(title: "Confirmation code", required: true)
                EntryField("Confirmation code", text: $pinEntry, keyboard: .numberPad, identifier: "delivery-pin")
                    .padding(12)
                    .sketchPanel()
                    .accessibilityIdentifier("delivery-pin")
                PrimaryButton(title: "Complete delivery", busy: busy) { Task { await complete(order) } }
            } else if role == "customer", order.status == .arriving, let pin = order.confirmationPin {
                Text("Confirmation code")
                    .font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                Text(pin).font(Theme.price(.title)).foregroundStyle(Theme.maroon)
                    .accessibilityIdentifier("customer-pin")
                Text("Read this to the runner. It works once.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            } else if order.status == .delivered {
                Text("Delivered. The delivery fee stayed a simulation.")
            } else if order.status == .requested && role == "customer" {
                Text(order.isPersonalPickup ? "Awaiting runner. This is a home or personal-item pickup." : "Awaiting runner.")
            } else {
                Text(order.status.label)
            }
            if order.quoteState == "customer_approval", role == "customer", let cents = order.counterCents {
                Text("The runner offered \(Fees.money(Double(cents) / 100)).")
                    .font(Theme.text(.body, weight: .semibold))
                if let reason = order.counterReason { Text(reason).font(Theme.text(.caption)).foregroundStyle(Theme.muted) }
                Button("Approve price") { Task { await decide("accept") } }.font(Theme.text(.body, weight: .semibold))
                Button("Keep earlier terms") { Task { await decide("decline") } }
            }
            if (role == "customer" && order.customerMayCancel) || (role == "driver" && order.driverMayCancel) {
                Button("Cancel delivery") { confirmCancel = true }
                    .foregroundStyle(Theme.bad)
                    .padding(.top, 6)
            }
            if role == "customer", order.status == .restaurantConfirmed || order.status == .pickedUp || order.status == .onTheWay || order.status == .arriving || order.status == .delivered {
                Button("Get help") { helpOpen = true }
                    .font(Theme.text(.body, weight: .semibold))
            }
        }
        .confirmationDialog("Cancel this delivery?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel delivery", role: .destructive) { Task { await setStatus(order, .cancelled) } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text(cancelCopy(order, role: role))
        }
        .sheet(isPresented: $helpOpen) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tell support what happened. This stays on this phone.").font(Theme.section())
                    RequiredLabel(title: "What happened", required: true)
                    EntryField("What happened", text: $helpDetails, axis: .vertical).padding(12).sketchPanel()
                    PrimaryButton(title: "Open a case") { Task { await openHelp(order) } }
                    Spacer()
                }
                .padding(20)
                .homeRunPage(road: forRunner)
                .environment(\.onTheRoad, forRunner)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { helpOpen = false } } }
            }
            .presentationDetents([.medium])
        }
    }

    private func cancelCopy(_ order: Order, role: String) -> String {
        switch order.status {
        case .requested: return "The simulated delivery authorization is released. Nothing was captured."
        case .accepted: return order.isPersonalPickup ? "The personal-item pickup has not been confirmed ready. The simulated delivery fee is refunded." : "The store confirmation is not in yet. The simulated delivery fee is refunded. Money you already paid the store is not refunded here."
        case .restaurantConfirmed: return order.isRunnerPurchase ? "This older purchase stays with support." : "The simulated delivery fee is refunded. Home Run cannot refund money paid to the store."
        case .pickedUp, .onTheWay, .arriving: return "After collection, cancellation goes through support."
        default: return "This stops the delivery."
        }
    }

    private func decide(_ decision: String) async {
        guard let order else { return }
        do {
            let _: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: CounterDecision(counterDecision: decision))
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func openHelp(_ order: Order) async {
        let details = helpDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !details.isEmpty else { return }
        do {
            let _: SupportCase = try await model.client().store("support", method: "POST", body: SupportDraft(orderId: order.id, category: "delivery", details: details))
            helpOpen = false
        } catch { self.error = error.localizedDescription }
    }

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Messages").font(Theme.section())
            if messages.isEmpty {
                Text("No messages yet.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            }
            ForEach(messages) { message in
                Text(message.body)
                    .font(Theme.text(.subheadline))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: message.senderId == model.user?.id ? .trailing : .leading)
            }
            RequiredLabel(title: "Message", required: true)
            EntryField("Message", text: $messageText, identifier: "order-message")
                .padding(12)
                .sketchPanel()
            Button("Send") { Task { await sendMessage() } }
                .font(Theme.text(.body, weight: .semibold))
        }
        .padding(16)
        .sketchPanel()
    }

    private func timeline(_ order: Order) -> some View {
        let steps: [(String, String?)] = [
            ("Requested", order.createdAt),
            ("Driver accepted", order.acceptedAt),
            ("Purchase recorded", order.restaurantOrderConfirmedAt),
            ("Picked up", order.pickedUpAt),
            ("On the way", order.onTheWayAt),
            ("Arriving", order.status == .arriving || order.status == .delivered ? (order.deliveredAt ?? order.onTheWayAt) : nil),
            ("Delivered", order.deliveredAt),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("Progress").font(Theme.section())
            ForEach(steps, id: \.0) { step in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: step.1 == nil ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(step.1 == nil ? Theme.muted : Theme.good)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.0)
                        Text(step.1.map(Format.dayTime) ?? "Not yet").font(Theme.text(.subheadline)).foregroundStyle(Theme.muted)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .sketchPanel()
    }

    private func facts(_ order: Order, role: String) -> some View {
        Card {
            Text("Restaurant").font(Theme.text(.headline, weight: .semibold))
            Text(order.restaurantAddress ?? "")
            if let website = restaurantURL(order.restaurantWebsite) {
                Link("Restaurant website", destination: website).font(Theme.text(.body, weight: .semibold))
            }
            Text("Handoff").font(Theme.text(.headline, weight: .semibold)).padding(.top, 6)
            Text(order.destinationLabel)
            if let directions = URL(string: "https://maps.apple.com/?daddr=\(order.destinationLat),\(order.destinationLng)") {
                Link("Meetup directions", destination: directions).font(Theme.text(.body, weight: .semibold))
            }
            if let arrival = order.estimatedArrivalAt {
                Text("Estimated around \(Format.time(arrival))").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            }
            if let basket {
                Button { showBasket = true } label: {
                    Image(uiImage: basket)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Basket screenshot. Full screen.")
                }
                .padding(.top, 6)
            }
            if let summary = order.itemSummary {
                Text("Pickup details").font(Theme.text(.headline, weight: .semibold)).padding(.top, 6)
                Text(summary)
            }
            if order.handoffSubmittedAt != nil {
                Text("Customer submitted confirmation").font(Theme.text(.caption, weight: .semibold))
            }
            if order.detailsReviewedAt != nil, !order.detailsNeedReview {
                Text("Runner reviewed details").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.good)
            }
            if let name = order.pickupName { Text("Name on the order: \(name)") }
            if order.referenceMissing == true {
                Text("Merchant did not provide a number.")
            } else if let number = order.restaurantOrderNumber {
                Text("Reference: \(number)")
            }
            if let window = order.pickupWindowLabel { Text("Pickup window: \(window)") }
            if let code = order.pickupCode { Text("Pickup code: \(code)") }
            if let contact = order.contactLabel { Text("Meet: \(contact)") }
            if let access = order.accessInstructions { Text(access) }
            if order.isRunnerPurchase {
                Text("Earlier runner-purchase record. Its merchandise ledger is unchanged.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            }
            if let lines = order.lines, !lines.isEmpty {
                ForEach(lines) { line in
                    Text("\(line.quantity)× \(line.name)\(line.weightPounds.map { " · \(Int($0)) lb" } ?? "")")
                        .font(Theme.text(.subheadline))
                }
            }
            Text("Amounts").font(Theme.text(.headline, weight: .semibold)).padding(.top, 6)
            if order.quoteState == "expired" {
                Text("Quote expired. Submit a new request.").font(Theme.price()).foregroundStyle(Theme.maroon)
            } else if role == "marketplace", order.deliveryFee == nil {
                let preview = RequestRanking.payoutPreview(order, origin: model.runnerOrigin)
                Text("You earn \(Fees.money(Double(preview.shareCents) / 100))").font(Theme.price()).foregroundStyle(Theme.maroon)
                Text("Customer pays \(Fees.money(Double(preview.customerCents) / 100)). Home Run keeps the 15%.")
            } else if order.quoteState == "review" || order.deliveryFee == nil {
                Text("Price needs review").font(Theme.price()).foregroundStyle(Theme.maroon)
            } else if let goods = order.merchandiseCents, let fee = order.quoteCents {
                Text("Merchandise \(Fees.money(Double(order.actualMerchandiseCents ?? goods) / 100))")
                Text("Delivery \(Fees.money(Double(fee) / 100))")
                Text("Total approved \(Fees.money(Double((order.actualMerchandiseCents ?? goods) + fee) / 100))").font(Theme.price()).foregroundStyle(Theme.maroon)
            } else {
                Text("Delivery \(Fees.money(order.deliveryFee))").font(Theme.price()).foregroundStyle(Theme.maroon)
            }
            Text("Simulated. Merchandise reimbursement is separate from the delivery earning.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            if role == "driver", let share = order.runnerShareCents {
                Text("Delivery earning \(Fees.money(Double(share) / 100))").font(Theme.text(.caption))
                if let goods = order.actualMerchandiseCents ?? order.merchandiseCents, order.personalItem != true {
                    Text("Merchandise reimbursement \(Fees.money(Double(goods) / 100))").font(Theme.text(.caption))
                }
            }
            if role == "customer", let handle = order.driver?.paymentHandle {
                Text("Runner handle \(handle). Simulated only.").font(Theme.text(.caption))
            }
            if order.status == .delivered, role == "customer" {
                Button("Order again") {
                    let lines = order.lines ?? [OrderLine(id: order.id, name: order.itemSummary ?? order.restaurantName, quantity: 1, weightPounds: nil, weightConfirmed: false, bulky: false, fragile: false, note: nil)]
                    model.stageRepeat(lines)
                }
                .font(Theme.text(.body, weight: .semibold))
            }
            Text("No card is charged. Amounts stay in the demo ledger.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            Button("View receipt") { Task { await loadReceipt(order) } }
                .font(Theme.text(.body, weight: .semibold))
        }
    }

    private func loadReceipt(_ order: Order) async {
        let list: LedgerList = (try? await model.client().store("ledger", query: ["order": order.id])) ?? LedgerList(entries: [])
        receipt = list.entries
        showReceipt = true
    }

    private func load() async {
        do {
            let envelope: OrderEnvelope = try await model.client().store("orders", query: ["id": id])
            order = envelope.order
            if envelope.order == nil { error = "Order not found." }
            else if let order = envelope.order {
                await loadBasket(order)
                if routePath == nil {
                    await loadRoute(order)
                    await loadMessages()
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadRoute(_ order: Order) async {
        guard let trip = order.trip else { return }
        do {
            let result = try await Routing.estimate(
                client: try model.client(),
                origin: LatLng(lat: trip.originLat, lng: trip.originLng),
                destination: LatLng(lat: trip.destinationLat, lng: trip.destinationLng),
                stops: (trip.stops ?? []).map { LatLng(lat: $0.lat, lng: $0.lng) },
                restaurant: LatLng(lat: order.restaurantLat, lng: order.restaurantLng),
                dropoff: LatLng(lat: order.destinationLat, lng: order.destinationLng)
            )
            routePath = result.0.withPath
            routeSource = result.0.source
        } catch {
            routePath = nil
            routeSource = nil
        }
    }

    private func loadMessages() async {
        guard let list: MessageList = try? await model.client().store("messages", query: ["order": id]) else { return }
        messages = list.messages
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let list: MessageList = try await model.client().store("messages", method: "POST", query: [:], body: MessageDraft(orderId: id, body: text))
            messages = list.messages
            messageText = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func complete(_ order: Order) async {
        busy = true
        defer { busy = false }
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: DeliveryPatch(status: OrderStatus.delivered.rawValue, pin: pinEntry))
            self.order = updated
            pinEntry = ""
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func decideOffer(_ order: Order, _ decision: String) async {
        busy = true
        defer { busy = false }
        struct Body: Encodable { var offerDecision: String }
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: Body(offerDecision: decision))
            self.order = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func claim(_ order: Order) async {
        busy = true
        defer { busy = false }
        let preview = RequestRanking.payoutPreview(order, origin: model.runnerOrigin)
        let meters = preview.meters
        let mine: [Trip] = (try? await model.client().store("trips", query: ["mine": "1"])) ?? []
        let tripId = mine.first { $0.status == "scheduled" && $0.destinationCity == Places.destination.name }?.id
        struct Body: Encodable {
            var offer: String
            var extraMeters: Double
            var extraSeconds: Double
            var distanceKind: String
            var incremental: Bool
            var tripId: String?
        }
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: Body(offer: "submit", extraMeters: meters, extraSeconds: preview.seconds, distanceKind: "geographic", incremental: model.runnerOrigin != nil, tripId: tripId))
            self.order = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func setStatus(_ order: Order, _ status: OrderStatus) async {
        busy = true
        defer { busy = false }
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: StatusPatch(status: status.rawValue))
            Haptics.success()
            self.order = updated
            error = nil
            await model.refreshBadges()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadBasket(_ order: Order) async {
        guard order.screenshotName != nil, basket == nil else { return }
        guard let payload: AttachmentPayload = try? await model.client().store("attachment", query: ["id": order.id]) else { return }
        if let encoded = payload.jpegBase64, let data = Data(base64Encoded: encoded), let image = UIImage(data: data) {
            basket = image
        }
    }

    @ViewBuilder
    private func handoffForm(_ order: Order) -> some View {
        RequiredLabel(title: "Pickup details", required: true)
        EntryField("Pickup details", text: $detailsText, axis: .vertical)
            .lineLimit(3 ... 8)
            .padding(12)
            .sketchPanel()
        if order.isPersonalPickup {
            Toggle("The item and contact will be ready during this window", isOn: $readyConfirmed)
            Text(order.contactLabel ?? "Add a contact label on the request.")
                .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
        } else {
            RequiredLabel(title: "Name on the order", required: true)
            EntryField("Name on the order", text: $pickupName).padding(12).sketchPanel()
            Toggle("Merchant did not provide one", isOn: $referenceMissing)
            if !referenceMissing {
                RequiredLabel(title: "Order number", required: true)
                EntryField("Order number", text: $orderNumber).padding(12).sketchPanel()
            }
            RequiredLabel(title: "Pickup code", required: false)
            EntryField("Pickup code, if you have one", text: $pickupCode).padding(12).sketchPanel()
            if let website = restaurantURL(order.restaurantWebsite) {
                Link("Merchant website", destination: website).font(Theme.text(.body, weight: .semibold))
            }
        }
        Picker("Pickup window", selection: $windowChoice) {
            Text("30 minutes before departure").tag("30 minutes before departure")
            Text("When the runner is nearby").tag("When the runner is nearby")
        }
        EntryField("Collection instructions", text: $instructions, axis: .vertical)
            .lineLimit(2 ... 5)
            .padding(12)
            .sketchPanel()
        if order.status != .requested {
            EntryField("Different branch, if this one changed", text: $branchNote).padding(12).sketchPanel()
        }
        PhotosPicker(selection: $handoffPhoto, matching: .images) {
            Text(order.isPersonalPickup ? "Add an item photo" : "Add a confirmation screenshot")
        }
        Text("A screenshot is information you provide. It does not prove payment or that the merchant is ready.")
            .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
        PrimaryButton(title: "Save pickup details", busy: busy) { Task { await saveHandoff(order) } }
    }

    private func saveHandoff(_ order: Order) async {
        guard let tripDeparture = order.trip?.departureAt, let departure = Format.parse(tripDeparture) else {
            error = "This trip has no departure time."
            return
        }
        let ready = windowChoice == "30 minutes before departure" ? departure.addingTimeInterval(-1_800) : departure.addingTimeInterval(-300)
        guard ready > DemoClock.now else {
            error = "That pickup window is already past for this trip."
            return
        }
        var image: String?
        if let handoffPhoto, let data = try? await handoffPhoto.loadTransferable(type: Data.self), let picture = UIImage(data: data) {
            image = picture.jpegData(compressionQuality: 0.72)?.base64EncodedString()
        }
        busy = true
        defer { busy = false }
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: HandoffSubmit(
                requestText: detailsText.isEmpty ? (order.itemSummary ?? "") : detailsText,
                pickupName: pickupName,
                restaurantOrderNumber: referenceMissing ? nil : orderNumber,
                referenceMissing: referenceMissing,
                pickupWindow: windowChoice,
                pickupReadyAt: ISO8601DateFormatter().string(from: ready),
                pickupCode: pickupCode.isEmpty ? nil : pickupCode,
                pickupInstructions: instructions.isEmpty ? nil : instructions,
                readyConfirmed: order.isPersonalPickup ? readyConfirmed : nil,
                contactLabel: order.contactLabel,
                accessInstructions: order.accessInstructions,
                screenshotBase64: image,
                removeScreenshot: false,
                branchNote: branchNote.isEmpty ? nil : branchNote
            ))
            self.order = updated
            editingHandoff = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func markReviewed(_ order: Order) async {
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: DetailsDecision(detailsDecision: "received"))
            self.order = updated
        } catch { self.error = error.localizedDescription }
    }

    private func decideWindow(_ order: Order, _ decision: String) async {
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: WindowDecision(windowDecision: decision))
            self.order = updated
        } catch { self.error = error.localizedDescription }
    }

    private func decidePlace(_ order: Order) async {
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: PlaceDecision(placeDecision: "accept"))
            self.order = updated
        } catch { self.error = error.localizedDescription }
    }

    private func collect(_ order: Order) async {
        busy = true
        defer { busy = false }
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: CollectionPatch(status: OrderStatus.pickedUp.rawValue, collectionConfirmed: true))
            Haptics.success()
            self.order = updated
        } catch { self.error = error.localizedDescription }
    }

    private func recordPurchase(_ order: Order) async {
        let cleaned = actualAmount.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decimal = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else {
            error = "Enter the actual merchandise total."
            return
        }
        var cents = decimal * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &cents, 0, .plain)
        let value = (rounded as NSDecimalNumber).intValue
        guard value >= 0 else { error = "Enter the actual merchandise total."; return }
        busy = true
        defer { busy = false }
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: PurchasePatch(purchaseActualCents: value, purchaseReference: orderNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : orderNumber))
            Haptics.success()
            self.order = updated
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func revise(_ order: Order, _ decision: String) async {
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: RevisionDecision(revisionDecision: decision))
            self.order = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static func ledgerTitle(_ kind: String) -> String {
        switch kind {
        case "earning": return "Runner delivery earning"
        case "merchandise-reimburse": return "Merchandise reimbursement"
        case "platform-share": return "Platform delivery share"
        case "merchandise-refund": return "Merchandise difference"
        case "merchandise-unrefunded": return "Merchandise not refunded"
        case "delivery-refund", "refund": return "Delivery refund"
        case "delivery-capture", "capture": return "Delivery captured"
        case "merchandise-capture": return "Merchandise captured"
        default: return kind.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
}

struct RouteMap: View {
    var path: [[Double]]
    var body: some View {
        Group {
            if GoogleMapsStartup.isReady {
                GoogleRouteMap(path: path)
            } else {
                appleMap
            }
        }
        .frame(height: 220)
        .mapFrame()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map of the delivery route")
    }

    private var appleMap: some View {
        Map {
            let coordinates = path.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count == 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
            }
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates).stroke(Theme.maroon, lineWidth: 4)
            }
            ForEach(Array(coordinates.enumerated()), id: \.offset) { item in
                Marker("", coordinate: item.element)
            }
        }
    }
}

private extension OrderDetailView {
    var routeCaption: String {
        guard routePath != nil else {
            return "Straight line between the posted stops. A driving route wasn't available, and this is not live tracking."
        }
        if GoogleMapsStartup.isReady {
            if routeSource == "google" {
                return "Driving route. Google Maps provides this map. This is not live tracking."
            }
            return "Google Maps provides this map. The road measurement is a separate estimate, and this is not live tracking."
        }
        return "Driving route. Apple Maps provides this map. This is not live tracking."
    }
}
