import SwiftUI

struct ContentView: View {
    private let urlString = "https://sit-k-library.accentrix.com/llk-webapp/"
    
    var body: some View {
        WebView(urlString: urlString)
            .ignoresSafeArea()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
