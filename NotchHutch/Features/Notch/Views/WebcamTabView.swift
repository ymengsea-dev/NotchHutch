import SwiftUI

struct WebcamTabView: View {
    var body: some View {
        NotchCameraView(width: nil, height: nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

