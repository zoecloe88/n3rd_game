# Upload MP4 Videos to Firebase Storage

## Quick Upload via Firebase Console

Since direct upload scripts require authentication setup, here's the easiest way to upload your MP4 videos:

### Steps:

1. **Open Firebase Console:**
   - Go to: https://console.firebase.google.com/project/wordn3rd-7bd5d/storage

2. **Navigate to Storage:**
   - Click on "Storage" in the left sidebar
   - Click "Get started" if this is your first time

3. **Create Public Folder Structure:**
   - Click "Add folder"
   - Create folder: `public`
   - Inside `public`, create folder: `videos`

4. **Upload MP4 Files:**
   - Navigate to `public/videos/`
   - Click "Upload file"
   - Upload each of these files:
     - `loginscreen.mp4`
     - `titlescreen.mp4`
     - `settingscreen.mp4`
     - `statscreen.mp4`
     - `modeselectionscreen.mp4`
     - `modeselection2.mp4`
     - `modeselection3.mp4`
     - `modeselectiontransitionscreen.mp4`
     - `wordoftheday.mp4`
     - `edition.mp4`
     - `youthscreen.mp4`
     - `logoloadingscreen.mp4`

5. **Set Public Access:**
   - After uploading, ensure the files are publicly readable
   - The storage rules already allow public read access for `/public/**`

6. **Get Download URLs:**
   - Click on each file
   - Copy the "Download URL" (format: `https://firebasestorage.googleapis.com/...`)

## Alternative: Using Firebase CLI

If you have Firebase CLI installed and authenticated:

```bash
# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Login (if not already)
firebase login

# Upload files using gsutil (requires Google Cloud SDK)
gsutil -m cp assets/*.mp4 gs://wordn3rd-7bd5d.firebasestorage.app/public/videos/
```

## After Upload

Once files are uploaded, you can:
1. Use the download URLs in your app instead of local assets
2. This reduces app bundle size
3. Allows for easier video updates without app updates

## Current Storage Rules

Your storage rules already allow public read access:
```
match /public/{allPaths=**} {
  allow read: if true;
  allow write: if false; // Only Cloud Functions or Admin can write
}
```

This means uploaded videos will be publicly accessible via their download URLs.

