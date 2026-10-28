import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    private var wasInBackground = false

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Main.storyboard creates the initial ViewController
        // and UIWindow automatically.
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when the scene is released.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene becomes active.
        
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene becomes inactive.
        
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        guard !wasInBackground,
              let controller = window?.rootViewController as? ViewController else { return }
        
        controller.server.stopServer()
        wasInBackground = true
        
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        guard wasInBackground,
              let controller = window?.rootViewController as? ViewController else {return}
        
        controller.server.restartServer()
        wasInBackground = false
        
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
}
