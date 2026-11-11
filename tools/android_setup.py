"""Installs Godot's Android Gradle build template into android/build and applies
this game's patches (portrait, Android 16 back-gesture and large-screen opt-outs,
target API 36). Run before exporting the "Android AAB" preset:

    python3 tools/android_setup.py [path/to/android_source.zip]

Default template: ~/.local/share/godot/export_templates/4.5.2.stable/android_source.zip
"""
import os
import shutil
import sys
import zipfile

VERSION = "4.5.2.stable"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    f"~/.local/share/godot/export_templates/{VERSION}/android_source.zip")
dest = os.path.join(ROOT, "android", "build")
if os.path.isdir(dest):
    shutil.rmtree(dest)
os.makedirs(dest)
with zipfile.ZipFile(src) as z:
    z.extractall(dest)
for p in (os.path.join(ROOT, "android", ".build_version"), os.path.join(dest, ".build_version")):
    with open(p, "w") as f:
        f.write(VERSION)
open(os.path.join(dest, ".gdignore"), "w").close()


def patch(path, pairs):
    with open(path) as f:
        s = f.read()
    for old, new in pairs:
        if old not in s:
            sys.exit(f"patch failed in {path}: {old!r} not found")
        s = s.replace(old, new, 1)
    with open(path, "w") as f:
        f.write(s)


patch(os.path.join(dest, "AndroidManifest.xml"), [
    ('android:screenOrientation="landscape"', 'android:screenOrientation="portrait"'),
    ('        android:requestLegacyExternalStorage="false"\n        tools:ignore="GoogleAppIndexingWarning" >',
     '        android:requestLegacyExternalStorage="false"\n'
     '        android:enableOnBackInvokedCallback="false"\n'
     '        tools:ignore="GoogleAppIndexingWarning" >\n'
     '        <!-- Android 16 (API 36): keep the portrait lock on large screens for now -->\n'
     '        <property\n'
     '            android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"\n'
     '            android:value="true" />'),
])
patch(os.path.join(dest, "config.gradle"), [("    targetSdk          : 35,", "    targetSdk          : 36,")])
print("android/build ready (template %s, target API 36)" % VERSION)
