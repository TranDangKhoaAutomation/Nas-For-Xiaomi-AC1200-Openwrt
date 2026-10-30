package com.trandangkhoa.nas_client

import android.content.Context
import android.content.ContentValues
import android.database.sqlite.SQLiteOpenHelper
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.work.*
import com.trandangkhoa.bridge.nasnet.Nasnet
import go.Seq
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.NetworkInterface
import java.security.KeyStore
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object BackupStore {
    private const val TAG = "khoanas-photo-backup"
    private const val ALIAS = "khoanas-backup-v1"
    private fun prefs(c: Context) = c.getSharedPreferences("photo-backup", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    @Synchronized fun read(c: Context): JSONObject {
        val value = prefs(c).getString("profile", null) ?: return JSONObject()
        val data = Base64.decode(value, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, data.copyOfRange(0, 12)))
        return JSONObject(String(cipher.doFinal(data.copyOfRange(12, data.size)), Charsets.UTF_8))
    }
    @Synchronized private fun write(c: Context, profile: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val data = cipher.iv + cipher.doFinal(profile.toString().toByteArray(Charsets.UTF_8))
        check(prefs(c).edit().putString("profile", Base64.encodeToString(data, Base64.NO_WRAP)).commit())
    }
    fun publicState(c: Context): String {
        val profile = read(c)
        profile.put("hasPassword", profile.optString("password").isNotEmpty()).remove("password")
        val status = JSONObject(prefs(c).getString("status", "{}")!!)
        val infos = WorkManager.getInstance(c).getWorkInfosByTag(TAG).get()
        status.put("running", infos.any { it.state == WorkInfo.State.RUNNING })
        status.put("queued", infos.any { it.state == WorkInfo.State.ENQUEUED })
        if (BackupWorker.sessionID.isNotEmpty()) {
            status.put("transfer", JSONObject(Nasnet.backupProgress(BackupWorker.sessionID)))
        }
        return JSONObject().put("profile", profile).put("status", status).toString()
    }
    fun save(c: Context, value: String) {
        require(!BackupWorker.busy.get()) { "Dừng sao lưu trước khi sửa thiết lập" }
        val p = JSONObject(value)
        val old = read(c)
        val host = p.optString("host").trim()
        val octets = host.split('.').map { it.toIntOrNull() ?: -1 }
        require(octets.size == 4 && octets.all { it in 0..255 } &&
            (octets[0] == 10 || octets[0] == 192 && octets[1] == 168 || octets[0] == 172 && octets[1] in 16..31 || octets[0] == 100 && octets[1] in 64..127)) { "Nhập IP LAN hoặc Tailscale của NAS" }
        p.put("host", host).put("user", p.optString("user").trim())
        require(p.optString("user").isNotEmpty()) { "Nhập tài khoản SMB" }
        require(p.optString("share").isNotBlank() && !p.optString("share").contains(Regex("[/\\\\\u0000]"))) { "Nhập tên chia sẻ SMB" }
        val root = p.optString("path", "Anh-sao-luu").replace('\\', '/').trim('/')
        require(root.isNotBlank() && root.split('/').all { it != ".." && it != "." && it.isNotBlank() && !it.contains(Regex("[<>:\"|?*\u0000]")) }) { "Thư mục đích không hợp lệ" }
        p.put("path", root)
        val sources = p.optJSONArray("sources") ?: JSONArray()
        require(sources.length() in 1..16) { "Chọn từ 1 đến 16 thư mục nguồn" }
        val granted = c.contentResolver.persistedUriPermissions.filter { it.isReadPermission }.map { it.uri.toString() }.toSet()
        for (i in 0 until sources.length()) require(granted.contains(sources.getJSONObject(i).getString("uri"))) { "Chọn lại thư mục để cấp quyền đọc" }
        require(p.optBoolean("images", true) || p.optBoolean("videos", true)) { "Chọn ảnh hoặc video để sao lưu" }
        require(p.optInt("minutes", 60) in listOf(15, 60, 360, 1440)) { "Lịch sao lưu không hợp lệ" }
        if (p.optString("password").isEmpty() && listOf("host", "user", "remote").all { p.opt(it) == old.opt(it) }) p.put("password", old.optString("password"))
        require(p.optString("password").isNotEmpty()) { "Nhập mật khẩu SMB cho sao lưu" }
        p.put("id", UUID.randomUUID().toString())
        WorkManager.getInstance(c).cancelAllWorkByTag(TAG).result.get()
        write(c, p)
        // Release only source grants explicitly removed from this feature.
        val kept = (0 until sources.length()).map { sources.getJSONObject(it).getString("uri") }.toSet()
        val previous = old.optJSONArray("sources") ?: JSONArray()
        for (i in 0 until previous.length()) {
            val uri = previous.getJSONObject(i).getString("uri")
            if (uri !in kept) try { c.contentResolver.releasePersistableUriPermission(Uri.parse(uri), android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: Exception) {}
        }
        if (p.optBoolean("enabled")) {
            val request = PeriodicWorkRequest.Builder(BackupWorker::class.java, p.optInt("minutes", 60).toLong(), TimeUnit.MINUTES)
                .setConstraints(constraints(p)).setInputData(workDataOf("profile" to p.getString("id")))
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).addTag(TAG).build()
            WorkManager.getInstance(c).enqueueUniquePeriodicWork(TAG, ExistingPeriodicWorkPolicy.CANCEL_AND_REENQUEUE, request)
        }
        status(c, "Đã lưu thiết lập", "", 0)
    }
    private fun constraints(p: JSONObject) = Constraints.Builder()
        .setRequiredNetworkType(if (p.optBoolean("wifi", true)) NetworkType.UNMETERED else NetworkType.CONNECTED)
        .setRequiresCharging(p.optBoolean("charging", false)).setRequiresBatteryNotLow(true).build()
    fun run(c: Context) {
        val p = read(c)
        require(p.optString("id").isNotEmpty()) { "Lưu thiết lập trước khi sao lưu" }
        val request = OneTimeWorkRequest.Builder(BackupWorker::class.java).setConstraints(constraints(p))
            .setInputData(workDataOf("profile" to p.getString("id"))).addTag(TAG)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build()
        WorkManager.getInstance(c).enqueueUniqueWork("$TAG-now", ExistingWorkPolicy.KEEP, request)
        status(c, "Đang chờ mạng, pin và lịch Android", "", 0)
    }
    fun stop(c: Context) {
        val p = read(c).put("enabled", false).put("id", UUID.randomUUID().toString())
        write(c, p)
        WorkManager.getInstance(c).cancelAllWorkByTag(TAG)
        BackupWorker.sessionID.takeIf { it.isNotEmpty() }?.let { Nasnet.backupStop(it) }
        status(c, "Đã dừng • tự sao lưu đã tắt", "", 0)
    }
    fun status(c: Context, message: String, file: String, count: Int) {
        val status = JSONObject().put("message", message).put("file", file).put("count", count).put("time", System.currentTimeMillis())
        prefs(c).edit().putString("status", status.toString()).apply()
    }
    fun hash(value: String) = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
    fun interfaces(): String {
        val result = JSONArray()
        for (net in Collections.list(NetworkInterface.getNetworkInterfaces())) {
            val addresses = JSONArray()
            for (address in net.interfaceAddresses) address.address.hostAddress?.substringBefore('%')?.let { addresses.put("$it/${address.networkPrefixLength}") }
            result.put(JSONObject().put("name",net.name).put("index",net.index).put("mtu",net.mtu).put("up",net.isUp).put("loopback",net.isLoopback).put("addresses",addresses))
        }
        return result.toString()
    }
}

