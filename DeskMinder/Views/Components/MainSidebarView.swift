import SwiftUI

struct MainSidebarView: View {
    @ObservedObject var scanner: DesktopScanner
    @Binding var thresholdValue: Double
    @Binding var thresholdUnit: ContentView.ThresholdUnit
    @Binding var autoCleanEnabled: Bool
    @State private var showConfirmMoveAllToTrash: Bool = false
    @State private var showConfirmMoveSelectedToTrash: Bool = false
    
    private let sliderRange = Double(DesktopScanner.allowedDaysRange.lowerBound)...Double(DesktopScanner.allowedDaysRange.upperBound)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sidebarHeaderSection
                Divider()
                
                statsSection
                Divider()
                
                quickActionsSection
                Divider()
                
                filtersSection
                // Divider()
                
                // automationSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .frame(minWidth: 260)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .trailing
        )
    }
    
    // MARK: - Sections
    
    private var sidebarHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DeskMinder")
                .font(.title3)
                .fontWeight(.semibold)
            
            if let score = scanner.currentScore {
                let title = scoreTitle(for: score.level)
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(scanner.items.count)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(scoreAccentColor(for: score))
                        Text("files to clean")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(score.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider().padding(.vertical, 6)

                    HStack(spacing: 12) {
                        Label("\(score.fileCount)", systemImage: "doc.on.doc")
                        Label("\(score.oldFileCount) old", systemImage: "clock")
                        Label("avg \(formattedAverageAgeValue(for: score)) d", systemImage: "timer")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } else {
                Text("No recent scan")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Statistics", systemImage: "chart.bar")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .textCase(.uppercase)
            
            statRow(label: "Files to review", value: "\(scanner.items.count)", isBold: true)
            statRow(label: "Selected", value: "\(scanner.selectedItems.count)", isBold: true)
            statRow(label: "Selected size", value: scanner.formattedSelectedTotalSize, isBold: true)
            statRow(label: "Total size", value: scanner.formattedTotalSize, isBold: true)
            statRow(label: "Oldest file", value: oldestFileStatText)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Quick Actions", systemImage: "bolt.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .textCase(.uppercase)
            
            Button {
                scanner.refresh()
            } label: {
                actionButtonLabel(
                    title: "Rescan Desktop",
                    subtitle: "Refreshes the list of files to clean up.",
                    systemImage: "arrow.clockwise"
                )
            }
            .buttonStyle(.plain)
            
            Button(role: .destructive) {
                showConfirmMoveSelectedToTrash = true
            } label: {
                actionButtonLabel(
                    title: "Move Selected Files to Bin",
                    subtitle: "Deletes the selected files.",
                    systemImage: "trash",
                    iconColor: .red,
                    titleColor: .red
                )
            }
            .buttonStyle(.plain)
            .disabled(scanner.selectedItems.isEmpty)
            .confirmationDialog(
                "Confirm move selected files to Bin",
                isPresented: $showConfirmMoveSelectedToTrash,
                titleVisibility: .visible
            ) {
                Button("Move selected files to Bin", role: .destructive) {
                    _ = scanner.moveSelectedToTrash()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to move the selected files to Bin?")
            }

            Button(role: .destructive) {
                showConfirmMoveAllToTrash = true
            } label: {
                actionButtonLabel(
                    title: "Move all Files to Bin",
                    subtitle: "Deletes all files.",
                    systemImage: "trash",
                    iconColor: .red,
                    titleColor: .red
                )
            }
            .buttonStyle(.plain)
            .disabled(scanner.items.isEmpty)
            .confirmationDialog(
                "Confirm move all files to Bin",
                isPresented: $showConfirmMoveAllToTrash,
                titleVisibility: .visible
            ) {
                Button("Move all files to Bin", role: .destructive) {
                    _ = scanner.moveAllToTrash()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to move all files to Bin?")
            }
        }
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Filters & Thresholds", systemImage: "line.3.horizontal.decrease.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.secondary)
                    Text("Minimum file age")
                        .font(.subheadline.weight(.medium))
                }

                HStack(spacing: 12) {
                    TextField("Value", text: Binding(
                        get: { String(Int(thresholdValue)) },
                        set: { newValue in
                            if let v = Int(newValue) {
                                thresholdValue = Double(v)
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)

                    Picker("Unit", selection: $thresholdUnit) {
                        ForEach(ContentView.ThresholdUnit.allCases) { unit in
                            Text(unit.label.capitalized).tag(unit)
                        }
                    }
                    .frame(width: 120)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
            
            Text("Active filters: age ≥ \(thresholdUnit.formatted(Int(thresholdValue)))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // private var automationSection: some View {
    //     VStack(alignment: .leading, spacing: 10) {
    //         sectionTitle("Automation")
            
    //         Toggle(isOn: $autoCleanEnabled) {
    //             VStack(alignment: .leading, spacing: 2) {
    //                 Text("Enable automatic cleanup")
    //                 Text("Prepares upcoming automatic rules (feature in progress).")
    //                     .font(.caption)
    //                     .foregroundColor(.secondary)
    //             }
    //         }
    //         .toggleStyle(.switch)
    //     }
    // }
    
    // MARK: - Helpers
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
    }
    
    private func statRow(label: String, value: String, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.callout)
                .fontWeight(isBold ? .bold : .regular)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func actionButtonLabel(
        title: String,
        subtitle: String,
        systemImage: String,
        iconColor: Color = .accentColor,
        titleColor: Color = .primary
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(titleColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    private func scoreAccentColor(for score: DeskCleanlinessScore) -> Color {
        switch score.level {
        case .good:
            return .green
        case .medium:
            return .orange
        case .bad:
            return .red
        }
    }
    
    private func scoreTitle(for level: DeskCleanlinessScore.Level) -> String {
        switch level {
        case .good:
            return "Clean Desktop"
        case .medium:
            return "Needs Attention"
        case .bad:
            return "Cluttered Desktop"
        }
    }
    
    private func scoreMiniStatsText(for score: DeskCleanlinessScore) -> String {
        let average = formattedAverageAgeValue(for: score)
        return "Files: \(score.fileCount) · Old files: \(score.oldFileCount) · Avg age: \(average) days"
    }
    
    private func formattedAverageAgeValue(for score: DeskCleanlinessScore) -> String {
        let value = score.averageAge.isFinite ? score.averageAge : 0
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
    
    private var oldestFileStatText: String {
        guard let description = scanner.oldestItemAgeDescription else {
            return "—"
        }
        
        if description == "Today" {
            return "Today"
        }
        
        return "\(description) ago"
    }
}
