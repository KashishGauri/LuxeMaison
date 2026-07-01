import SwiftUI

struct DashboardContent: View {
    let dashboard: SalesAssociateDashboard
    var reminderCount: Int = 0
    let onStartClient: () -> Void
    let onShowAppointments: () -> Void
    var onShowNotifications: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HeaderBar(reminderCount: reminderCount, onTap: onShowNotifications)

                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 18) {
                        MonthlyGoalCard(goal: dashboard.monthlyGoal)
                        WeeklySalesCard(summary: dashboard.weeklySales)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 18) {
                        PriorityQueueCard(items: dashboard.priorityItems)
                        QuickActionsCard(
                            actions: dashboard.quickActions,
                            metrics: dashboard.metrics,
                            onStartClient: onStartClient,
                            onShowAppointments: onShowAppointments
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.hidden)
    }
}

// Header Bar view
private struct HeaderBar: View {
    var reminderCount: Int = 0
    var onTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }

            Spacer()

            // Tapping opens the notifications screen; a badge appears when an
            // appointment is due within the next 15 minutes (matches the push reminder).
            Button(action: onTap) {
                Image(systemName: reminderCount > 0 ? "bell.badge.fill" : "bell")
                    .font(.title3.weight(.semibold))
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.76), in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if reminderCount > 0 {
                            Text("\(reminderCount)")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Color.red, in: Circle())
                                .offset(x: 3, y: -3)
                        }
                    }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.ink)
            .accessibilityLabel(reminderCount > 0 ? "Notifications, \(reminderCount) starting soon" : "Notifications")
        }
    }
}

//Sidebar Navigation Menu
private struct PlaceholderTabContent: View {
    let tab: SalesAssociateTab

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tab.rawValue)
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text("This tab will be built after the Today and Client screens are finalized.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }
}

private struct MonthlyGoalCard: View {
    let goal: SalesGoal

    var body: some View {
        Card {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.title.uppercased())
                        .font(.caption.weight(.black))
                        .tracking(1.4)
                        .foregroundStyle(Theme.muted)

                    Text(goal.percentageText)
                        .font(.system(size: 74, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(goal.detailText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.leading, 8)

                StoreImageView()
                    .frame(width: 235)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .frame(height: 216)
        }
    }
}

private struct StoreImageView: View {
    var body: some View {
        Image("StoreDisplay")
            .resizable()
            .scaledToFill()
            .overlay(alignment: .leading) {
                LinearGradient(
                    colors: [.white.opacity(0.40), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
    }
}

private struct PriorityQueueCard: View {
    let items: [PriorityItem]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SalesSectionHeader(title: "Priority Queue", badge: "\(items.count) open")

                ForEach(items) { item in
                    PriorityRow(item: item)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
        }
    }
}

private struct PriorityRow: View {
    let item: PriorityItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: 44, height: 44)
                .background(Theme.selected, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline.weight(.bold))
                Text(item.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            if let badge = item.badge {
                Text(badge)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Theme.selected, in: Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.muted.opacity(0.72))
            }
        }
        .padding(.vertical, 2)
    }
}

private struct WeeklySalesCard: View {
    let summary: WeeklySalesSummary

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SalesSectionHeader(title: "Weekly Sales", badge: summary.total)

                HStack(spacing: 12) {
                    SummaryTile(value: summary.change, label: summary.comparison)
                    SummaryTile(value: summary.bestDay, label: summary.bestDayLabel)
                }

                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(summary.days) { day in
                        BarColumn(day: day)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, minHeight: 196, alignment: .bottom)
                .background(.white.opacity(0.40), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .frame(height: 342)
        }
    }
}

private struct SummaryTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.title2.weight(.black))
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.line.opacity(0.65), lineWidth: 1)
        )
    }
}

private struct BarColumn: View {
    let day: DailySales

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(day.isBest ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.goldGradient.opacity(0.40)))
                        .frame(height: max(28, proxy.size.height * day.progress))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 132)

            Text(day.day)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.muted)
            Text(day.amount)
                .font(.caption2.weight(.black))
                .foregroundStyle(Theme.gold)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.day), \(day.amount) sales")
    }
}

private struct QuickActionsCard: View {
    let actions: [QuickAction]
    let metrics: [DashboardMetric]
    let onStartClient: () -> Void
    let onShowAppointments: () -> Void

    private let actionColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Actions")
                    .font(.title2.weight(.black))

                LazyVGrid(columns: actionColumns, spacing: 12) {
                    ForEach(actions) { action in
                        ActionButton(action: action) {
                            if action.title == "Start Client" {
                                onStartClient()
                            } else if action.title == "Appointments" {
                                onShowAppointments()
                            }
                        }
                    }
                }

                LazyVGrid(columns: actionColumns, spacing: 12) {
                    ForEach(metrics) { metric in
                        MetricTile(metric: metric)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(height: 436)
        }
    }
}

private struct ActionButton: View {
    let action: QuickAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                Image(systemName: action.icon)
                    .font(.title3.weight(.semibold))
                Text(action.title)
                    .font(.subheadline.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .padding(.horizontal, 8)
            .foregroundStyle(action.isPrimary ? .white : Theme.ink)
            .background(
                action.isPrimary ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(.white.opacity(0.68)),
                in: RoundedRectangle(cornerRadius: 21, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MetricTile: View {
    let metric: DashboardMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(metric.title.uppercased())
                .font(.caption.weight(.black))
                .tracking(1.1)
                .foregroundStyle(Theme.muted)
            Text(metric.value)
                .font(.system(size: 32, weight: .black, design: .rounded))
        }
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .padding(.horizontal, 16)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Theme.line.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct SalesSectionHeader: View {
    let title: String
    let badge: String

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.weight(.black))
            Spacer()
            Text(badge)
                .font(.caption.weight(.black))
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Theme.selected, in: Capsule())
        }
    }
}

