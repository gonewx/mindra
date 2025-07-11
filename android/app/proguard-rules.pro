# Flutter相关的ProGuard规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 音频播放相关
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_service.** { *; }
-keep class xyz.luan.audioplayers.** { *; }

# 数据库相关
-keep class com.tekartik.sqflite.** { *; }

# 通知相关
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# 文件选择器相关
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# 权限处理相关
-keep class com.baseflow.permissionhandler.** { *; }

# 网络请求相关
-keep class com.diox.dio.** { *; }

# 保持所有native方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保持枚举类
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
