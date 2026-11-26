import SwiftUI

struct PrivacyDetailsView: View {
    var body: some View {
        ArcadePage(title: "PRIVACY", symbol: "hand.raised.fill") {
            ArcadePanel(title: "YOUR WALK, YOUR CHOICE") {
                Text("You can play without an account. Guest results stay on this device until you explicitly assign them to an account for upload.")
                Text("No ads or cross-app tracking are included.")
            }
            ArcadePanel(title: "LOCATION & MAPS") {
                Text("Location is used while gameplay is active to collect nearby pellets and position your character. Pausing or leaving gameplay stops location updates. Background location is not requested.")
                Text("Raw GPS fixes are processed on the device; the game does not upload a GPS movement trace. Uploaded results include the chosen route, collected pellet IDs, distance, start/end times, mode and virtual ghost state. This can reveal where and when you played.")
                Text("Online map requests go to OpenFreeMap and may reveal the viewed map area and network address to its infrastructure. Download maps beforehand for offline play.")
                Link("OpenFreeMap privacy policy", destination: URL(string: "https://openfreemap.org/privacy/")!)
                    .foregroundStyle(.yellow)
            }
            ArcadePanel(title: "ACCOUNTS & RESULTS") {
                Text("Creating an account sends your username and password to the selected server over HTTPS. The server stores a password hash, not the original password. Your player ID links uploaded results to your account.")
                Text("The app stores a 30-day sign-in token in device-only Keychain. It never saves your password. Sign-out clears the local token and attempts to revoke it on the server; offline tokens expire naturally.")
                Text("The default server and database are hosted by Render in Frankfurt. Hosting providers may keep operational logs such as network addresses, request paths and timestamps.")
                Link("Render privacy policy", destination: URL(string: "https://render.com/privacy")!)
                    .foregroundStyle(.yellow)
            }
            ArcadePanel(title: "STORAGE & CONTROL") {
                Text("Routes, walk history, achievements and preferences are stored on this device. Downloaded maps use MapLibre’s local storage. Signing out does not delete walk history or server results.")
                Text("This class project has no in-app password recovery or account-deletion tool. Ask the project author directly about removing server data. Uninstalling removes local app data, but Keychain credentials may remain: sign out first.")
                Text("The free database is scheduled to expire on December 26, 2026. This is a classroom demonstration, not a long-term data-backup service.")
                Text("Updated November 26, 2026").font(.caption)
            }
        }
    }
}
