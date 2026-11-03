package com.gift360.gift360

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.gift360.gift360/biometric"
    private val keyAlias = "gift360.biometric.login.rsa"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "availability" -> result.success(availability())
                    "hasKey" -> result.success(hasUsableKey())
                    "createKeyPair" -> createKeyPair(result)
                    "signChallenge" -> signChallenge(call.argument<String>("challenge"), result)
                    "deleteKey" -> {
                        loadKeyStore().deleteEntry(keyAlias)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun availability(): Map<String, Any> {
        val manager = BiometricManager.from(this)
        return when (manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS ->
                mapOf("supported" to true, "enrolled" to true)
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ->
                mapOf("supported" to true, "enrolled" to false, "reason" to "Set up a strong biometric on this device to enable biometric login.")
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE ->
                mapOf("supported" to false, "enrolled" to false, "reason" to "This device has no supported biometric hardware.")
            else ->
                mapOf("supported" to false, "enrolled" to false, "reason" to "Strong biometric authentication is unavailable. Use OTP login instead.")
        }
    }

    private fun createKeyPair(result: MethodChannel.Result) {
        val keyStore = try {
            loadKeyStore()
        } catch (_: Exception) {
            result.error("biometric_unavailable", "Could not access Android Keystore.", null)
            return
        }
        try {
            if (keyStore.containsAlias(keyAlias)) {
                result.error("key_invalidated", "An existing protected biometric key has no matching enrollment.", null)
                return
            }
            val generator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_RSA,
                "AndroidKeyStore"
            )
            val spec = KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_SIGN
            )
                .setKeySize(2048)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                spec.setUserAuthenticationParameters(
                    0,
                    KeyProperties.AUTH_BIOMETRIC_STRONG
                )
            } else {
                @Suppress("DEPRECATION")
                spec.setUserAuthenticationValidityDurationSeconds(0)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                spec.setInvalidatedByBiometricEnrollment(true)
            }
            generator.initialize(spec.build())
            val keyPair = generator.generateKeyPair()
            val keyInfo = java.security.KeyFactory
                .getInstance(keyPair.private.algorithm, "AndroidKeyStore")
                .getKeySpec(keyPair.private, KeyInfo::class.java)
            if (!keyInfo.isInsideSecureHardware) {
                keyStore.deleteEntry(keyAlias)
                result.error("biometric_unavailable", "This device cannot protect the biometric signing key in secure hardware.", null)
                return
            }
            result.success(Base64.encodeToString(keyPair.public.encoded, Base64.NO_WRAP))
        } catch (_: Exception) {
            try {
                keyStore.deleteEntry(keyAlias)
            } catch (_: Exception) {
                result.error("biometric_unavailable", "Could not clean up the temporary biometric key.", null)
                return
            }
            result.error("biometric_unavailable", "Could not create a hardware-protected biometric key.", null)
        }
    }

    private fun hasUsableKey(): Boolean {
        val keyStore = loadKeyStore()
        if (!keyStore.containsAlias(keyAlias)) return false
        return try {
            val privateKey = keyStore.getKey(keyAlias, null) as? java.security.PrivateKey
                ?: return false
            val keyInfo = java.security.KeyFactory
                .getInstance(privateKey.algorithm, "AndroidKeyStore")
                .getKeySpec(privateKey, KeyInfo::class.java)
            keyInfo.isInsideSecureHardware
        } catch (_: KeyPermanentlyInvalidatedException) {
            false
        } catch (_: java.security.UnrecoverableKeyException) {
            false
        } catch (_: java.security.InvalidKeyException) {
            false
        }
    }

    private fun signChallenge(challenge: String?, result: MethodChannel.Result) {
        if (challenge == null) {
            result.error("invalid_argument", "A biometric challenge is required.", null)
            return
        }
        try {
            val keyStore = loadKeyStore()
            if (!keyStore.containsAlias(keyAlias)) {
                result.error("key_missing", "The protected biometric key is missing.", null)
                return
            }
            val privateKey = keyStore.getKey(keyAlias, null) as? java.security.PrivateKey
                ?: run {
                    result.error("key_missing", "The protected biometric key is missing.", null)
                    return
                }
            val signature = Signature.getInstance("SHA256withRSA")
            signature.initSign(privateKey)
            val prompt = BiometricPrompt(
                this,
                ContextCompat.getMainExecutor(this),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authenticationResult: BiometricPrompt.AuthenticationResult
                    ) {
                        try {
                            val authorizedSignature = authenticationResult.cryptoObject?.signature
                                ?: throw IllegalStateException("Missing authorized signature")
                            authorizedSignature.update(challenge.toByteArray(Charsets.UTF_8))
                            val signed = authorizedSignature.sign()
                            result.success(Base64.encodeToString(signed, Base64.NO_WRAP))
                        } catch (_: Exception) {
                            result.error("key_invalidated", "The protected biometric key could not sign this challenge. Sign in with OTP and enroll again.", null)
                        }
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        when (errorCode) {
                            BiometricPrompt.ERROR_USER_CANCELED,
                            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                            BiometricPrompt.ERROR_CANCELED ->
                                result.error("biometric_cancelled", "Biometric authentication was cancelled.", null)
                            BiometricPrompt.ERROR_LOCKOUT,
                            BiometricPrompt.ERROR_LOCKOUT_PERMANENT ->
                                result.error("biometric_lockout", "Biometrics are temporarily locked. Unlock your device and try again.", null)
                            else ->
                                result.error("biometric_unavailable", "Biometric authentication failed. Use OTP login instead.", null)
                        }
                    }
                }
            )
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Verify to log in")
                .setSubtitle("Use your device biometric to sign in securely")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText("Cancel")
                .build()
            prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(signature))
        } catch (_: KeyPermanentlyInvalidatedException) {
            result.error("key_invalidated", "The biometric key was invalidated. Sign in with OTP and enroll again.", null)
        } catch (_: java.security.UnrecoverableKeyException) {
            result.error("key_invalidated", "The biometric key was invalidated. Sign in with OTP and enroll again.", null)
        } catch (_: Exception) {
            result.error("biometric_unavailable", "Could not start biometric authentication. Use OTP login instead.", null)
        }
    }

    private fun loadKeyStore(): KeyStore =
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
}
