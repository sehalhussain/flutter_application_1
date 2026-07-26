import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // ═══════════════════════════════════════════════════════════════════════
    // CRITICAL: Set UNUserNotificationCenter delegate
    // This is REQUIRED for:
    // 1. Showing notifications when app is in foreground
    // 2. Handling notification action button taps
    // 3. Receiving notifications when app is terminated
    // ═══════════════════════════════════════════════════════════════════════
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MARK: - UNUserNotificationCenterDelegate
  // These methods handle notification interactions
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Called when app is in foreground and a notification is delivered
  /// Without this, notifications won't show when user is using the app
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show notification even when app is in foreground
    // Options: .banner, .sound, .badge, .list
    completionHandler([.banner, .sound, .badge, .list])
  }
  
  /// Called when user taps on notification OR taps an action button
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // Handle action button taps
    let actionId = response.actionIdentifier
    
    if actionId == "mark_prayed" {
      // The Flutter plugin will handle this via its own delegate setup
      // This method just ensures the app wakes up properly
      print("Notification action: Mark as Prayed")
    } else if actionId == "dismiss" {
      print("Notification action: Dismiss")
    } else if actionId == UNNotificationDefaultActionIdentifier {
      // User tapped the notification body
      print("Notification tapped: \(response.notification.request.content.body)")
    }
    
    // Call super to let Flutter handle the payload
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}