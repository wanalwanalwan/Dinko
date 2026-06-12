import Foundation

enum DrillCatalogLoader {
    static func loadAll() -> [CatalogDrill] {
        guard let url = Bundle.main.url(forResource: "drill_catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let drills = try? JSONDecoder().decode([CatalogDrill].self, from: data) else {
            return []
        }
        return drills
    }
}
