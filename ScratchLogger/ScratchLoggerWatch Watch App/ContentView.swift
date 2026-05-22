import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "scribble.variable")
                .imageScale(.large)
            Text("Scratch Logger")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
