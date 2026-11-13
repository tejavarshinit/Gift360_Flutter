package com.gift360.gift360

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.UserNotAuthenticatedException
import android.util.Base64
import android.util.Log
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.InvalidKeyException
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.UnrecoverableKeyException

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.gift360.gift360/biometric"
    private val keyAlias = "gift360.deviceauth.login.rsa"
    private val legacyBiometricKeyAlias = "gift360.biometric.login.rsa"
    private val deviceCredentialRequestCode = 43117
    private val deviceCredentialValiditySeconds = 30

    private var pendingChallenge: String? = null
    private var pendingSignResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "availability" -> result.success(availability())
                    "hasKey" -> result.success(hasUsableKey())
                    "createKeyPair" -> createKeyPair(result)
                    "signChallenge" -> signChallenge(
                        call.argument<String>("challenge"),
                        call.argument<String>("method"),
                        result
                    )
                    "deleteKey" -> {
                        deleteAlias(keyAlias)
                        deleteAlias(legacyBiometricKeyAlias)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gift360/device_id"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getAndroidId") {
                result.success(
                    Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID
                    )
                )
            } else {
                result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != deviceCredentialRequestCode) return
        val challenge = pendingChallenge
        val result = pendingSignResult
        pendingChallenge = null
        pendingSignResult = null
        if (challenge == null || result == null) return
        if (resultCode == RESULT_OK) {
            signWithStoredKey(challenge, result)
        } else {
            result.error(
                "device_credential_cancelled",
                "Device unlock was cancelled.",
                null
            )
        }
    }

    private fun availability(): Map<String, Any> {
        val deviceSecure = isDeviceSecure()
        val biometricAvailable = isBiometricAvailable()
        if (!deviceSecure) {
            return mapOf(
                "supported" to false,
                "enrolled" to false,
                "biometricAvailable" to biometricAvailable,
                "credentialAvailable" to false,
                "reason" to "Set up a screen lock (PIN, pattern or password) on this device to enable device-lock login."
            )
        }
        return mapOf(
            "supported" to true,
            "enrolled" to true,
            "biometricAvailable" to biometricAvailable,
            "credentialAvailable" to true
        )
    }

    private fun isBiometricAvailable(): Boolean {
        return try {
            BiometricManager.from(this)
                .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
                BiometricManager.BIOMETRIC_SUCCESS
        } catch (_: Exception) {
            false
        }
    }

    private fun allowedAuthenticators(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
        } else {
            BiometricManager.Authenticators.BIOMETRIC_STRONG
        }

    private fun isDeviceSecure(): Boolean {
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            keyguard.isDeviceSecure
        } else {
            @Suppress("DEPRECATION")
            keyguard.isKeyguardSecure
        }
    }

    private fun createKeyPair(result: MethodChannel.Result) {
        val keyStore = try {
            loadKeyStore()
        } catch (_: Exception) {
            result.error("device_credential_unavailable", "Could not access Android Keystore.", null)
            return
        }
        try {
            if (keyStore.containsAlias(keyAlias)) {
                result.error("key_invalidated", "An existing protected device-lock key has no matching enrollment.", null)
                return
            }
            deleteAlias(legacyBiometricKeyAlias)
            val generator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_RSA,
                "AndroidKeyStore"
            )
            val spec = KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_SIGN
            )
                .setKeySize(2048)
                .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                spec.setUserAuthenticationParameters(
                    0,
                    KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
                )
            } else {
                @Suppress("DEPRECATION")
                spec.setUserAuthenticationValidityDurationSeconds(deviceCredentialValiditySeconds)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                spec.setInvalidatedByBiometricEnrollment(true)
            }
            generator.initialize(spec.build())
            val keyPair = generator.generateKeyPair()
            val keyInfo = KeyFactory
                .getInstance(keyPair.private.algorithm, "AndroidKeyStore")
                .getKeySpec(keyPair.private, KeyInfo::class.java)
            if (!keyInfo.isInsideSecureHardware) {
                keyStore.deleteEntry(keyAlias)
                result.error("device_credential_unavailable", "This device cannot protect the device-lock signing key in secure hardware.", null)
                return
            }
            result.success(Base64.encodeToString(keyPair.public.encoded, Base64.NO_WRAP))
        } catch (_: Exception) {
            try {
                keyStore.deleteEntry(keyAlias)
            } catch (_: Exception) {
                result.error("device_credential_unavailable", "Could not clean up the temporary device-lock key.", null)
                return
            }
            result.error("device_credential_unavailable", "Could not create a hardware-protected device-lock key.", null)
        }
    }

    private fun hasUsableKey(): Boolean {
        return try {
            val keyStore = loadKeyStore()
            if (!keyStore.containsAlias(keyAlias)) return false
            val privateKey = keyStore.getKey(keyAlias, null) as? PrivateKey ?: return false
            val keyInfo = KeyFactory
                .getInstance(privateKey.algorithm, "AndroidKeyStore")
                .getKeySpec(privateKey, KeyInfo::class.java)
            keyInfo.isInsideSecureHardware
        } catch (_: KeyPermanentlyInvalidatedException) {
            false
        } catch (_: UnrecoverableKeyException) {
            false
        } catch (_: InvalidKeyException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun signChallenge(
        challenge: String?,
        method: String?,
        result: MethodChannel.Result
    ) {
        if (challenge == null) {
            result.error("invalid_argument", "A device-lock challenge is required.", null)
            return
        }
        if (!isDeviceSecure()) {
            result.error("device_credential_unavailable", "Set up a screen lock (PIN, pattern or password) on this device to use device-lock login.", null)
            return
        }
        if (!hasUsableKey()) {
            result.error("key_missing", "The protected device-lock key is missing or invalidated.", null)
            return
        }
        when (method?.trim()?.lowercase()) {
            "biometric" -> {
                if (!isBiometricAvailable()) {
                    result.error("biometric_unavailable", "No fingerprint or face is set up on this device. Use MPIN or pattern instead.", null)
                    return
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    signWithBiometricPrompt(
                        challenge,
                        BiometricManager.Authenticators.BIOMETRIC_STRONG,
                        result
                    )
                } else {
                    signWithBiometricOnlyPrompt(challenge, result)
                }
            }
            "devicecredential" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    signWithBiometricPrompt(
                        challenge,
                        BiometricManager.Authenticators.DEVICE_CREDENTIAL,
                        result
                    )
                } else {
                    signWithKeyguardConfirmation(challenge, result)
                }
            }
            else -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    signWithBiometricPrompt(challenge, allowedAuthenticators(), result)
                } else {
                    signWithKeyguardConfirmation(challenge, result)
                }
            }
        }
    }

    private fun signWithBiometricOnlyPrompt(challenge: String, result: MethodChannel.Result) {
        try {
            val prompt = BiometricPrompt(
                this,
                ContextCompat.getMainExecutor(this),
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authenticationResult: BiometricPrompt.AuthenticationResult
                    ) {
                        signWithStoredKey(challenge, result)
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        result.error(errorCodeToCode(errorCode), errorCodeToMessage(errorCode), null)
                    }
                }
            )
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Verify to log in")
                .setSubtitle("Use your fingerprint or face to sign in securely")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText("Cancel")
                .build()
            prompt.authenticate(promptInfo)
        } catch (_: Exception) {
            result.error("biometric_unavailable", "Could not start biometric authentication. Use MPIN or pattern instead.", null)
        }
    }

    private fun signWithBiometricPrompt(
        challenge: String,
        authenticators: Int,
        result: MethodChannel.Result
    ) {
        var stage = "load Android Keystore"
        try {
            val keyStore = loadKeyStore()
            if (!keyStore.containsAlias(keyAlias)) {
                result.error("key_missing", "The protected device-lock key is missing.", null)
                return
            }
            val privateKey = keyStore.getKey(keyAlias, null) as? PrivateKey
                ?: run {
                    result.error("key_missing", "The protected device-lock key is missing.", null)
                    return
                }
            stage = "initialize device-lock signing key"
            val signature = Signature.getInstance("SHA256withRSA")
            signature.initSign(privateKey)
            stage = "create device-lock prompt"
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
                            result.error("key_invalidated", "The protected device-lock key could not sign this challenge. Sign in with OTP and enroll again.", null)
                        }
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        result.error(errorCodeToCode(errorCode), errorCodeToMessage(errorCode), null)
                    }
                }
            )
            stage = "configure device-lock prompt"
            val promptBuilder = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Verify to log in")
                .setSubtitle(
                    if (authenticators == BiometricManager.Authenticators.DEVICE_CREDENTIAL) {
                        "Enter your device PIN or pattern"
                    } else {
                        "Use your screen lock or biometric to sign in securely"
                    }
                )
                .setAllowedAuthenticators(authenticators)
            if (authenticators and BiometricManager.Authenticators.DEVICE_CREDENTIAL == 0) {
                promptBuilder.setNegativeButtonText("Cancel")
            }
            val promptInfo = promptBuilder.build()
            stage = "start device-lock prompt"
            prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(signature))
        } catch (error: KeyPermanentlyInvalidatedException) {
            Log.e("Gift360DeviceLock", "Device-lock setup failed at $stage", error)
            result.error("key_invalidated", "The device-lock key was invalidated. Sign in with OTP and enroll again.", null)
        } catch (error: UserNotAuthenticatedException) {
            Log.e("Gift360DeviceLock", "Device-lock setup failed at $stage", error)
            result.error("key_not_authorized", "Device unlock verification expired. Please try again.", null)
        } catch (error: UnrecoverableKeyException) {
            Log.e("Gift360DeviceLock", "Device-lock setup failed at $stage", error)
            result.error("key_invalidated", "The device-lock key was invalidated. Sign in with OTP and enroll again.", null)
        } catch (error: Exception) {
            Log.e(
                "Gift360DeviceLock",
                "Could not start device-lock authentication at $stage (${error.javaClass.simpleName})",
                error
            )
            result.error("device_credential_unavailable", "Could not start device-lock authentication. Use OTP login instead.", null)
        }
    }

    private fun signWithKeyguardConfirmation(challenge: String, result: MethodChannel.Result) {
        if (pendingSignResult != null) {
            result.error("device_credential_unavailable", "Another device unlock is already in progress.", null)
            return
        }
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        @Suppress("DEPRECATION")
        val intent = keyguard.createConfirmDeviceCredentialIntent(
            "Verify to log in",
            "Unlock your screen to sign in to Gift360"
        )
        if (intent == null) {
            result.error("device_credential_unavailable", "Could not start device unlock. Use OTP login instead.", null)
            return
        }
        pendingChallenge = challenge
        pendingSignResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(intent, deviceCredentialRequestCode)
    }

    private fun signWithStoredKey(challenge: String, result: MethodChannel.Result) {
        try {
            val keyStore = loadKeyStore()
            if (!keyStore.containsAlias(keyAlias)) {
                result.error("key_missing", "The protected device-lock key is missing.", null)
                return
            }
            val privateKey = keyStore.getKey(keyAlias, null) as? PrivateKey
                ?: run {
                    result.error("key_missing", "The protected device-lock key is missing.", null)
                    return
                }
            val signature = Signature.getInstance("SHA256withRSA")
            signature.initSign(privateKey)
            signature.update(challenge.toByteArray(Charsets.UTF_8))
            result.success(Base64.encodeToString(signature.sign(), Base64.NO_WRAP))
        } catch (error: KeyPermanentlyInvalidatedException) {
            Log.e("Gift360DeviceLock", "Device-lock key was invalidated", error)
            result.error("key_invalidated", "The device-lock key was invalidated. Sign in with OTP and enroll again.", null)
        } catch (error: UserNotAuthenticatedException) {
            Log.e("Gift360DeviceLock", "Device-lock key is not authorized yet", error)
            result.error("key_not_authorized", "Device unlock verification expired. Please try again.", null)
        } catch (error: UnrecoverableKeyException) {
            Log.e("Gift360DeviceLock", "Device-lock key is unrecoverable", error)
            result.error("key_invalidated", "The device-lock key was invalidated. Sign in with OTP and enroll again.", null)
        } catch (error: Exception) {
            Log.e("Gift360DeviceLock", "Device-lock key could not sign", error)
            result.error("key_invalidated", "The protected device-lock key could not sign this challenge. Sign in with OTP and enroll again.", null)
        }
    }

    private fun errorCodeToCode(errorCode: Int): String = when (errorCode) {
        BiometricPrompt.ERROR_USER_CANCELED,
        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
        BiometricPrompt.ERROR_CANCELED -> "device_credential_cancelled"
        BiometricPrompt.ERROR_LOCKOUT,
        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "biometric_lockout"
        BiometricPrompt.ERROR_NO_BIOMETRICS,
        BiometricPrompt.ERROR_HW_NOT_PRESENT,
        BiometricPrompt.ERROR_HW_UNAVAILABLE -> "biometric_unavailable"
        else -> "device_credential_unavailable"
    }

    private fun errorCodeToMessage(errorCode: Int): String = when (errorCode) {
        BiometricPrompt.ERROR_USER_CANCELED,
        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
        BiometricPrompt.ERROR_CANCELED -> "Device unlock was cancelled."
        BiometricPrompt.ERROR_LOCKOUT,
        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "Device lock is temporarily locked. Unlock your device and try again."
        BiometricPrompt.ERROR_NO_BIOMETRICS,
        BiometricPrompt.ERROR_HW_NOT_PRESENT,
        BiometricPrompt.ERROR_HW_UNAVAILABLE -> "Biometric authentication is unavailable. Use MPIN or pattern instead."
        else -> "Device-lock authentication failed. Use OTP login instead."
    }

    private fun deleteAlias(alias: String) {
        try {
            loadKeyStore().deleteEntry(alias)
        } catch (_: Exception) {
            // Best effort cleanup; enrollment state tolerates a leftover alias.
        }
    }

    private fun loadKeyStore(): KeyStore =
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
}
