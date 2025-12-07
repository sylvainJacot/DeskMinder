import Foundation

struct DeskCleanlinessScore: Equatable {
    let fileCount: Int
    let oldFileCount: Int
    let averageAge: Double
    let score: Int
    
    enum Level {
        case good
        case medium
        case bad
    }
    
    init(fileCount: Int, oldFileCount: Int, averageAge: Double, score: Int) {
        self.fileCount = fileCount
        self.oldFileCount = oldFileCount
        self.averageAge = averageAge
        self.score = max(0, min(score, 100))
    }
    
    init(fileCount: Int, oldFileCount: Int, averageAge: Double) {
        self.init(
            fileCount: fileCount,
            oldFileCount: oldFileCount,
            averageAge: averageAge,
            score: DeskCleanlinessScore.computeScore(
                fileCount: fileCount,
                oldFileCount: oldFileCount,
                averageAge: averageAge
            )
        )
    }
    
    var level: Level {
        if score >= 80,
           oldFileCount <= 5,
           averageAge <= 14 {
            return .good
        }
        
        let oldFileRatio = fileCount > 0 ? Double(oldFileCount) / Double(fileCount) : 0
        
        if score < 30
            || oldFileRatio >= 0.85
            || averageAge >= 90 {
            return .bad
        }
        
        return .medium
    }
    
    /// Provides a realistic value for SwiftUI previews.
    static func mock() -> DeskCleanlinessScore {
        DeskCleanlinessScore(
            fileCount: 24,
            oldFileCount: 12,
            averageAge: 18.5,
            score: DeskCleanlinessScore.computeScore(fileCount: 24, oldFileCount: 12, averageAge: 18.5)
        )
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
        switch level {
        case .good:
            return "Clean Desktop"
        case .medium:
            return "Needs Attention"
        case .bad:
            return "Cluttered Desktop"
        }
    }
    
    var localizedDescription: String {
        switch level {
        case .good:
            return "Your desktop looks tidy overall and nothing seems urgent."
        case .medium:
            return "Your desktop is starting to fill up. Consider a quick cleanup."
        case .bad:
            return "Your desktop is heavily cluttered and packed with old files. It's time to tidy up."
        }
    }
    
    static func computeScore(fileCount: Int, oldFileCount: Int, averageAge: Double) -> Int {
        var computedScore = 100
        let hasOldFiles = oldFileCount > 0
        
        if hasOldFiles {
            computedScore -= min(fileCount * 2, 30)            // clutter penalty: max -30
            computedScore -= min(Int(averageAge * 1.2), 30)    // high average age penalty: max -30
        }
        
        computedScore -= min(oldFileCount * 3, 40)             // old files: max -40
        return max(0, min(computedScore, 100))
    }
}
