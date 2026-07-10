import SwiftUI

struct ContentView: View {
    private let urlString = "https://www.baidu.com"
    
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
