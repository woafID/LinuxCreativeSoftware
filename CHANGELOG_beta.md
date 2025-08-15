VERSION 103b
- Added a global sudo password prompt to prevent timeouts, which can cause issues when not paying attention to the setup process.
- Replaced interactive zenity prompts that interrupted the seamless setup with auto-closing ones.
- Updated Wine to version 10.3.
- Modernized the winmd file implementation, replacing the outdated method with a single file and accompanying DLL (the old method appears to be incompatible with Wine 10+).
- Added wintypes.dll to the Affinity root directory to support the new winmd file approach.
- Fixed SVG icons used in the .desktop files appearing incorrectly on Plasma by renaming them, as they had standard names like "photo.svg".
- Added version numbers to the script.
