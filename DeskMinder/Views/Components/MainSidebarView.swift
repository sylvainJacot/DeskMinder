import SwiftUI

struct MainSidebarView: View {
    @ObservedObject var scanner: DesktopScanner
    @Binding var thresholdValue: Double
    @Binding var thresholdUnit: ContentView.ThresholdUnit
    @Binding var autoCleanEnabled: Bool
    
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
                let copy = scoreCopy(for: score.level)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        Text(score.percentageFormatted)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(scoreAccentColor(for: score))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(copy.title)
                                .font(.headline)
                            Text(copy.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    Text(scoreMiniStatsText(for: score))
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
            sectionTitle("Statistics")
            
            statRow(label: "Files to review", value: "\(scanner.items.count)")
            statRow(label: "Selected", value: "\(scanner.selectedItems.count)")
            statRow(label: "Ignored", value: "\(scanner.ignoredItems.count)")
            statRow(label: "Total size", value: scanner.formattedTotalSize)
            statRow(label: "Oldest file", value: oldestFileStatText)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Quick Actions")
            
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
            
            Button {
                _ = scanner.moveSelectionToRecommendedFolder()
            } label: {
                actionButtonLabel(
                    title: "Move to Recommended Folder",
                    subtitle: "Moves the selected files to \"DeskMinder - Tri\" in your Documents.",
                    systemImage: "folder.badge.gearshape"
                )
            }
            .buttonStyle(.plain)
            .disabled(scanner.selectedItems.isEmpty)
            
            Button(role: .destructive) {
                _ = scanner.moveSelectedToTrash()
            } label: {
                actionButtonLabel(
                    title: "Move Selected Files to Trash",
                    subtitle: "Deletes the selected files.",
                    systemImage: "trash"
                )
            }
            .buttonStyle(.plain)
            .disabled(scanner.selectedItems.isEmpty)
        }
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Filters & Thresholds")
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Minimum File Age")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                TextField("Value", text: Binding(
                    get: { String(Int(thresholdValue)) },
                    set: { newValue in
                        if let v = Int(newValue) {
                            thresholdValue = Double(v)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                
                Text("Only show files modified at least this long ago.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Picker("Age Unit", selection: $thresholdUnit) {
                    ForEach(ContentView.ThresholdUnit.allCases) { unit in
                        Text(unit.label.capitalized).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
            
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
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func actionButtonLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
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
    
    private func scoreCopy(for level: DeskCleanlinessScore.Level) -> (title: String, description: String) {
        switch level {
        case .good:
            return ("Clean Desktop", "Your desktop looks tidy overall. Enjoy it while it lasts.")
        case .medium:
            return ("Needs Attention", "Some files are piling up. A quick tidy from time to time will keep it under control.")
        case .bad:
            return ("Cluttered Desktop", "Your desktop is heavily cluttered and packed with old files. It's the right moment to tidy up.")
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
