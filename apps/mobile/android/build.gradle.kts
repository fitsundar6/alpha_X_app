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
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            val android = extensions.findByName("android")
            if (android != null) {
                for (m in android.javaClass.methods) {
                    if ((m.name == "compileSdkVersion" || m.name == "setCompileSdkVersion" || m.name == "setCompileSdk") && m.parameterCount == 1) {
                        val paramType = m.parameterTypes[0]
                        if (paramType == Int::class.javaPrimitiveType || paramType == java.lang.Integer::class.java) {
                            try {
                                m.invoke(android, 36)
                            } catch (_: Exception) {}
                        }
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
