# Agents

## Project overview

**threemf** is a macOS Quick Look plugin, Spotlight Importer, Finder Sync extension, and CLI for previewing `.3mf`, `.stl`, and `.gcode` 3D printing files. Press Space on a file in Finder to see an interactive 3D preview with orbit, pan, zoom, and layer scrubbing.

## Architecture

```
Sources/
├── HostApp/           # Minimal SwiftUI host app + App Intents (Shortcuts)
├── Shared/            # Core logic (ThreeMFCore) shared across targets
│   ├── MeshData.swift             # Vertex/index/normal/plate data model
│   ├── STLParser.swift            # Binary + ASCII STL parser (parallel at ≥100K tris)
│   ├── ThreeMFMeshParser.swift    # 3MF XML mesh parser (ZIP + component refs)
│   ├── ThreeMFExtractor.swift     # PNG thumbnail + plate JSON extractor from 3MF ZIP
│   ├── BambuModelConfig.swift     # Bambu/Orca model_settings + filament palette + MMU paint
│   ├── GCodeParser.swift          # G0/G1/G2/G3/G90/G91/G92/M82/M83 G-code toolpath parser
│   ├── SceneBuilder.swift         # Creates SceneKit scene from MeshData
│   ├── ToolpathSceneBuilder.swift # Creates per-layer SceneKit line scene from ToolpathData
│   ├── ThumbnailCache.swift       # Disk-backed LRU PNG thumbnail cache
│   ├── BoundedFileReader.swift    # Stat-before-read size cap enforcement
│   ├── ResourceLimits.swift       # Quick Look vs CLI resource limit profiles
│   ├── ParseCancellation.swift    # Cooperative cancellation across parsers
│   └── SafePNGValidator.swift     # ImageIO header validation before NSImage decode
├── PreviewExtension/  # QLPreviewingController — spacebar 3D/toolpath preview
├── ThumbnailExtension/# QLThumbnailProvider — Finder icon thumbnails
├── MDImporter/        # CSImportExtension — Spotlight metadata indexing
├── FinderSync/        # FIFinderSync — "Open in Bambu Studio / PrusaSlicer / OrcaSlicer"
└── CLI/               # threemf-cli — headless info, validate, thumbnail, and batch commands
Tests/                 # Unit, fuzzing, and performance tests
```

## Build

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
xcodebuild -project threemf.xcodeproj -scheme ThreeMFQuickLook -configuration Release build
```

For CI (no code signing):
```bash
xcodebuild ... CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## Test

```bash
xcodebuild -project threemf.xcodeproj -scheme ThreeMFTests -configuration Debug test
swift test
```

## Key decisions

- **Brand**: always "threemf" (lowercase, one word)
- **Fast preview path**: `.3mf` files under 2 MB load the interactive 3D mesh directly; larger `.3mf` files display the embedded plate PNG thumbnail immediately with a "Show 3D" button and `←`/`→` plate cycling
- **Z-up to Y-up**: 3D printing models use Z as vertical axis, SceneKit uses Y — apply -90° X rotation
- **SceneKit for rendering**: uses Metal under the hood, no custom shaders — SCNGeometry + SCNView with `allowsCameraControl`
- **Custom scroll handling**: `ZoomSCNView` subclass overrides scroll wheel for FOV zoom instead of dolly
- **Right-click pan**: custom `rightMouseDragged` handler for camera panning
- **macOS 14+**: deployment target is Sonoma; local builds are arm64, release builds are universal (arm64 + x86_64)
- **No external deps except ZIPFoundation**: STL parsing, XML parsing, SceneKit rendering all use system frameworks
- **Vertex deduplication**: STL parser uses quantized coordinate keys (multiply by 10000, round to Int32) for fast dedup

## 3MF format notes

- `.3mf` files are ZIP archives
- Root model at `3D/3dmodel.model` (XML)
- Bambu Studio stores meshes in external files referenced via `<component p:path="/3D/Objects/object_N.model">`
- Build placement via `<build><item objectid="N" transform="..."/>` — 12-float column-major affine transform
- Thumbnails at `Metadata/plate_1.png` (and variants)

## CI/CD

- **test.yml**: runs on push/PR to main
- **release.yml**: runs on tag push (`v*`) — builds, signs, notarizes, creates GitHub release with SLSA provenance, updates Homebrew tap
- **codeql.yml**: CodeQL security scanning on push/PR + weekly
- **dependency-review.yml**: checks for vulnerable deps on PRs

## Don't

- Don't add Co-Authored-By to commits
- Don't use "3MF", "3mf", "three-mf" as the brand name — it's "threemf"
- Don't forget SBOM (`sbom.json`) when adding dependencies
