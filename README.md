# Octane Asset Reuploader (2021 Studio Edition)

Asset Reuploader modified and optimized for the **Octane** Roblox revival (`octane.wtf`, formerly Aisaka) and **Roblox Studio 2021 (build 0.477)**.

Based on the original [Asset-Reuploader](https://github.com/kartFr/Asset-Reuploader) by kartFr.

---

## ✨ Features

- **Dual-Cookie Architecture**:
  - `roblox_cookie.txt`: Authenticates with official Roblox to download private/protected assets, animations, and sound files.
  - `cookie.txt`: Authenticates with Octane (`octane.wtf`) to upload and publish reuploaded assets directly to your Octane account.
- **Animations (`develop?View=24`)**:
  - Extracts keyframe sequences and animation data from official Roblox.
  - Publishes them as native Octane Animation assets.
  - Automatically replaces `AnimationId`s across all instances and scripts in your game.
- **Audio / Sounds (`develop?View=3`)**:
  - Downloads original audio files (MP3/OGG) directly from official Roblox CDN.
  - Uploads to Octane as Sound assets (Octane charges 15 Robux per audio upload).
  - Automatically updates `SoundId` references throughout your place.
- **Gamepasses as T-Shirts (`develop?View=2`)**:
  - Scans all scripts (`GamepassManager`, shops, UI controllers) for Gamepass IDs.
  - Downloads official gamepass icons and publishes them to Octane as T-Shirts.
  - Features a 1-click **Convert APIs** button to convert `MarketplaceService:UserOwnsGamePassAsync` calls into `Player:PlayerOwnsAsset` so gamepass functionality works natively in 2021 Studio!
- **2021 Studio / Revival Engine Compatibility**:
  - Patched Luau syntax (compatible with 2021 build 477 without modern type syntax issues).
  - Isolated datamodel traversal preventing `identity 5 lacks permission 6` crashes on internal CoreGui services.
  - Polyfilled `task` scheduling library (`task.spawn`, `task.wait`, `task.delay`).
  - Embedded relative module require resolver.

---

## 🚀 Setup & Usage

### 1. Configuration
1. Open `cookie.txt` and paste your **Octane session cookie** (from `octane.wtf`).
2. Open `roblox_cookie.txt` and paste your **official Roblox `.ROBLOSECURITY`** cookie (required for downloading private/protected sounds and animations).
3. Open `config.ini` and verify the settings:
   ```ini
   port=38073
   domain=octane.wtf
   user_id=YOUR_OCTANE_USER_ID
   cookie_file=cookie.txt
   roblox_cookie_file=roblox_cookie.txt
   ```
   *(Replace `YOUR_OCTANE_USER_ID` with your numeric user ID from your Octane profile URL, e.g. `https://octane.wtf/users/24811/profile`)*

### 2. Install the Studio Plugin
- Copy `AssetReuploader2021.rbxmx` into your Roblox Studio plugins directory:
  ```
  %localappdata%\Roblox\Plugins\AssetReuploader2021.rbxmx
  ```

### 3. Run the Reuploader Backend
- Double-click `assetreuploader.exe`.
- Ensure it displays:
  ```text
  Authenticating cookie...
  Official Roblox download cookie loaded!
  localhost started on port 38073. Waiting to start reuploading.
  ```

### 4. Reupload Assets in Studio
1. Open your place in Octane Studio.
2. In the **Plugins** ribbon bar, click **Asset Reuploader**.
3. Select your target tab:
   - **Animation**: Scan and migrate animations.
   - **Sound**: Scan and migrate audio files.
   - **Gamepass**: Scan scripts for gamepass IDs, upload icons as T-Shirts, and convert gamepass check APIs with one click.
   - **Replace**: Search & replace specific IDs manually.
4. Click **Reupload** and wait for the migration to complete!

---

## 🛠️ Building from Source

### Requirements
- [Go](https://go.dev/) 1.21+
- [Rojo](https://rojo.space/) 7.x

### Build the Backend
```bash
go build -o assetreuploader.exe ./cmd/assetreuploader
```

### Build the Studio Plugin
```bash
cd plugin
rojo build default.project.json -o AssetReuploader2021.rbxmx
```

---

## 📜 Credits & License

- Original project by [kartFr](https://github.com/kartFr/Asset-Reuploader).
- Licensed under the [GNU General Public License v3.0](LICENSE).
