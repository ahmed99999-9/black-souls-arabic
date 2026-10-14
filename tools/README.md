# tools/

Developer tooling for the Black Souls Arabic build. Nothing here is shipped to
players; the game itself is the project root (`Game.exe`, `Data/`, `Graphics/`,
`Audio/`, `Fonts/`).

## build_joiplay.rb

Builds the Android/JoiPlay distribution (`joiplay/BLACK_SOULS_ARABIC/` +
`joiplay/BLACK_SOULS_ARABIC_joiplay_v1.1.0.zip`). The Windows build at the repo
root is never modified.

```sh
ruby tools/build_joiplay.rb             # audit + stage + zip
ruby tools/build_joiplay.rb --check-only # audit only (safe on any machine)
ruby tools/build_joiplay.rb --stage-only # audit + stage, no zip
ruby tools/build_joiplay.rb --zip-only   # re-zip an existing staged folder
```

What the build does:

1. **Audit** (`audit!`) — fails the build on any problem:
   - every `Data/Map*.rvdata2` loads and its event hash keys are Integers
     (the "map key" bug class: keys stored as String break movement/erase);
   - self-switch condition characters are in `A..D`;
   - fade balance: no `Fadeout Screen` (221) without a matching `Fadein
     Screen` (222) in the same page/common event — this is the black-screen
     cutscene bug class;
   - enemy death pages (self-switch `D`) either erase the event (214) or are
     already invisible (no graphic, no commands) — the "corpse respawn" bug
     class;
   - picture references (231) exist in `Graphics/Pictures`;
   - `Data/Scripts.rvdata2` still carries the JoiPlay `Win32API` guard in the
     Window Title script.
2. Stages `Data/ Graphics/ Audio/ Fonts/ Bonus/` and strips anything that is
   not `*.rvdata2` from `Data/`.
3. Writes `Game.rvproj2` (the JoiPlay game marker) and a plain-ASCII
   `Game.ini` (the Windows one is UTF-16LE and confuses mkxp's ini parser).
4. Converts all MP3 to OGG (mkxp cannot decode MP3).
5. Writes bilingual install instructions and zips the folder.

### ffmpeg

Needed only for the MP3→OGG step. Lookup order:

1. `ENV["FFMPEG"]`
2. `vendor/ffmpeg/usr/bin/ffmpeg` — project-local, extracted with
   `vendor/ffmpeg/usr/lib/x86_64-linux-gnu` on `LD_LIBRARY_PATH`. Install with
   any static x86_64 ffmpeg build:

   ```sh
   mkdir -p vendor/ffmpeg/usr/bin vendor/ffmpeg/usr/lib
   tar -xf ffmpeg-*.tar.xz -C vendor/ffmpeg/usr/bin --strip-components=1
   # (or copy /usr/bin/ffmpeg + its libav* libraries into vendor/ffmpeg)
   ```

   `vendor/` is git-ignored on purpose.
3. `ffmpeg` on `PATH`.

If MP3s remain and no ffmpeg is found the build stops with exit 1 instead of
shipping an Android build with unplayable music.

## dev/

Archived one-off diagnostic scripts from the localization work (map checks,
death-page analysis, script dumps, binary structure probes…). They are kept for
reproducibility, not for regular use — the durable checks live in
`audit!` above and in `dev/verify_fixes.rb`.

Every script in `dev/` starts with a small shim that `chdir`s to the project
root, so they can be run from any directory:

```sh
ruby tools/dev/verify_fixes.rb   # full fix verification report
```

They only need a plain Ruby (tested with 3.3) and read/write nothing outside
the project; temporary output goes to `/tmp`.
