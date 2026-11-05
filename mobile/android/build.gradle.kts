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
// isar_flutter_libs 3.x compiles against an old SDK (no android:attr/lStar) -> force a modern compileSdk
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.apply {
            if ((compileSdk ?: 0) < 34) compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
