import Foundation

/// Each tap is a new request, including repeated requests for the same camera target.
struct RouteMapCameraRequest {
    enum Target {
        case player
        case parcours
        case savedZoom
    }

    let id = UUID()
    let target: Target
}
