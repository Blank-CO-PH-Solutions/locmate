import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Google Maps SDK key for iOS. Create one in the Google Cloud Console
  // (Maps SDK for iOS, restricted to this bundle id) and paste it here, or
  // leave the placeholder and the map shows an authorization notice.
  // See README.md → "Google Maps".
  private let googleMapsApiKey = "YOUR_GOOGLE_MAPS_API_KEY"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey(googleMapsApiKey)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
