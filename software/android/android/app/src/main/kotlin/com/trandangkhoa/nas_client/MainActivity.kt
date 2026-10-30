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

class MainActivity : FlutterActivity() {
    private val workers = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var exportResult: MethodChannel.Result? = null
    private var exportPath: String? = null
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent); setIntent(intent)
        intent.dataString?.let { channel?.invokeMethod("incomingLink", it) }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
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
        networkCallback?.let { try { (getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager).unregisterNetworkCallback(it) } catch (_: Exception) {} }
        super.onDestroy()
    }
}
