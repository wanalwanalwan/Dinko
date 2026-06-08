import Foundation

final class ProgramTemplateLoader {
    static func loadAll() -> [ProgramTemplate] {
        guard let url = Bundle.main.url(forResource: "curated_programs", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return (try? decoder.decode([ProgramTemplate].self, from: data)) ?? []
    }
}
