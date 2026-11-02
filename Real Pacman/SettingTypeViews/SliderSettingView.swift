import SwiftUI

struct SliderSettingView: View {
    let name: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text(name)
            Slider(value: $value, in: 0...1) { Text(name) }
        }
    }
}