private class BackupIndex(c: Context) : SQLiteOpenHelper(c,"backup-index.db",null,1) {
    override fun onCreate(db: SQLiteDatabase) { db.execSQL("CREATE TABLE completed (version TEXT PRIMARY KEY, finished INTEGER NOT NULL)") }
    override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) {}
    fun contains(key: String) = readableDatabase.rawQuery("SELECT 1 FROM completed WHERE version=?",arrayOf(key)).use { it.moveToFirst() }
    fun add(key: String) { writableDatabase.insertWithOnConflict("completed",null,ContentValues().apply {put("version",key);put("finished",System.currentTimeMillis())},SQLiteDatabase.CONFLICT_REPLACE) }
}

class BackupWorker(c: Context, p: WorkerParameters) : Worker(c,p) {
    companion object { val busy = AtomicBoolean(false); @Volatile var sessionID = "" }
    @Volatile private var ownSession = ""
    override fun onStopped() { ownSession.takeIf { it.isNotEmpty() }?.let { Nasnet.backupStop(it) } }
    override fun doWork(): Result {
        if (!busy.compareAndSet(false,true)) return Result.retry()
        val c = applicationContext
        var count = 0
        val deadline = System.currentTimeMillis() + 7*60*1000
        try {
            val p = BackupStore.read(c)
            if (p.optString("id") != inputData.getString("profile")) return Result.success()
            Seq.setContext(c)
            Nasnet.updateInterfaces(BackupStore.interfaces())
            if (p.optBoolean("remote",true)) Nasnet.start(File(c.filesDir,"tailnet").path)
            BackupStore.status(c,"Đang kiểm tra ảnh và video", "",0)
            BackupIndex(c).use { index ->
                val sources = p.getJSONArray("sources")
                for (i in 0 until sources.length()) {
                    val source = sources.getJSONObject(i)
                    val tree = Uri.parse(source.getString("uri"))
                    val pending = ArrayDeque<Pair<String,Int>>()
                    pending.add(DocumentsContract.getTreeDocumentId(tree) to 0)
                    val seen = mutableSetOf<String>()
                    while (pending.isNotEmpty()) {
                        checkBudget(deadline)
                        val (parent, depth) = pending.removeFirst()
                        if (!seen.add(parent)) continue
                        require(seen.size <= 10000 && depth <= 64) { "Quá nhiều thư mục nguồn" }
                        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree,parent)
                        val cols = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,DocumentsContract.Document.COLUMN_DISPLAY_NAME,DocumentsContract.Document.COLUMN_MIME_TYPE,DocumentsContract.Document.COLUMN_SIZE,DocumentsContract.Document.COLUMN_LAST_MODIFIED)
                        val cursor = c.contentResolver.query(children,cols,null,null,null) ?: throw IllegalStateException("Mất quyền đọc thư mục")
                        cursor.use {
                            while (it.moveToNext()) {
                                checkBudget(deadline)
                                val id = it.getString(0);val name = it.getString(1) ?: "media"
                                val mime = it.getString(2) ?: ""
                                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) { pending.add(id to depth+1);continue }
                                val ext = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
                                val image = mime.startsWith("image/") || ext in listOf("jpg","jpeg","png","webp","heic","heif","gif","bmp")
                                val video = mime.startsWith("video/") || ext in listOf("mp4","mov","mkv","webm","m4v","3gp","avi")
                                if (!(image && p.optBoolean("images",true) || video && p.optBoolean("videos",true))) continue
                                if (it.isNull(3)) continue
                                val size = it.getLong(3); val modified = it.getLong(4)
                                val uri = DocumentsContract.buildDocumentUriUsingTree(tree,id)
                                // Providers without timestamps need a content fingerprint to detect edits.
                                val revision = if (modified>0) "$modified" else c.contentResolver.openInputStream(uri)!!.use { stream ->
                                    val digest=MessageDigest.getInstance("SHA-256");val buffer=ByteArray(1024*1024)
                                    while (true) { checkBudget(deadline);val n=stream.read(buffer);if(n<0)break;digest.update(buffer,0,n) }
                                    digest.digest().joinToString("") { b -> "%02x".format(b) }
                                }
                                val version = BackupStore.hash("${tree}\n$id\n$size\n$revision")
                                val scope = BackupStore.hash("${p.getString("host")}\n${p.getString("share")}\n${p.getString("path")}\n$version")
                                if (index.contains(scope)) continue
                                if (ownSession.isEmpty()) {
                                    ownSession = Nasnet.backupStart(p.getString("host"),p.getString("user"),p.getString("password"),p.getString("share"),p.optBoolean("remote",true))
                                    sessionID = ownSession
                                    if (isStopped) { Nasnet.backupStop(ownSession);return Result.success() }
                                }
                                val safeName = name.replace(Regex("[<>:\"/\\\\|?*\u0000-\u001f]"),"_").trim('.',' ').take(100).ifEmpty { "media" }
                                val dot = safeName.lastIndexOf('.')
                                val stem=if(dot>0)safeName.substring(0,dot) else safeName
                                val suffix=if(dot>0)safeName.substring(dot) else ""
                                val month=if(modified>0)SimpleDateFormat("yyyy/MM",Locale.ROOT).format(Date(modified)) else "Khong-ro-ngay"
                                val sourceName=BackupStore.hash(tree.toString()).take(8)
                                val target="${p.getString("path")}/$sourceName/$month/${stem}_${version.take(24)}$suffix"
                                BackupStore.status(c,"Đang sao lưu",name,count)
                                c.contentResolver.openFileDescriptor(uri,"r")!!.use { descriptor ->
                                    val fd = ParcelFileDescriptor.dup(descriptor.fileDescriptor).detachFd()
                                    Nasnet.backupUploadFD(ownSession,fd.toLong(),target,size)
                                }
                                index.add(scope);count++
                            }
                        }
                    }
                }
            }
            if (!isStopped) BackupStore.status(c,"Đã sao lưu • $count tệp mới trong lượt này","",count)
            return Result.success()
        } catch (_: SecurityException) {
            BackupStore.status(c,"Mất quyền đọc: mở Thiết lập và chọn lại thư mục","",count)
            return Result.failure()
        } catch (_: Exception) {
            if (!isStopped) BackupStore.status(c,"Chưa hoàn tất • sẽ thử lại. Kiểm tra mạng, đăng nhập Tailscale và quyền ghi SMB.","",count)
            return Result.retry()
        } finally {
            ownSession.takeIf { it.isNotEmpty() }?.let { Nasnet.backupStop(it) }
            sessionID="";busy.set(false)
        }
    }
    private fun checkBudget(deadline: Long) { if (isStopped || System.currentTimeMillis()>deadline) throw InterruptedException() }
}
