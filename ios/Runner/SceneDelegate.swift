import Flutter
import LocalAuthentication
import Security
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let biometricChannelName = "com.gift360.gift360/biometric"
  private let keyTag = "com.gift360.gift360.biometric.login.rsa"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: biometricChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "biometric_unavailable", message: "Biometric service is unavailable.", details: nil))
        return
      }
      switch call.method {
      case "availability":
        result(self.availability())
      case "hasKey":
        result(self.hasKey())
      case "createKeyPair":
        self.createKeyPair(result: result)
      case "signChallenge":
        guard let arguments = call.arguments as? [String: Any],
              let challenge = arguments["challenge"] as? String else {
          result(FlutterError(code: "invalid_argument", message: "A biometric challenge is required.", details: nil))
          return
        }
        self.signChallenge(challenge, result: result)
      case "deleteKey":
        let status = self.deleteKey()
        if status == errSecSuccess || status == errSecItemNotFound {
          result(nil)
        } else {
          result(FlutterError(code: "key_delete_failed", message: "The protected biometric key could not be removed.", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func availability() -> [String: Any] {
    let context = LAContext()
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
      return ["supported": true, "enrolled": true]
    }
    if let laError = error as? LAError, laError.code == .biometryNotEnrolled {
      return [
        "supported": true,
        "enrolled": false,
        "reason": "Set up Face ID or Touch ID on this device to enable biometric login."
      ]
    }
    return [
      "supported": false,
      "enrolled": false,
      "reason": "Biometric authentication is unavailable. Use OTP login instead."
    ]
  }

  private func createKeyPair(result: @escaping FlutterResult) {
    guard !hasKey() else {
      result(FlutterError(code: "key_invalidated", message: "An existing protected biometric key has no matching enrollment.", details: nil))
      return
    }
    var accessError: Unmanaged<CFError>?
    guard let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
      [.privateKeyUsage, .biometryCurrentSet],
      &accessError
    ) else {
      result(FlutterError(code: "biometric_unavailable", message: "This device cannot create a biometric-protected key.", details: nil))
      return
    }
    let privateAttributes: [String: Any] = [
      kSecAttrIsPermanent as String: true,
      kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
      kSecAttrAccessControl as String: access
    ]
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeySizeInBits as String: 2048,
      kSecPrivateKeyAttrs as String: privateAttributes
    ]
    var keyError: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &keyError) else {
      result(FlutterError(code: "biometric_unavailable", message: "Could not create a protected biometric key.", details: nil))
      return
    }
    guard let publicKey = SecKeyCopyPublicKey(privateKey),
          let publicData = SecKeyCopyExternalRepresentation(publicKey, &keyError) as Data? else {
      let cleanupStatus = deleteKey()
      result(FlutterError(
        code: "biometric_unavailable",
        message: cleanupStatus == errSecSuccess || cleanupStatus == errSecItemNotFound
          ? "Could not export the public biometric key."
          : "Could not export or safely remove the temporary biometric key.",
        details: nil
      ))
      return
    }
    result(x509PublicKey(publicData).base64EncodedString())
  }

  private func signChallenge(_ challenge: String, result: @escaping FlutterResult) {
    let context = LAContext()
    context.localizedReason = "Verify to log in to Gift360"
    context.evaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics,
      localizedReason: context.localizedReason
    ) { [weak self] succeeded, error in
      guard let self else { return }
      guard succeeded else {
        let laError = error as? LAError
        let code: String
        let message: String
        switch laError?.code {
        case .userCancel, .appCancel, .systemCancel:
          code = "biometric_cancelled"
          message = "Biometric authentication was cancelled."
        case .biometryLockout:
          code = "biometric_lockout"
          message = "Biometrics are temporarily locked. Unlock your device and try again."
        default:
          code = "biometric_unavailable"
          message = "Biometric authentication failed. Use OTP login instead."
        }
        DispatchQueue.main.async {
          result(FlutterError(code: code, message: message, details: nil))
        }
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        var key: SecKey?
        var keyError: Unmanaged<CFError>?
        let query: [String: Any] = [
          kSecClass as String: kSecClassKey,
          kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
          kSecAttrApplicationTag as String: self.keyTag.data(using: .utf8)!,
          kSecReturnRef as String: true,
          kSecUseAuthenticationContext as String: context
        ]
        let status = SecItemCopyMatching(query as CFDictionary, &key)
        guard status == errSecSuccess, let privateKey = key else {
          DispatchQueue.main.async {
            result(FlutterError(
              code: status == errSecItemNotFound ? "key_missing" : "key_invalidated",
              message: "The protected biometric key is missing or invalidated. Sign in with OTP and enroll again.",
              details: nil
            ))
          }
          return
        }
        guard let signature = SecKeyCreateSignature(
          privateKey,
          .rsaSignatureMessagePKCS1v15SHA256,
          Data(challenge.utf8) as CFData,
          &keyError
        ) as Data? else {
          DispatchQueue.main.async {
            result(FlutterError(code: "key_invalidated", message: "The protected biometric key could not sign this challenge. Sign in with OTP and enroll again.", details: nil))
          }
          return
        }
        DispatchQueue.main.async {
          result(signature.base64EncodedString())
        }
      }
    }
  }

  private func hasKey() -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
  }

  private func deleteKey() -> OSStatus {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrApplicationTag as String: keyTag.data(using: .utf8)!
    ]
    return SecItemDelete(query as CFDictionary)
  }

  private func x509PublicKey(_ rsaPublicKey: Data) -> Data {
    let algorithmIdentifier = Data([
      0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7,
      0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
    ])
    let bitString = derElement(0x03, Data([0x00]) + rsaPublicKey)
    return derElement(0x30, algorithmIdentifier + bitString)
  }

  private func derElement(_ tag: UInt8, _ content: Data) -> Data {
    var encoded = Data([tag])
    let length = content.count
    if length < 128 {
      encoded.append(UInt8(length))
    } else {
      var value = length
      var bytes: [UInt8] = []
      while value > 0 {
        bytes.insert(UInt8(value & 0xff), at: 0)
        value >>= 8
      }
      encoded.append(0x80 | UInt8(bytes.count))
      encoded.append(contentsOf: bytes)
    }
    encoded.append(content)
    return encoded
  }
}
