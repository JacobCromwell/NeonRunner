# The web demo's engine templates

The "Web (demo)" export preset doesn't use Godot's stock web templates: it names the two files in this folder
(`custom_template/release` and `custom_template/debug`), so `tools/godot.sh web` and every other export of
that preset use them with nothing else to do. They are Godot's own web templates (no threads), at the
pinned version (`tools/godot.sh`, `PINNED`), with one patch: `gles3_lazy_compile.patch`.

## What the patch does

The web build draws with the Compatibility renderer (WebGL 2). The first time Godot draws with a shader, it
compiles every variant of that shader at its default settings (plain and instanced, colour and depth) and only
then the one the draw needs. Most of those first variants are never drawn. A browser compiles each shader
program while the page waits, and Chrome and Edge on Windows translate each one to Direct3D first, so on a weak
laptop a load's compiles can stall the page long enough for the browser to give up on it (a playtester's Edge
crashed as the City's intro began, October 2026). The patch makes the web build compile each variant only when
something draws with it (`ShaderGLES3::_initialize_version`, under `#ifdef WEB_ENABLED`; native builds are
unchanged).

Measured with `tools/web/shader_programs.js` from the title to City 1, stock template against patched:

| | stock | patched |
|---|---|---|
| Programs compiled up to the title | 23 | 9 |
| Programs compiled from Play to City 1 | 131 | 45 |
| The most compiled in one frame (the intro's start) | 44 programs, 4.8 M characters | 18, 1.7 M |
| Shader code compiled in all | 18.1 M characters | 6.1 M |
| Programs drawn | 48 | the same 48 |

The programs that draw are byte for byte the same, so nothing on screen changes.

## When to rebuild

Only when the pinned Godot version changes, or the patch does: `tools/web/engine_template/build.sh` (about 30
minutes on 4 CPUs; it installs Emscripten into `build/engine_template`, git-ignored). It writes
`godot-<version>-web_nothreads_{release,debug}.zip` here; point the preset's `custom_template/*` at the new
names, commit them and delete the old ones. `test_web_demo` fails while the preset names templates of another
engine version than the one running, or files that aren't here. Re-check the patch against the new engine's
`drivers/gles3/shader_gles3.cpp` (the patch is four lines; `git apply` refuses it if the code moved), and
measure with `node tools/web/shader_programs.js` before and after.

The Emscripten version in `build.sh` must be the one the official templates of that Godot version use (a stock
export prints it in the browser's console at start: "Build configuration: Emscripten 4.0.20").
