import SwiftUI

struct MainSidebarView: View {
    @ObservedObject var scanner: DesktopScanner
    @Binding var thresholdValue: Double
    @Binding var thresholdUnit: ContentView.ThresholdUnit
    @Binding var autoCleanEnabled: Bool
    
    private let sliderRange = Double(DesktopScanner.allowedDaysRange.lowerBound)...Double(DesktopScanner.allowedDaysRange.upperBound)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 260)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.98)
        )
    }
    
    // MARK: - Sections
    
    private var sidebarHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Desk Minder")
                .font(.title3)
                .fontWeight(.semibold)
            
            if let score = scanner.currentScore {
                HStack(alignment: .center, spacing: 12) {
                    Text(score.percentageFormatted)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(scoreAccentColor(for: score.score))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(score.qualitativeLabel)
                            .font(.headline)
                        Text(score.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Aucun scan récent")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Statistiques")
            
            statRow(label: "Fichiers à traiter", value: "\(scanner.totalItemsCount)")
            statRow(label: "Sélectionnés", value: "\(scanner.selectedItemsCount)")
            statRow(label: "Ignorés", value: "\(scanner.ignoredItemsCount)")
            statRow(label: "Taille totale", value: scanner.formattedTotalSize)
            statRow(label: "Plus ancien", value: scanner.oldestItemAgeDescription ?? "—")
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Actions rapides")
            
            Button {
                scanner.refresh()
            } label: {
                labelWithIcon("Rescanner le bureau", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            
            Button {
                _ = scanner.moveSelectionToRecommendedFolder()
            } label: {
                labelWithIcon("Déplacer vers le dossier conseillé", systemImage: "folder.badge.gearshape")
            }
            .buttonStyle(.plain)
            .disabled(scanner.selectedItemsCount == 0)
            
            Button(role: .destructive) {
                _ = scanner.moveSelectedToTrash()
            } label: {
                labelWithIcon("Envoyer à la corbeille", systemImage: "trash")
            }
            .buttonStyle(.plain)
            .disabled(scanner.selectedItemsCount == 0)
        }
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Filtres & seuils")
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Âge minimal")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(thresholdValue)) \(thresholdUnit.label)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TextField("Valeur", text: Binding(
    get: { String(Int(thresholdValue)) },
    set: { newValue in
        if let v = Int(newValue) {
            thresholdValue = Double(v)
        }
    }
))
.textFieldStyle(.roundedBorder)
                
                Picker("Unité", selection: $thresholdUnit) {
                    ForEach(ContentView.ThresholdUnit.allCases) { unit in
                        Text(unit.label.capitalized).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Text("Filtres actifs : âge ≥ \(thresholdUnit.formatted(Int(thresholdValue)))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // private var automationSection: some View {
    //     VStack(alignment: .leading, spacing: 10) {
    //         sectionTitle("Automatisation")
            
    //         Toggle(isOn: $autoCleanEnabled) {
    //             VStack(alignment: .leading, spacing: 2) {
    //                 Text("Activer le nettoyage automatique")
    //                 Text("Prépare l'activation de règles automatiques (fonctionnalité à venir).")
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
            .font(.headline)
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
        }
    }
    
    private func labelWithIcon(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.subheadline)
    }
    
    private func scoreAccentColor(for score: Int) -> Color {
        switch score {
        case 80...100:
            return .green
        case 50..<80:
            return .orange
        default:
            return .red
        }
    }
}
