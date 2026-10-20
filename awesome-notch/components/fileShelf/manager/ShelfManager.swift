import SwiftUI
import Combine

final class ShelfManager: ObservableObject{
    
    static var shared = ShelfManager()
    
    @Published var items: [ShelfItem] = []
    
    // handle drop file
    func handleDrop(providers: [NSItemProvider]){
        for provider in providers{
            // get file url from provider
            _ = provider.loadObject(ofClass: URL.self, completionHandler: { url, error in
                guard let url = url else {return }

                // Thumbnail decode happens here, on the provider's background
                // callback queue — not on the main thread.
                let newItem = ShelfItem(url: url)

                // update ui in main thread
                DispatchQueue.main.async{
                    // add item in the beginning
                    self.items.insert(newItem, at: 0)
                }
            })
        }
    }
    
    // remove file from container
    func remove( _ item: ShelfItem){
        items.removeAll{ $0.id == item.id }
    }
}
