import Foundation

/// Représente l'indice de propreté calculé à partir du bureau.
/// Pour ajuster l'impact de chaque critère, il suffit de modifier les pondérations
/// appliquées dans l'initialiseur (sections surcharge, anciens fichiers, âge moyen).
struct DeskCleanlinessScore: Equatable {
    let fileCount: Int
    let oldFileCount: Int
    let averageAge: Double
    let score: Int
    
    init(fileCount: Int, oldFileCount: Int, averageAge: Double) {
        self.fileCount = fileCount
        self.oldFileCount = oldFileCount
        self.averageAge = averageAge
        
        var computedScore = 100
        let hasOldFiles = oldFileCount > 0
        
        if hasOldFiles {
            computedScore -= min(fileCount * 2, 30)            // surcharge : max -30
            computedScore -= min(Int(averageAge * 1.2), 30)    // âge moyen élevé : max -30
        }
        
        computedScore -= min(oldFileCount * 3, 40)             // fichiers anciens : max -40
        computedScore = max(0, computedScore)
        self.score = computedScore
    }
    
    /// Fournit une valeur réaliste pour les aperçus SwiftUI.
    static func mock() -> DeskCleanlinessScore {
        DeskCleanlinessScore(fileCount: 24, oldFileCount: 12, averageAge: 18.5)
    }
}

extension DeskCleanlinessScore {
    var formattedAverageAge: String {
        if averageAge.isNaN || averageAge.isInfinite {
            return "0"
        }
        
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = averageAge < 10 ? 1 : 0
        return formatter.string(from: NSNumber(value: averageAge)) ?? String(format: "%.1f", averageAge)
    }
    
    var percentageFormatted: String {
        "\(score)%"
    }
    
    var qualitativeLabel: String {
        switch score {
        case 80...100:
            return "Propre"
        case 50..<80:
            return "À ranger"
        default:
            return "Très encombré"
        }
    }
    
    var localizedDescription: String {
        switch score {
        case 80...100:
            return "Votre bureau est sous contrôle. Continuez ainsi !"
        case 50..<80:
            return "Quelques fichiers méritent un coup d'œil."
        default:
            return "Un tri s'impose pour retrouver de l'espace."
        }
    }
}
