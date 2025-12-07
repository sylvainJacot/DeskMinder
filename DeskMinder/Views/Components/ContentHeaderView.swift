import SwiftUI

struct ContentHeaderView: View {
    @ObservedObject var scanner: DesktopScanner
    @Binding var thresholdValue: Int
    @Binding var thresholdUnit: ContentView.ThresholdUnit
    var onThresholdChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleRow
            thresholdControls
            sortRow
            if let score = scanner.cleanlinessScore {
                cleanlinessCard(for: score)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("DeskMinder")
                .font(.title3)
                .fontWeight(.semibold)
            
            if !scanner.items.isEmpty {
                Text("\(scanner.items.count) \(scanner.items.count == 1 ? "file" : "files") to clean")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                scanner.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }
    
    private var thresholdControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("When should a file be considered old?")
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 8) {
                Text("After")
                
                TextField("", value: $thresholdValue, formatter: NumberFormatter())
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: thresholdValue) { _ in
                        onThresholdChange()
                    }
                
                Picker("", selection: $thresholdUnit) {
                    ForEach(ContentView.ThresholdUnit.allCases) { unit in
                        Text(unit.label.capitalized).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: thresholdUnit) { _ in
                    onThresholdChange()
                }
                
                Spacer()
            }
            
            Text("Files that have been on the desktop for more than \(thresholdUnit.formatted(thresholdValue)) will be suggested for cleanup.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
    }
    
    private var sortRow: some View {
        HStack(spacing: 12) {
            Text("Active filters: age ≥ \(thresholdUnit.formatted(thresholdValue))")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func cleanlinessCard(for score: DeskCleanlinessScore) -> some View {
        let accentColor = cleanlinessAccentColor(for: score.score)
        
        HStack {
            VStack(alignment: .leading) {
                Text("Desktop cleanliness index:")
                    .font(.headline)
                    .padding(3)
                Text("\(score.score)/100")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
                ProgressView(value: Double(score.score), total: 100)
                    .tint(accentColor)
            }
            
            VStack(alignment: .leading) {
                Text(fileCountLabel(score.fileCount))
                Spacer()
                Text(oldFileCountLabel(score.oldFileCount))
                Spacer()
                Text("Average age: \(score.formattedAverageAge) days")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    private func cleanlinessAccentColor(for score: Int) -> Color {
        switch score {
        case 80...100:
            return .green
        case 50..<80:
            return .orange
        default:
            return .red
        }
    }
    
    private func fileCountLabel(_ count: Int) -> String {
        count > 1 ? "\(count) files" : "\(count) file"
    }
    
    private func oldFileCountLabel(_ count: Int) -> String {
        count > 1 ? "\(count) old files" : "\(count) old file"
    }
}
