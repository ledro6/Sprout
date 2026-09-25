import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("io.github.takahirom.roborazzi")
}

android {
    namespace = "com.ledro6.sprout"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.ledro6.sprout"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    // APK на каждый процессор и общий на все: arm64 — почти любой телефон
    // с 2017 года, armeabi-v7a — старые, x86_64 — эмулятор на компьютере.
    // Отдельный APK вдвое легче общего: нативная графика AR — самое тяжёлое.
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }

    buildTypes {
        release {
            // Сжатие выключено нарочно: сборка пробная, а проверить
            // ужатый код без телефона нечем.
            isMinifyEnabled = false
            // Подпись отладочным ключом: APK ставится на любой телефон как
            // есть. Для Google Play нужен свой ключ.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    androidResources {
        // Свой язык приложения в настройках Android 13+.
        generateLocaleConfig = false
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.maxHeapSize = "4g"
                // Robolectric на JDK 21 лезет во внутренности java.base.
                it.jvmArgs(
                    "--add-exports", "java.base/jdk.internal.access=ALL-UNNAMED",
                    "--add-opens", "java.base/java.io=ALL-UNNAMED",
                    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
                )
                // Образ Android для Robolectric — с зеркала Maven Central.
                it.systemProperty(
                    "robolectric.dependency.repo.url",
                    "https://maven-central.storage-download.googleapis.com/maven2",
                )
            }
        }
    }

    packaging {
        resources.excludes += listOf("META-INF/AL2.0", "META-INF/LGPL2.1")
        // 32-битный x86 — только старые эмуляторы; телефонов на нём нет.
        jniLibs.excludes += "lib/x86/**"
    }

    bundle {
        // Язык выбирают в самом приложении — в сборке нужны все переводы.
        language { enableSplit = false }
    }

    lint {
        // Осознанные исключения — с причинами — в lint.xml.
        lintConfig = file("lint.xml")
    }
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

dependencies {
    val bom = platform("androidx.compose:compose-bom:2026.06.01")
    implementation(bom)
    implementation("androidx.core:core-ktx:1.18.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("com.google.android.material:material:1.13.0")
    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    implementation("androidx.lifecycle:lifecycle-process:2.10.0")
    implementation("androidx.navigation:navigation-compose:2.9.7")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.biometric:biometric:1.1.0")
    implementation("androidx.work:work-runtime-ktx:2.11.1")
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")
    implementation("androidx.exifinterface:exifinterface:1.4.1")
    implementation("com.google.mlkit:image-labeling:17.0.9")
    // AR: ARCore и Filament через SceneView — сцена декларативно, как Compose.
    implementation("io.github.sceneview:arsceneview:4.37.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.foundation:foundation")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")

    testImplementation(bom)
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.17")
    testImplementation("io.github.takahirom.roborazzi:roborazzi:1.75.0")
    testImplementation("io.github.takahirom.roborazzi:roborazzi-compose:1.75.0")
    testImplementation("androidx.compose.ui:ui-test-junit4")
    testImplementation("androidx.test:core-ktx:1.7.0")
    testImplementation("androidx.work:work-testing:2.11.1")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
