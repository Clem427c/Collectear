"""Branche la signature release d'Android sur android/key.properties (clé d'envoi Google Play).

Appelé par la CI (étape « Build AAB ») sur le android/app/build.gradle.kts généré par `flutter create`.
Si android/key.properties existe, le build release est signé avec la clé qu'il décrit ; sinon il
garde la clé de debug du modèle Flutter (comme avant). Ré-exécutable : ne fait rien s'il est déjà passé.

Usage : python3 tool/android_signing.py android/app/build.gradle.kts
"""
import re
import sys

MARK = "// Collectear : signature release"

IMPORTS = "import java.io.FileInputStream\nimport java.util.Properties\n\n"

LOAD = f"""{MARK} (android/key.properties, écrit par la CI, jamais dans le dépôt)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {{
    FileInputStream(keystorePropertiesFile).use {{ keystoreProperties.load(it) }}
}}

"""

CONFIGS = """    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

"""

USE = ('signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") '
       'else signingConfigs.getByName("debug")')


def patch(src: str) -> str:
    if MARK in src:
        return src
    # 0. Imports en tête de fichier (dans un script Gradle Kotlin, « java. » désigne l'extension
    #    java de Gradle : java.util.Properties() ne compile pas).
    src = IMPORTS + src
    # 1. Lecture de key.properties, juste avant le bloc android { } (après plugins { }).
    m = re.search(r"^android\s*\{", src, re.M)
    assert m, "bloc android { } introuvable"
    src = src[:m.start()] + LOAD + src[m.start():]
    # 2. signingConfigs { release } juste avant buildTypes { }.
    m = re.search(r"^(\s*)buildTypes\s*\{", src, re.M)
    assert m, "bloc buildTypes { } introuvable"
    src = src[:m.start()] + CONFIGS.rstrip("\n") + "\n\n" + src[m.start():].lstrip("\n")
    # 3. Le build release utilise la clé d'envoi quand elle est là.
    src, n = re.subn(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', USE, src)
    assert n >= 1, "signingConfig debug du modèle Flutter introuvable"
    return src


def main():
    path = sys.argv[1]
    if not path.endswith(".kts"):
        sys.exit(f"{path} : seul le format Kotlin (build.gradle.kts) est géré")
    src = open(path, encoding="utf-8").read()
    out = patch(src)
    open(path, "w", encoding="utf-8").write(out)
    print("Signature release :", "déjà branchée" if out == src else "branchée sur key.properties")


if __name__ == "__main__":
    main()
