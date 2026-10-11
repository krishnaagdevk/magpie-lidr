# Magpie Handoff Bundle Specification (Format v1)

## Overview
A `.magpie` handoff bundle is an uncompressed or standard ZIP archive transferred from the Magpie Field iOS application to Magpie Studio via `POST /api/handoffs`.

## File Structure
```
package.magpie (ZIP)
├── manifest.json         # Package metadata, site identifier, and file manifest
├── plan.json             # Canonical EditedPlan JSON (walls, openings, rooms)
├── measurements.json     # Certified measurements and gate validation payload
├── model.usdz            # (Optional) Exported 3D LiDAR room mesh
└── photos/               # (Optional) Captured photo attachments
    ├── photo-1.jpg
    └── photo-2.jpg
```

## Archive Constraints
- **Compression**: Uncompressed (method 0 / Stored) or standard Deflate.
- **Max Package Size**: 64 MiB (`MAGPIE_PACKAGE_LIMITS.maxBytes`).
- **Path Security**: UTF-8 filenames, maximum 200 characters, no directory traversal (`../`), no root slashes.

## Required Documents

### 1. `manifest.json`
```json
{
  "format": "magpie-package",
  "version": 1,
  "producer": "ios",
  "title": "Kitchen Scan 101",
  "siteId": "SITE-A12",
  "capturedAt": "2026-10-10T14:30:00Z",
  "files": [
    "manifest.json",
    "plan.json",
    "measurements.json",
    "model.usdz"
  ]
}
```

### 2. `plan.json`
Canonical JSON representation of `EditedPlan` containing stories, walls, dimensions, transforms, and rooms.

### 3. `measurements.json`
Canonical JSON representation of `MeasurementsPayload` containing:
- `measurementsVersion`: 1
- `siteId`: Site identifier
- `dimensions`: Array of scanned and tape-verified measurement items
- `validation`: Hard gate validation results (`gateResult`, `criticalCount`, `passRate`)

## Transfer Protocol
1. **Upload**: Client sends `POST /api/handoffs` (or `POST /api/handoffs/:siteId`) with header `Content-Type: application/zip` and `x-magpie-package: true`. Optional `Authorization: Bearer <token>`.
2. **Response**: Server responds with HTTP 201:
   ```json
   {
     "code": "8-char-alphanumeric-code",
     "reuseUntil": "2026-10-11T14:30:00.000Z",
     "packageType": "magpie-package"
   }
   ```
3. **Retrieval**: Editor fetches the package at `inbox/{code}.magpie` or through `?import={code}`.
