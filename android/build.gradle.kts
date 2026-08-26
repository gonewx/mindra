allprojects {
    repositories {
        // 使用阿里云镜像加速依赖下载
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }

        // 备用官方仓库
        google()
        mavenCentral()
    }
}

subprojects {
    // 为所有子项目统一 Java / Kotlin 的 JVM 目标到 17
    // 必须放在 afterEvaluate 里：部分第三方插件（如 audioplayers_android）在自己的
    // build.gradle 里把 Java 目标设成 1.8，只有等子项目评估完再覆盖才生效。
    // 若提前到 plugins.withId 阶段设置，会被插件自身配置覆盖，导致
    // "Inconsistent JVM-target compatibility (Java 1.8 vs Kotlin 17)" 构建失败。
    afterEvaluate {
        // AGP 9 起 BaseExtension 已移除，改用 com.android.build.api.dsl 下的新 DSL 接口
        when (val androidExt = extensions.findByName("android")) {
            is com.android.build.api.dsl.LibraryExtension -> androidExt.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
            is com.android.build.api.dsl.ApplicationExtension -> androidExt.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }

        // 直接给编译任务兜底，不依赖 extension 的配置时机
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
            options.compilerArgs.add("-Xlint:-options")
        }

        // Kotlin 2.x 起 kotlinOptions/jvmTarget 已废弃，改用 compilerOptions DSL
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
