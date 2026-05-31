plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "com.xiaoland.craftingtable.ctcore"
    compileSdk = 36

    defaultConfig {
        minSdk = 26
    }
}

dependencies {
    api("net.java.dev.jna:jna:${libs.versions.jna.get()}@aar")
}
