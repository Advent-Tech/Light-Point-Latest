plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}


allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// mapbox_maps_flutter_mobile skips applying Kotlin on AGP 9+ (expects built-in Kotlin),
// but android.builtInKotlin=false here, so apply the Kotlin plugin for it explicitly.
subprojects {
    if (name == "mapbox_maps_flutter_mobile") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
