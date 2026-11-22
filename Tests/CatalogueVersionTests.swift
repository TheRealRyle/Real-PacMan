import Testing
import Foundation
@testable import ParcoursCore

struct CatalogueVersionTests {
    @Test("An old cached catalogue cannot hide newer bundled gameplay modes")
    func oldCache() throws {
        let bundled = try ParcoursCatalogue.loadVerney(bundle: .module)
        let old = GameRoute(id: bundled.id, name: "Old cached version", version: 1,
                            coordinates: bundled.coordinates, pellets: bundled.pellets,
                            mapStyleURL: bundled.mapStyleURL)
        let entries = ParcoursCatalogue.entries(saved: [old], prototype: bundled)
        #expect(entries.first?.route == bundled)
    }

    @Test("A newer server version still replaces bundled data")
    func newerServer() throws {
        let bundled = try ParcoursCatalogue.loadVerney(bundle: .module)
        let newer = GameRoute(id: bundled.id, name: "New server version", version: bundled.version + 1,
                              coordinates: bundled.coordinates, pellets: bundled.pellets,
                              mapStyleURL: bundled.mapStyleURL)
        #expect(ParcoursCatalogue.entries(saved: [newer], prototype: bundled).first?.route == newer)
    }
}
