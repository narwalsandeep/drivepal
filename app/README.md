# drivepal_app

DRIVEPAL mobile shell (Flutter).

## Maps API key file

Create a local `app/assets/google_maps_platform.env` from
`app/assets/google_maps_platform.env.example` and set your own key.

## Web: why your UI changes don’t show after “Refresh”

The **Dart code is compiled** by the `flutter run` process. A browser **Refresh** only reloads the JS bundle that process already served; it does **not** recompile files you edited on disk.

1. Run from **`app/`** (where `pubspec.yaml` lives):  
   `cd app && flutter run -d chrome`  
   Leave that terminal running.
2. Save your Dart files, then in **that same terminal** press **`r`** (hot reload) or **`R`** (hot restart). Theme / layout changes often need **`R`**.
3. If you open **`app/build/web/`** with a static server or `file://`, you see **whatever last `flutter build web` produced** — not live edits. Rebuild after changes, or use step 1–2 instead.

With the workspace root open in Cursor/VS Code, use **Run and Debug → “Flutter app: Chrome”** — `/.vscode/launch.json` sets **`cwd` to `app/`** so the correct project runs.

## Web: `KeyData` / `rawKeyData` assertion (debug only)

If the console shows **`Should never encounter KeyData when transitMode is rawKeyData`**, that comes from Flutter’s **web keyboard pipeline** (often with pointer + modifier edge cases in Chrome). It is a **known engine/framework issue**, not your widgets. **Release builds strip these asserts.**

To avoid it while testing:

- **`flutter run -d chrome --release`**, or serve **`flutter build web`** output, or run **`flutter upgrade`**.

If the app still works in debug, you can ignore the red console spam or use **`--release`** for manual QA.

