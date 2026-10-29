package com.hermesmobile.hermes_mobile

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicBoolean

object PrivilegedShellBridge {
    private const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"
    private const val SHIZUKU_REQUEST_CODE = 9119
    private const val PERMISSION_TIMEOUT_MS = 20_000L
    private const val MAX_OUTPUT_CHARS = 32_768

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()

    fun getStatus(context: Context): Map<String, Any> {
        val appCtx = context.applicationContext

        val running = try {
            Shizuku.pingBinder()
        } catch (_: Throwable) {
            false
        }

        val authorized = running && try {
            !Shizuku.isPreV11() &&
                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (_: Throwable) {
            false
        }

        val uid = if (authorized) {
            try {
                Shizuku.getUid()
            } catch (_: Throwable) {
                -1
            }
        } else {
            -1
        }

        val installed = isPackageInstalled(appCtx, SHIZUKU_PACKAGE)
        val installedBackend = if (installed) "shizuku" else "none"
        val backend = if (running) "shizuku" else "none"
        val available = running || installed

        val modeLabel = when {
            authorized && uid == 0 -> "Active (Root UID 0 via Shizuku)"
            authorized && uid == 2000 -> "Active (ADB UID 2000 via Shizuku)"
            authorized -> "Active (Shizuku Shell)"
            running -> "Permission required (Shizuku active)"
            installed -> "Service stopped (Start Shizuku Next)"
            else -> "Inactive (Requires Shizuku Next)"
        }

        return mapOf(
            "available" to available,
            "running" to running,
            "authorized" to authorized,
            "backend" to backend,
            "installedBackend" to installedBackend,
            "uid" to uid,
            "modeLabel" to modeLabel
        )
    }

    fun requestPermission(context: Context, callback: (Map<String, Any>) -> Unit) {
        val completed = AtomicBoolean(false)

        fun finish(granted: Boolean, backend: String, message: String) {
            if (!completed.compareAndSet(false, true)) return
            mainHandler.post {
                callback(
                    mapOf(
                        "granted" to granted,
                        "backend" to backend,
                        "message" to message
                    )
                )
            }
        }

        val running = try {
            Shizuku.pingBinder()
        } catch (_: Throwable) {
            false
        }

        if (!running) {
            finish(
                false,
                "none",
                "Shizuku Next is not running. Start the service from the Shizuku Next app first."
            )
            return
        }

        try {
            if (Shizuku.isPreV11()) {
                finish(false, "shizuku", "Shizuku version is older than v11.")
                return
            }
            if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                finish(true, "shizuku", "Shizuku permission already granted.")
                return
            }

            lateinit var listener: Shizuku.OnRequestPermissionResultListener
            val timeoutRunnable = Runnable {
                try {
                    Shizuku.removeRequestPermissionResultListener(listener)
                } catch (_: Throwable) {
                }
                finish(false, "shizuku", "Shizuku permission request timed out.")
            }

            listener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
                if (requestCode == SHIZUKU_REQUEST_CODE) {
                    mainHandler.removeCallbacks(timeoutRunnable)
                    try {
                        Shizuku.removeRequestPermissionResultListener(listener)
                    } catch (_: Throwable) {
                    }
                    val ok = grantResult == PackageManager.PERMISSION_GRANTED
                    finish(
                        ok,
                        "shizuku",
                        if (ok) "Shizuku shell access granted." else "Shizuku permission denied."
                    )
                }
            }

            Shizuku.addRequestPermissionResultListener(listener)
            mainHandler.postDelayed(timeoutRunnable, PERMISSION_TIMEOUT_MS)
            Shizuku.requestPermission(SHIZUKU_REQUEST_CODE)
        } catch (e: Throwable) {
            finish(false, "shizuku", "Failed to request Shizuku permission: ${e.message}")
        }
    }

    fun openManagerApp(context: Context): Boolean {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(SHIZUKU_PACKAGE)
            ?: return false
        return try {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launchIntent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    fun executeCommand(
        context: Context,
        command: String,
        timeoutMs: Long,
        callback: (Map<String, Any>) -> Unit
    ) {
        val appCtx = context.applicationContext
        val boundedTimeout = timeoutMs.coerceIn(1_000L, 60_000L)

        executor.execute {
            val status = getStatus(appCtx)
            val authorized = status["authorized"] as? Boolean ?: false
            val backend = status["backend"] as? String ?: "none"

            if (!authorized || backend == "none") {
                mainHandler.post {
                    callback(
                        mapOf(
                            "success" to false,
                            "exitCode" to 126,
                            "stdout" to "",
                            "stderr" to "Privileged shell is not active or authorized. Start Shizuku Next and grant access in Settings.",
                            "timedOut" to false,
                            "backend" to backend
                        )
                    )
                }
                return@execute
            }

            var process: Process? = null
            try {
                val cmdArray = arrayOf("sh", "-c", command)
                process = spawnShizukuProcess(cmdArray)

                try {
                    process.outputStream.close()
                } catch (_: Throwable) {
                }

                val stdoutFuture = executor.submit(Callable { readBoundedStream(process.inputStream) })
                val stderrFuture = executor.submit(Callable { readBoundedStream(process.errorStream) })
                val exitFuture = executor.submit(Callable { process.waitFor() })

                var timedOut = false
                val exitCode = try {
                    exitFuture.get(boundedTimeout, TimeUnit.MILLISECONDS)
                } catch (_: TimeoutException) {
                    timedOut = true
                    try {
                        process.destroy()
                    } catch (_: Throwable) {
                    }
                    124
                }

                val stdout = try {
                    stdoutFuture.get(2, TimeUnit.SECONDS)
                } catch (_: Throwable) {
                    ""
                }
                val stderr = try {
                    stderrFuture.get(2, TimeUnit.SECONDS)
                } catch (_: Throwable) {
                    if (timedOut) "Command timed out after ${boundedTimeout}ms." else ""
                }

                mainHandler.post {
                    callback(
                        mapOf(
                            "success" to (!timedOut && exitCode == 0),
                            "exitCode" to exitCode,
                            "stdout" to stdout,
                            "stderr" to stderr,
                            "timedOut" to timedOut,
                            "backend" to backend
                        )
                    )
                }
            } catch (e: Throwable) {
                try {
                    process?.destroy()
                } catch (_: Throwable) {
                }
                mainHandler.post {
                    callback(
                        mapOf(
                            "success" to false,
                            "exitCode" to 1,
                            "stdout" to "",
                            "stderr" to (e.localizedMessage ?: e.toString()),
                            "timedOut" to false,
                            "backend" to backend
                        )
                    )
                }
            }
        }
    }

    private fun spawnShizukuProcess(cmd: Array<String>): Process {
        val method = Shizuku::class.java.getDeclaredMethod(
            "newProcess",
            Array<String>::class.java,
            Array<String>::class.java,
            String::class.java
        )
        method.isAccessible = true
        return method.invoke(null, cmd, null, null) as Process
    }

    private fun readBoundedStream(stream: InputStream): String {
        val sb = StringBuilder()
        var truncated = false
        BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { reader ->
            val buffer = CharArray(2048)
            while (true) {
                val read = reader.read(buffer)
                if (read == -1) break
                val remaining = MAX_OUTPUT_CHARS - sb.length
                if (remaining > 0) {
                    val toAppend = minOf(read, remaining)
                    sb.append(buffer, 0, toAppend)
                    if (read > remaining) {
                        truncated = true
                    }
                } else {
                    truncated = true
                }
            }
        }
        if (truncated) {
            sb.append("\n...[output truncated at $MAX_OUTPUT_CHARS chars]")
        }
        return sb.toString().trimEnd()
    }

    @Suppress("DEPRECATION")
    private fun isPackageInstalled(context: Context, packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                context.packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (_: Throwable) {
            false
        }
    }
}
