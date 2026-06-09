val newBuildDir: Directory =
    rootProject.layout.projectDirectory
        .dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureNamespace = {
        val extension = project.extensions.findByName("android")
        if (extension != null) {
            try {
                val getNamespace = extension.javaClass.getMethod("getNamespace")
                val ns = getNamespace.invoke(extension)
                if (ns == null || ns.toString().isEmpty()) {
                    val setNamespace = extension.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(extension, "com.smartglass.ai.${project.name.replace(':', '_').replace('-', '_')}")
                    println("Dynamically set namespace for subproject: ${project.name}")
                }
            } catch (e: Exception) {
                // Ignore
            }

            try {
                val compileOptions = extension.javaClass.getMethod("getCompileOptions").invoke(extension)
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", org.gradle.api.JavaVersion::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", org.gradle.api.JavaVersion::class.java)
                setSource.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    if (project.state.executed) {
        configureNamespace()
    } else {
        project.afterEvaluate {
            configureNamespace()
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    tasks.configureEach {
        if (this.javaClass.name.contains("KotlinCompile")) {
            try {
                val kotlinOptions = this.javaClass.getMethod("getKotlinOptions").invoke(this)
                val setJvmTarget = kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java)
                setJvmTarget.invoke(kotlinOptions, "17")
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
}



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

