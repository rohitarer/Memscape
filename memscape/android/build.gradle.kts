plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ (Optional but safe): Centralized build directory
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    // project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ✅ Apply Google Services plugin where needed
    // afterEvaluate {
    //     if (plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")) {
    //         apply(plugin = "com.google.gms.google-services")
    //     }
    // }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}



// plugins {
//     id("com.google.gms.google-services") version "4.4.2" apply false
// }
// allprojects {
//     repositories {
//         google()
//         mavenCentral()
//     }
// }

// val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
// rootProject.layout.buildDirectory.value(newBuildDir)

// subprojects {
//     val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
//     project.layout.buildDirectory.value(newSubprojectBuildDir)
// }
// subprojects {
//     project.evaluationDependsOn(":app")
// }

// tasks.register<Delete>("clean") {
//     delete(rootProject.layout.buildDirectory)
// }
