import SwiftUI
import AppKit

struct NotchView<Content: View>: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @EnvironmentObject var settings: SettingsManager
    @State private var expanded = false
    @State private var notchSize: CGSize? = nil
    
    // Dynamic content that can be any SwiftUI view
    let content: Content
    
    // Initializer that accepts any view content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let collapsedWidth = (notchSize?.width ?? 180) + 100
        let collapsedHeight = (notchSize?.height ?? 32) + 6
        
        return NotchShape(
            topCornerRadius: expanded ? 22 : 12,
            bottomCornerRadius: expanded ? 22 : 12
        )
        .fill(expanded ? settings.notchColor : (musicManager.isPlaying ? settings.notchColor : .clear))
        .frame(
            width: expanded ? nil : collapsedWidth,
            height: expanded ? nil : collapsedHeight
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: collapsedWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .topLeading) {
            // Expanded content — scales + fades in from the notch (anchored
            // at top, where the physical notch is), not a plain fade, so it
            // reads as growing out of the notch rather than materializing.
            content
                .padding(.vertical)
                .padding(.horizontal, 35)
                .opacity(expanded ? 1 : 0) // Hide content when collapsed
                .scaleEffect(expanded ? 1 : 0.6, anchor: .top)
        }
        .overlay(alignment: .top) {
            // Collapsed content: artwork and spectrum positioned at top of notch
            if settings.isOverflowNotchWhenPlaying {
                if !expanded && musicManager.isPlaying {
                    HStack{
                        // Artwork on the left
                        Group {
                            if let artwork = musicManager.artwork {
                                Image(nsImage: artwork)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                            } else {
                                Image("apple_music")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                                    .animation(.bouncy,value: musicManager.isPlaying)
                            }
                        }
                        .frame(width: 24, height: 24)
                        .cornerRadius(3)
                        .clipped()
                        Spacer()
                        
                        // Audio spectrum on the right
                        AudioSpectrumView(isPlaying: musicManager.isPlaying)
                    }
                    
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(width: collapsedWidth, alignment: .top)
                    .overlay(
                        Group {
                            if settings.isNotchBorder {
                                NotchShape(
                                    topCornerRadius: expanded ? 22 : 12,
                                    bottomCornerRadius: expanded ? 22 : 12
                                )
                                .stroke(settings.NotchBorderColor, lineWidth: 2)
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    .opacity(expanded ? 0 : 1)
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.6, blendDuration: 0), value: musicManager.isPlaying)
        .clipShape(NotchShape(
            topCornerRadius: expanded ? 22 : 12,
            bottomCornerRadius: expanded ? 22 : 12
        ))
        .onAppear {
            if let screen = NSScreen.main {
                notchSize = screen.notchSize
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotchExpanded"))) { notification in
            if let isExpanded = notification.object as? Bool {
                // Matches NotchWindowController's window-frame timing (0.32s
                // overshoot-bounce open / 0.2s crisp close): real spring
                // bounce opening (low damping), fast and bounce-free closing.
                let expandSpring = Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
                let collapseSpring = Animation.spring(response: 0.22, dampingFraction: 0.85, blendDuration: 0)
                withAnimation(isExpanded ? expandSpring : collapseSpring) {
                    expanded = isExpanded
                }
            }
        }
    }
}

#Preview {
    NotchView {
        // Example content - you can put any view here!
        VStack(spacing: 8) {
            Text("Notch Content")
                .foregroundColor(.white)
                .font(.headline)
            Text("Customize me!")
                .foregroundColor(.gray)
                .font(.caption)
        }
    }
}
