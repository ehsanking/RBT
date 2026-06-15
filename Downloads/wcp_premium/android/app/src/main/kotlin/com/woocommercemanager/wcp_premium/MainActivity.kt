package com.woocommercemanager.wcp_premium

import android.Manifest
import android.app.KeyguardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Base64
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge — uses ONLY platform SDK APIs (NO pub.dev plugins, NO extra
 * Gradle dependencies) so the app builds and runs from Iran, where Google's
 * `download.flutter.io` Maven mirror returns 403 (this is why androidx.biometric
 * is intentionally NOT used). Capabilities:
 *   • insertContact   → open the system Contacts editor pre-filled (name +
 *                       phone + «مشتری» note). The Contacts app does the write
 *                       on user confirm, so no WRITE_CONTACTS permission.
 *   • requestStartupPermissions → POST_NOTIFICATIONS on Android 13+.
 *   • biometric{Available,Authenticate} → KeyguardManager device-credential
 *     confirm (PIN / pattern / password / biometric-if-set) — built into the
 *     SDK since API 21/23, no dependency.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "wcp/native"
    private val billingChannelName = "wcp/billing"
    private val bioRequestCode = 9711
    private var pendingBio: MethodChannel.Result? = null
    private val pickImageRequestCode = 9712
    private val pickFileRequestCode = 9713
    private var pendingPick: MethodChannel.Result? = null

    // Cafe Bazaar (Poolakey) in-app billing over raw AIDL — see BazaarBilling.
    private val billing: BazaarBilling by lazy { BazaarBilling(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "insertContact" -> insertContact(
                        call.argument<String>("name") ?: "",
                        call.argument<String>("phone") ?: "",
                        call.argument<String>("note") ?: "",
                        result
                    )
                    "requestStartupPermissions" -> {
                        requestStartupPermissions()
                        result.success(true)
                    }
                    "setTorch" -> setTorch(call.argument<Boolean>("on") ?: false, result)
                    "pickImage" -> pickImage(result)
                    "pickFile" -> pickFile(result)
                    "openFile" -> openFile(
                        call.argument<String>("path") ?: "",
                        call.argument<String>("mime"),
                        result
                    )
                    "saveToDownloads" -> saveToDownloads(
                        call.argument<String>("path") ?: "",
                        call.argument<String>("name") ?: "file",
                        call.argument<String>("mime") ?: "application/octet-stream",
                        result
                    )
                    "biometricAvailable" -> result.success(deviceSecure())
                    "biometricAuthenticate" -> {
                        val reason = call.argument<String>("reason")
                            ?: "برای ادامه احراز هویت کنید"
                        biometricAuthenticate(reason, result)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, billingChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> billing.connect(result)
                    "disconnect" -> {
                        billing.disconnect()
                        result.success(true)
                    }
                    "isConnected" -> result.success(billing.isConnected)
                    "isSupported" -> billing.isSupported(
                        call.argument<String>("type") ?: "subs", result
                    )
                    "skuDetails" -> billing.skuDetails(
                        call.argument<List<String>>("skus") ?: emptyList(),
                        call.argument<String>("type") ?: "subs",
                        result
                    )
                    "purchase" -> billing.purchase(
                        call.argument<String>("sku") ?: "",
                        call.argument<String>("type") ?: "subs",
                        call.argument<String>("payload") ?: "",
                        result
                    )
                    "queryPurchases" -> billing.queryPurchases(
                        call.argument<String>("type") ?: "subs", result
                    )
                    "consume" -> billing.consume(
                        call.argument<String>("purchaseToken") ?: "", result
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun insertContact(
        name: String,
        phone: String,
        note: String,
        result: MethodChannel.Result
    ) {
        try {
            val intent = Intent(ContactsContract.Intents.Insert.ACTION).apply {
                type = ContactsContract.RawContacts.CONTENT_TYPE
                if (name.isNotEmpty()) putExtra(ContactsContract.Intents.Insert.NAME, name)
                if (phone.isNotEmpty()) {
                    putExtra(ContactsContract.Intents.Insert.PHONE, phone)
                    putExtra(
                        ContactsContract.Intents.Insert.PHONE_TYPE,
                        ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
                    )
                }
                if (note.isNotEmpty()) putExtra(ContactsContract.Intents.Insert.NOTES, note)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("contact_failed", e.message, null)
        }
    }

    /**
     * Real device flashlight toggle via CameraManager.setTorchMode (API 23+,
     * no camera preview / no pub plugin needed). Returns false if no flash unit.
     */
    private fun setTorch(on: Boolean, result: MethodChannel.Result) {
        try {
            val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val camId = cm.cameraIdList.firstOrNull { id ->
                cm.getCameraCharacteristics(id)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
            if (camId == null) {
                result.success(false)
                return
            }
            cm.setTorchMode(camId, on)
            result.success(true)
        } catch (e: Exception) {
            result.error("torch_failed", e.message, null)
        }
    }

    /**
     * Open the system image picker (ACTION_GET_CONTENT, images only) and return
     * the chosen image to Dart as { data: base64, mime, filename }, or null if
     * the user cancelled. No storage permission needed — the picker grants
     * per-URI read access. No pub plugin / extra Gradle dependency.
     */
    private fun pickImage(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.success(null)
            return
        }
        pendingPick = result
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            startActivityForResult(
                Intent.createChooser(intent, "انتخاب تصویر"),
                pickImageRequestCode
            )
        } catch (e: Exception) {
            pendingPick = null
            result.error("pick_failed", e.message, null)
        }
    }

    /**
     * Open the system file picker (any type) and return the chosen file to
     * Dart as { data: base64, mime, filename }, or null if cancelled. Same
     * mechanism as pickImage; the server enforces the allowed mime list.
     */
    private fun pickFile(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.success(null)
            return
        }
        pendingPick = result
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "*/" + "*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            startActivityForResult(
                Intent.createChooser(intent, "انتخاب فایل"),
                pickFileRequestCode
            )
        } catch (e: Exception) {
            pendingPick = null
            result.error("pick_failed", e.message, null)
        }
    }

    /**
     * Open a local file with the system viewer (ACTION_VIEW). The file is shared
     * through our FileProvider (authority "<applicationId>.fileprovider") as a
     * content:// URI with FLAG_GRANT_READ_URI_PERMISSION, so no storage
     * permission and no pub plugin are needed. Returns false when no activity
     * can handle the type, so Dart can fall back to a «saved» toast.
     */
    private fun openFile(path: String, mime: String?, result: MethodChannel.Result) {
        try {
            if (path.isEmpty()) {
                result.success(false)
                return
            }
            val file = File(path)
            if (!file.exists()) {
                result.success(false)
                return
            }
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime ?: "*/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: android.content.ActivityNotFoundException) {
            result.success(false)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    /**
     * Copy a local file (already in app-private storage, e.g. our cache/temp
     * dir) into the device's PUBLIC Downloads collection so the user can find
     * it in their Files / Downloads app. On Android Q+ (API 29) this uses
     * MediaStore.Downloads — no storage permission and no pub plugin needed.
     * On older API it falls back to the app's external-files Download dir
     * (Context.getExternalFilesDir), which is also permission-free. Returns the
     * saved content URI / file path string on success, or null on failure.
     */
    private fun saveToDownloads(
        path: String,
        name: String,
        mime: String,
        result: MethodChannel.Result
    ) {
        try {
            if (path.isEmpty()) {
                result.success(null)
                return
            }
            val src = File(path)
            if (!src.exists()) {
                result.success(null)
                return
            }
            val safeName = if (name.isBlank()) "file" else name
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, safeName)
                    if (mime.isNotEmpty()) put(MediaStore.Downloads.MIME_TYPE, mime)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val resolver = contentResolver
                val uri = resolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                )
                if (uri == null) {
                    result.success(null)
                    return
                }
                resolver.openOutputStream(uri)?.use { out ->
                    src.inputStream().use { input -> input.copyTo(out) }
                } ?: run {
                    resolver.delete(uri, null, null)
                    result.success(null)
                    return
                }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                result.success(uri.toString())
            } else {
                // Pre-Q: app external-files Download dir (no permission).
                val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                    ?: run {
                        result.success(null)
                        return
                    }
                if (!dir.exists()) dir.mkdirs()
                val dest = File(dir, safeName)
                src.inputStream().use { input ->
                    dest.outputStream().use { out -> input.copyTo(out) }
                }
                result.success(dest.absolutePath)
            }
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    private fun deliverPickedImage(uri: Uri?) {
        val res = pendingPick
        pendingPick = null
        if (res == null) return
        if (uri == null) {
            res.success(null)
            return
        }
        try {
            val cr = contentResolver
            val mime = cr.getType(uri) ?: "application/octet-stream"
            val name = queryDisplayName(uri) ?: "file"
            val bytes = cr.openInputStream(uri)?.use { it.readBytes() } ?: ByteArray(0)
            if (bytes.isEmpty()) {
                res.success(null)
                return
            }
            val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
            res.success(mapOf("data" to b64, "mime" to mime, "filename" to name))
        } catch (e: Exception) {
            res.error("read_failed", e.message, null)
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) cursor.getString(idx) else null
                    } else null
                }
        } catch (e: Exception) {
            null
        }
    }

    private fun requestStartupPermissions() {
        // Platform APIs only (Activity.requestPermissions / Context.checkSelfPermission,
        // API 23+) — POST_NOTIFICATIONS is API 33+, so the device is always 23+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 9701)
            }
        }
    }

    private fun keyguard(): KeyguardManager =
        getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager

    /** True when the device has a secure lock (PIN/pattern/password/biometric). */
    private fun deviceSecure(): Boolean = keyguard().isDeviceSecure

    @Suppress("DEPRECATION")
    private fun biometricAuthenticate(reason: String, result: MethodChannel.Result) {
        val km = keyguard()
        if (!km.isDeviceSecure) {
            result.success(false)
            return
        }
        val intent: Intent? =
            km.createConfirmDeviceCredentialIntent("ووکامرس+", reason)
        if (intent == null) {
            result.success(false)
            return
        }
        pendingBio = result
        try {
            startActivityForResult(intent, bioRequestCode)
        } catch (e: Exception) {
            pendingBio = null
            result.success(false)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == bioRequestCode) {
            pendingBio?.success(resultCode == RESULT_OK)
            pendingBio = null
            return
        }
        if (requestCode == pickImageRequestCode || requestCode == pickFileRequestCode) {
            deliverPickedImage(if (resultCode == RESULT_OK) data?.data else null)
            return
        }
        // Cafe Bazaar purchase flow returns here.
        if (billing.handleActivityResult(requestCode, resultCode, data)) return
    }

    override fun onDestroy() {
        billing.disconnect()
        super.onDestroy()
    }
}
