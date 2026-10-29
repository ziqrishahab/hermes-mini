# Shizuku.newProcess is private and invoked via reflection in PrivilegedShellBridge.
# R8 must not rename or strip it in release builds.
-keep class rikka.shizuku.Shizuku {
    private static *** newProcess(java.lang.String[], java.lang.String[], java.lang.String);
}
-keep class rikka.shizuku.** { *; }
