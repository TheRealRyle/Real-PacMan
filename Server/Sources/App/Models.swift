import Fluent
import Vapor

final class RouteVersion: Model, @unchecked Sendable {
    static let schema = "route_versions"
    @ID(key: .id) var id: UUID?
    @Field(key: "route_id") var routeID: UUID
    @Field(key: "version") var version: Int
    @Field(key: "payload") var payload: String
    init() {}
    init(route: RoutePayload) throws {
        routeID = route.id
        version = route.version
        payload = String(decoding: try JSONEncoder().encode(route), as: UTF8.self)
    }
    func route() throws -> RoutePayload { try JSONDecoder().decode(RoutePayload.self, from: Data(payload.utf8)) }
}

final class StoredResult: Model, @unchecked Sendable {
    static let schema = "results"
    @ID(custom: "id", generatedBy: .user) var id: UUID?
    @Parent(key: "route_version_id") var routeVersion: RouteVersion
    @Field(key: "payload") var payload: String
    @Field(key: "score") var score: Int
    @OptionalField(key: "player_id") var playerID: UUID?
    init() {}
    init(id: UUID, routeVersionID: UUID, payload: String, score: Int) {
        self.id = id
        $routeVersion.id = routeVersionID
        self.payload = payload
        self.score = score
    }
}
