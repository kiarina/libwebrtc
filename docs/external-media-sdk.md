# External-media SDK integration

The `codex/spirits-external-media` branch merges factory policy PR#158 while
keeping its PR topic separate. Its native core integration is pinned in
`integration/windows-x64-inputs.json`. This is a downstream pre-release, not an
upstream merge or a stock SDK claim.

Build the corresponding core + wrapper using the repository's GN instructions.
The core integration already contains the three ordinary m150 wrapper patches;
do not apply those twice. The input manifest includes the measured build flags,
source hashes and tested binary/import-library identities. A different rebuilt
binary requires its own validation/manifest rather than claiming byte identity.

For the existing validated Windows x64 candidate, run the packaging script with
explicit core source, wrapper source, staged SDK root and a fresh output folder:

```powershell
./tools/package_external_media_sdk.ps1 -CoreSource $env:WEBRTC_SOURCE -WrapperSource $env:LIBWEBRTC_SOURCE -SdkRoot $env:SDK_ROOT -OutputDirectory build/package
```

The script checks all listed wrapper production sources, changed native core
production files, staged headers and the known DLL/import library before copying.
The archive contains only headers, binaries, source manifest and license notices;
private build paths, debug symbols, recordings and trace logs are excluded.
Consumers must verify the archive and per-file hashes and use matching headers,
import library and DLL. Known test limits remain in the validation lab; this is
not a full core presubmit or all-platform pass.
