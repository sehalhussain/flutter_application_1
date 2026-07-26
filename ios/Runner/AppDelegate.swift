import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // CRITICAL: Set UNUserNotificationCenter delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  
  /// Called when app is in foreground and a notification is delivered
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // FIX: Use .alert instead of .banner, and drop .list for iOS 12/13 compatibility
    completionHandler([.alert, .sound, .badge])
  }
  
  /// Called when user taps on notification OR taps an action button
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let actionId = response.actionIdentifier
    
    if actionId == "mark_prayed" {
      print("Notification action: Mark as Prayed")
    } else if actionId == "dismiss" {
      print("Notification action: Dismiss")
    } else if actionId == UNNotificationDefaultActionIdentifier {
      print("Notification tapped: \(response.notification.request.content.body)")
    }
    
    // Call super to let Flutter handle the payload
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}