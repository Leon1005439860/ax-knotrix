import SwiftUI

struct ContentView: View {
    private let urlString = "http://192.168.118.157:5173/llk-webapp"
    //private let urlString = "https://sit-k-library.accentrix.com/llk-webapp/"
    
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
