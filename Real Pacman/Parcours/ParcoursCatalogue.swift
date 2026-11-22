import Foundation

enum ParcoursCatalogue {
    static let verneyID = UUID(uuidString: "7DAB402C-797E-4B41-A47D-54D01D1CF361")!

    static func loadVerney(bundle: Bundle = .main) throws -> GameRoute {
        guard let url = bundle.url(forResource: "verney-draft", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let route = try JSONDecoder().decode(GameRoute.self, from: Data(contentsOf: url))
        try route.validate()
        return route
    }

    static func entries(saved: [GameRoute], prototype: GameRoute?) -> [ParcoursCandidate] {
        let cachedVerney = saved.filter { $0.id == verneyID }.max { $0.version < $1.version }
        let verney: GameRoute?
        if let prototype, prototype.version > (cachedVerney?.version ?? 0) {
            verney = prototype
        } else {
            verney = cachedVerney ?? prototype
        }
        var entries = [
            ParcoursCandidate(id: verneyID, name: "Parc du Verney",
                              description: "Chambéry · first map prototype", route: verney),
            ParcoursCandidate(id: UUID(uuidString: "3535FF91-781D-4C5E-BA14-3419263CD253")!,
                              name: "Chambéry Station",
                              description: "Planned location · walking network not defined yet", route: nil),
            ParcoursCandidate(id: UUID(uuidString: "F20825EE-3A11-451D-9008-C478B633F717")!,
                              name: "USMB · Le Bourget-du-Lac",
                              description: "Planned location · walking network not defined yet", route: nil)
        ]
        entries = entries.map { entry in
            guard let route = saved.filter({ $0.id == entry.id }).max(by: { $0.version < $1.version }),
                  route.version >= (entry.route?.version ?? 0) else { return entry }
            return ParcoursCandidate(id: route.id, name: route.name,
                                     description: route.parcours?.description ?? "Saved parcours", route: route)
        }
        let reserved = Set(entries.map(\.id))
        entries += saved.filter { !reserved.contains($0.id) }.map {
            ParcoursCandidate(id: $0.id, name: $0.name,
                              description: $0.parcours?.description ?? "Saved parcours", route: $0)
        }
        return entries
    }
}
