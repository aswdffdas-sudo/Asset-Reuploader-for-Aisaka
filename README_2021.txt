================================================================================
   ASSET REUPLOADER - AISAKA REVIVAL (ANIMATIONS, AUDIOS, GAMEPASSES)
================================================================================

This edition is fully integrated with Aisaka (https://www.aisaka.me):

1. ANIMATION UPLOADS (develop?View=24):
   - Downloads original animations from Roblox.
   - Uploads to Aisaka as AssetType 24 (Animation).
   - Automatically replaces AnimationId across your game!

2. AUDIO / SOUND UPLOADS (develop?View=3):
   - Downloads original MP3/OGG sound files from Roblox.
   - Uploads directly to Aisaka (https://www.aisaka.me/develop?View=3) as AssetType 3 (Audio).
   - Automatically replaces SoundId across your game!
   * Note: Aisaka charges 15 Robux per audio upload.

3. GAMEPASSES AS T-SHIRTS (develop?View=2):
   - Scans game scripts (GamepassManager, Shop, etc.) for Gamepass IDs.
   - Automatically downloads the official gamepass badges/icons from Roblox.
   - Publishes them to Aisaka as T-Shirts (AssetType 2).
   - Automatically replaces the old Gamepass IDs with the new Aisaka T-Shirt IDs!
   - Features a 1-click "Convert APIs" button to turn UserOwnsGamePassAsync into
     PlayerOwnsAsset so gamepass checks work natively in 2021 Studio!

--------------------------------------------------------------------------------
SETUP:
--------------------------------------------------------------------------------
1. cookie.txt -> Your AISAKA session cookie (from aisaka.me).
2. roblox_cookie.txt -> Your OFFICIAL ROBLOX .ROBLOSECURITY (to download private assets).
3. config.ini ->
   port=38073
   domain=aisaka.me
   user_id=24811
   cookie_file=cookie.txt
   roblox_cookie_file=roblox_cookie.txt

4. Double-click `assetreuploader.exe`.
5. In Aisaka Studio, open the Asset Reuploader plugin, pick your tab, and click Reupload!
================================================================================
