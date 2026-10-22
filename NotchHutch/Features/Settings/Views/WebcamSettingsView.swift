import SwiftUI

struct WebcamSettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    
    var body: some View {
        Form {
            Section {
                VStack {
                    Toggle("Enable Webcam", isOn: Binding(
                        get: { settings.isWebcamEnabled },
                        set: { newValue in
                            settings.isWebcamEnabled = newValue
                        }
                    ))
                    Text("Show webcam in home tab")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Webcam Shape")
                        Spacer()
                        Text(settings.webcamShape.title)
                            .foregroundColor(.secondary)
                    }
                    Picker("", selection: Binding(
                        get: { settings.webcamShape },
                        set: { newValue in
                            // Avoid "Publishing changes from within view updates..."
                            // by deferring the AppStorage write to the next run loop.
                            DispatchQueue.main.async {
                                settings.webcamShape = newValue
                            }
                        }
                    )) {
                        ForEach(WebcamShape.allCases, id: \.self) { shape in
                            Text(shape.title).tag(shape)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            Section {
                VStack {
                    Toggle("Keep Notch Extended When Camera On", isOn: Binding(
                        get: { settings.keepsNotchExpandedWhenCameraOn },
                        set: { newValue in
                            settings.keepsNotchExpandedWhenCameraOn = newValue
                        }
                    ))
                    Text("Keep the notch extended when the webcam is active")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Section {
                VStack {
                    Toggle("Separate Webcam Tab", isOn: Binding(
                        get: { settings.isWebcamTabEnabled },
                        set: { newValue in
                            settings.isWebcamTabEnabled = newValue
                        }
                    ))
                    Text("Show webcam in a separate tab")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
    }
}
