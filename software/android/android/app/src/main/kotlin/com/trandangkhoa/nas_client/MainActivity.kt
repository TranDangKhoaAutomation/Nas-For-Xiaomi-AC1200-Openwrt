package com.trandangkhoa.nas_client

import android.app.Activity
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.os.Handler
import android.os.Looper
import com.trandangkhoa.bridge.nasnet.Nasnet
import go.Seq
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.NetworkInterface
import java.util.Collections
import java.util.concurrent.Executors
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.os.Build
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val workers = Executors.newCachedThreadPool()
    private val previews = ThreadPoolExecutor(1, 1, 0L, TimeUnit.SECONDS, ArrayBlockingQueue<Runnable>(12))
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var exportResult: MethodChannel.Result? = null
    private var exportPath: String? = null
    private var folderResult: MethodChannel.Result? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    private fun interfaces(): String {
        val result = JSONArray()
        try {
            for (net in Collections.list(NetworkInterface.getNetworkInterfaces())) {
                val addresses = JSONArray()
                for (address in net.interfaceAddresses) {
                    val host = address.address.hostAddress?.substringBefore('%') ?: continue
                    addresses.put("$host/${address.networkPrefixLength}")
                }
                result.put(JSONObject().put("name", net.name).put("index", net.index)
                    .put("mtu", net.mtu).put("up", net.isUp).put("loopback", net.isLoopback)
                    .put("addresses", addresses))
            }
        } catch (_: Exception) { /* The Go bridge reports a missing usable interface. */ }
        return result.toString()
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        Seq.setContext(applicationContext)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.trandangkhoa.nas/native")
        channel!!.setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            fun text(name: String) = args[name] as? String ?: ""
            fun remote() = args["remote"] as? Boolean ?: true
            if (call.method == "backupPickFolder") {
                if (folderResult != null) { result.error("BUSY", "Đang chọn thư mục", null); return@setMethodCallHandler }
                folderResult = result
                try {
                    startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                    }, 6202)
                } catch (_: Exception) { folderResult = null; result.error("FOLDER", "Thiết bị chưa có trình chọn thư mục", null) }
                return@setMethodCallHandler
            }
            if (call.method == "mediaPreview") {
                try {
                    previews.execute {
                        try {
                            val value = preview(text("path"), text("kind"), text("cacheKey"))
                            main.post { result.success(value) }
                        } catch (_: Exception) {
                            main.post { result.success(emptyMap<String, Any>()) }
                        }
                    }
                } catch (_: Exception) { result.success(emptyMap<String, Any>()) }
                return@setMethodCallHandler
            }
            if (call.method == "exportFile") {
                if (exportResult != null) { result.error("BUSY", "Đang chọn nơi lưu tệp", null); return@setMethodCallHandler }
                val file = File(text("path")).canonicalFile
                if (!file.path.startsWith(cacheDir.canonicalPath + File.separator) || !file.isFile) {
                    result.error("FILE", "Tệp tải xuống không hợp lệ", null); return@setMethodCallHandler
                }
                exportPath = file.path; exportResult = result
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE); type = "application/octet-stream"
                    putExtra(Intent.EXTRA_TITLE, text("name").substringAfterLast('/').substringAfterLast('\\'))
                }
                startActivityForResult(intent, 6201)
                return@setMethodCallHandler
            }
            if (call.method == "initialLink") { result.success(intent?.dataString); return@setMethodCallHandler }
            workers.execute {
                try {
                    val value: Any? = when (call.method) {
                        "networkStart" -> { Nasnet.updateInterfaces(interfaces()); Nasnet.start(File(filesDir, "tailnet").path); null }
                        "networkState" -> Nasnet.state()
                        "backupGet" -> BackupStore.publicState(applicationContext)
                        "backupSave" -> { BackupStore.save(applicationContext, text("profile")); null }
                        "backupRun" -> { BackupStore.run(applicationContext); null }
                        "backupStop" -> { BackupStore.stop(applicationContext); null }
                        "networkDiscover" -> Nasnet.discover()
                        "mediaURL" -> Nasnet.mediaURL(text("path"))
                        "networkLogin" -> {
                            val url = Nasnet.loginURL()
                            main.post {
                                try {
                                    if (url.isNotEmpty()) {
                                        val uri = android.net.Uri.parse(url)
                                        require(uri.scheme == "https" && uri.host == "login.tailscale.com")
                                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                                    }
                                    result.success(null)
                                } catch (_: Exception) {
                                    result.error("BROWSER", "Không mở được trình duyệt đăng nhập. Kiểm tra trình duyệt trên thiết bị.", null)
                                }
                            }
                            return@execute
                        }
                        "networkLogout" -> { Nasnet.logout(); null }
                        "connect" -> Nasnet.connect(text("host"), text("user"), text("password"), text("domain"), remote())
                        "disconnect" -> { Nasnet.disconnect(); null }
                        "mount" -> Nasnet.mount(text("share"))
                        "list" -> Nasnet.list(text("path"))
                        "mkdir" -> { Nasnet.mkdir(text("path")); null }
                        "rename" -> { Nasnet.rename(text("from"), text("to")); null }
                        "remove" -> { Nasnet.remove(text("path")); null }
                        "upload" -> { Nasnet.upload(text("source"), text("path")); null }
                        "download" -> {
                            val file = File(text("destination")).canonicalFile
                            require(file.path.startsWith(cacheDir.canonicalPath + File.separator)) { "Đường dẫn tải xuống không hợp lệ" }
                            Nasnet.download(text("path"), file.path); null
                        }
                        "transferState" -> Nasnet.transferState()
                        "cancelTransfer" -> { Nasnet.cancelTransfer(); null }
                        "routerRequest" -> Nasnet.routerRequest(text("host"), text("body"), remote())
                        else -> { main.post { result.notImplemented() }; return@execute }
                    }
                    main.post { result.success(value) }
                } catch (error: Exception) {
                    // Do not log call arguments, credentials, auth URLs or node state.
                    main.post { result.error("NAS", error.message ?: "Chưa hoàn tất thao tác", null) }
                }
            }
        }
        val callback = object : ConnectivityManager.NetworkCallback() {
            private fun update() { workers.execute { try { Nasnet.updateInterfaces(interfaces()) } catch (_: Exception) {} } }
            override fun onAvailable(network: Network) = update()
            override fun onLost(network: Network) = update()
        }
        networkCallback = callback
        (getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager).registerDefaultNetworkCallback(callback)
    }

    private fun preview(path: String, kind: String, cacheKey: String): Map<String, Any> {
        val folder = File(cacheDir, "media-previews").apply { mkdirs() }
        val key = MessageDigest.getInstance("SHA-256").digest(cacheKey.toByteArray()).joinToString("") { "%02x".format(it) }
        val output = File(folder, "$key.jpg")
        val metadata = File(folder, "$key.json")
        if (metadata.isFile) {
            try {
                val saved = JSONObject(metadata.readText())
                if (!saved.optBoolean("hasThumbnail") || output.isFile) {
                    metadata.setLastModified(System.currentTimeMillis())
                    return mutableMapOf<String, Any>("durationMs" to saved.optLong("durationMs")).apply {
                        if (output.isFile) put("thumbnail", output.path)
                    }
                }
            } catch (_: Exception) { /* Rebuild damaged cache metadata. */ }
        }
        val url = Nasnet.mediaURL(path)
        var bitmap: Bitmap? = null
        var duration = 0L
        if (kind == "video") {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(url, mapOf("X-KhoaNAS-Preview" to "1"))
                duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                bitmap = if (Build.VERSION.SDK_INT >= 27) retriever.getScaledFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, 320, 240)
                    else retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            } catch (_: Exception) { /* Keep duration even when this codec cannot produce a frame. */ }
            finally { retriever.release() }
        } else {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 3000; connection.readTimeout = 6000
            connection.setRequestProperty("X-KhoaNAS-Preview", "1")
            try {
                val maximum = 12 * 1024 * 1024
                if (connection.contentLengthLong in 1..maximum.toLong()) {
                    val data = connection.inputStream.use { input ->
                        val bytes = ByteArrayOutputStream(); val buffer = ByteArray(16384)
                        var count: Int
                        while (true) {
                            count = input.read(buffer)
                            if (count < 0) break
                            if (bytes.size() + count > maximum) throw IllegalStateException("image too large")
                            bytes.write(buffer, 0, count)
                        }
                        bytes.toByteArray()
                    }
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeByteArray(data, 0, data.size, options)
                    if (options.outWidth > 0 && options.outHeight > 0) {
                        options.inSampleSize = 1
                        while (maxOf(options.outWidth, options.outHeight) / options.inSampleSize > 640) options.inSampleSize *= 2
                        options.inJustDecodeBounds = false
                        bitmap = BitmapFactory.decodeByteArray(data, 0, data.size, options)
                    }
                }
            } finally { connection.disconnect() }
        }
        val result = mutableMapOf<String, Any>("durationMs" to duration)
        bitmap?.let { frame ->
            try {
                val scale = minOf(1f, 320f / maxOf(frame.width, frame.height))
                val thumb = if (scale < 1f) Bitmap.createScaledBitmap(frame, maxOf(1,(frame.width*scale).toInt()), maxOf(1,(frame.height*scale).toInt()), true) else frame
                output.outputStream().use { thumb.compress(Bitmap.CompressFormat.JPEG, 75, it) }
                if (thumb !== frame) thumb.recycle()
                result["thumbnail"] = output.path
            } finally { frame.recycle() }
        }
        metadata.writeText(JSONObject().put("durationMs", duration).put("hasThumbnail", output.isFile).toString())
        folder.listFiles()?.filter { it.isFile && it.extension == "json" }?.sortedByDescending { it.lastModified() }?.drop(80)?.forEach {
            File(folder, it.nameWithoutExtension + ".jpg").delete(); it.delete()
        }
        return result
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent); setIntent(intent)
        intent.dataString?.let { channel?.invokeMethod("incomingLink", it) }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 6202) {
            val reply = folderResult ?: return
            folderResult = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) { reply.success(null); return }
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                var name = "Thư mục ảnh"
                val doc = android.provider.DocumentsContract.buildDocumentUriUsingTree(uri, android.provider.DocumentsContract.getTreeDocumentId(uri))
                contentResolver.query(doc, arrayOf(android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) name = it.getString(0) }
                reply.success(mapOf("uri" to uri.toString(), "name" to name))
            } catch (_: Exception) { reply.error("FOLDER", "Không giữ được quyền đọc. Hãy chọn thư mục trong bộ nhớ thiết bị.", null) }
            return
        }
        if (requestCode != 6201) return
        val result = exportResult ?: return
        val source = exportPath
        exportResult = null; exportPath = null
        if (resultCode != Activity.RESULT_OK || data?.data == null || source == null) { result.success(false); return }
        workers.execute {
            try {
                contentResolver.openOutputStream(data.data!!, "w")!!.use { output -> File(source).inputStream().use { it.copyTo(output) } }
                main.post { result.success(true) }
            } catch (error: Exception) { main.post { result.error("EXPORT", error.message, null) } }
        }
    }

    override fun onDestroy() {
        previews.shutdownNow()
        networkCallback?.let { try { (getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager).unregisterNetworkCallback(it) } catch (_: Exception) {} }
        super.onDestroy()
    }
}
