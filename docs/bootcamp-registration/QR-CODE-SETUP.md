# QR Code Setup Guide — Embed Images Directly in n8n

Instead of using external URLs for QR codes, both registration forms now embed images directly as **base64 data URIs**. This provides several advantages:

## ✅ Benefits

| Advantage | Description |
|-----------|-------------|
| **No External Dependencies** | QR codes are part of the workflow JSON — no image hosting needed |
| **Faster Loading** | Images load instantly without external HTTP requests |
| **No Broken Links** | Images can never be deleted or moved |
| **Offline Compatible** | Forms work even if image host is down |
| **Version Control** | QR codes are versioned with your workflow |
| **No API Keys** | No need for Imgur, Cloudinary, or cloud storage APIs |

---

## 📋 How It Works

Instead of:
```json
"qrImageUrl": "https://i.imgur.com/abc123.png"
```

You use:
```json
"qrImageUrl": "data:image/png;base64,iVBORw0KGgoAAAANS..."
```

The browser decodes the base64 string and displays the image directly.

---

## 🛠️ Converting Your QR Images

You need **2 QR codes**:
1. **Live Class** QR code (`qr-live.png`) — for $49.99 payment
2. **Video Course** QR code (`qr-video.png`) — for $29.99 payment

### Method 1: Command Line (macOS/Linux) ⚡ Fastest

```bash
# Convert QR images to base64
base64 -i qr-live.png | tr -d '\n' > qr-live-base64.txt
base64 -i qr-video.png | tr -d '\n' > qr-video-base64.txt

# Now open the .txt files and copy the base64 strings
```

**Why `tr -d '\n'`?** Removes line breaks to create a single continuous string.

---

### Method 2: Online Tool 🌐 No Installation

1. Go to **[base64.guru/converter/encode/image](https://base64.guru/converter/encode/image)**
2. Click "Choose File" and upload `qr-live.png`
3. Click "Encode to Base64"
4. Copy the output (it may include `data:image/png;base64,` — **remove that prefix**)
5. Repeat for `qr-video.png`

**Note:** Only copy the long string of letters/numbers, NOT the `data:image/png;base64,` part if it's included (we already have that in the workflow).

---

### Method 3: Python Script 🐍 Automated

Create a file `convert_qr.py`:

```python
import base64

def convert_qr_to_base64(image_path, output_file):
    """Convert image to base64 and save to file"""
    with open(image_path, "rb") as img_file:
        b64_string = base64.b64encode(img_file.read()).decode()
    
    with open(output_file, "w") as out_file:
        out_file.write(b64_string)
    
    print(f"✅ Converted {image_path} → {output_file}")
    print(f"   Length: {len(b64_string)} characters")

# Convert both QR codes
convert_qr_to_base64("qr-live.png", "qr-live-base64.txt")
convert_qr_to_base64("qr-video.png", "qr-video-base64.txt")

print("\n🎉 Done! Open the .txt files and copy the base64 strings.")
```

Run it:
```bash
python3 convert_qr.py
```

---

### Method 4: Node.js 📦 For Developers

```javascript
const fs = require('fs');

function convertToBase64(imagePath, outputFile) {
  const imageBuffer = fs.readFileSync(imagePath);
  const base64String = imageBuffer.toString('base64');
  
  fs.writeFileSync(outputFile, base64String);
  console.log(`✅ Converted ${imagePath} → ${outputFile}`);
  console.log(`   Length: ${base64String.length} characters`);
}

convertToBase64('qr-live.png', 'qr-live-base64.txt');
convertToBase64('qr-video.png', 'qr-video-base64.txt');

console.log('\n🎉 Done! Open the .txt files and copy the base64 strings.');
```

Run it:
```bash
node convert_qr.js
```

---

## 📝 Updating the Workflow

After converting your QR images to base64, you need to add them to the workflow JSON file.

### Step-by-Step:

1. **Open the workflow file** in a text editor (VS Code, Sublime, etc.):
   - `bootcamp-registration-simple.json` (for simple form)
   - `bootcamp-registration-standalone.json` (for authenticated form)

2. **Find the placeholders** (Ctrl/Cmd + F):
   ```
   REPLACE_WITH_YOUR_LIVE_QR_BASE64
   REPLACE_WITH_YOUR_VIDEO_QR_BASE64
   ```

3. **Replace them with your base64 strings**

**Before:**
```json
"value": "={{ $('Form — Page 1: Track Selection').item.json['Select Your Track'].includes('Live') ? 'data:image/png;base64,REPLACE_WITH_YOUR_LIVE_QR_BASE64' : 'data:image/png;base64,REPLACE_WITH_YOUR_VIDEO_QR_BASE64' }}"
```

**After:**
```json
"value": "={{ $('Form — Page 1: Track Selection').item.json['Select Your Track'].includes('Live') ? 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...(very long string)...CYII=' : 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...(another long string)...SUVORK5CYII=' }}"
```

4. **Save the file**

5. **Re-import to n8n**:
   - Delete the old workflow (if already imported)
   - Click "Import from File"
   - Select your updated JSON file
   - Activate the workflow

---

## ⚠️ Important Notes

### File Size Limits

| Image Type | Recommended Size | Max Recommended |
|------------|------------------|-----------------|
| **QR Code PNG** | 280×280 px | 512×512 px |
| **File Size** | < 10 KB | < 50 KB |
| **Base64 Length** | ~13,000 chars | ~70,000 chars |

**Why keep it small?**
- Large base64 strings make the JSON file harder to edit
- n8n may have limits on form field sizes
- Faster page loading

### Optimizing QR Images

Before converting to base64:

```bash
# Install imagemagick (macOS)
brew install imagemagick

# Resize to 280x280 (optimal for the form)
convert qr-live.png -resize 280x280 qr-live-optimized.png
convert qr-video.png -resize 280x280 qr-video-optimized.png

# Then convert optimized images to base64
base64 -i qr-live-optimized.png | tr -d '\n' > qr-live-base64.txt
```

### Supported Image Formats

| Format | Recommended | Base64 Prefix |
|--------|-------------|---------------|
| **PNG** | ✅ Best | `data:image/png;base64,` |
| **JPEG** | ✅ Good | `data:image/jpeg;base64,` |
| **WebP** | ⚠️ Limited browser support | `data:image/webp;base64,` |
| **SVG** | ⚠️ Use PNG instead | `data:image/svg+xml;base64,` |

**Recommendation:** Use PNG for QR codes (best quality, transparent background).

---

## 🔍 Troubleshooting

### Issue: QR code not displaying in form

**Possible causes:**
1. Incorrect base64 prefix (must be `data:image/png;base64,`)
2. Base64 string has line breaks (use `tr -d '\n'`)
3. File is too large (> 100 KB)

**Solution:**
```bash
# Re-convert with proper formatting
base64 -i qr-live.png | tr -d '\n' | pbcopy  # macOS (copies to clipboard)
base64 -i qr-live.png | tr -d '\n' | xclip   # Linux (copies to clipboard)
```

### Issue: Workflow JSON is too large

**Solution:** Reduce image size:
```bash
# Resize to 280x280 and reduce quality
convert qr-live.png -resize 280x280 -quality 85 qr-live-small.png
```

### Issue: Base64 string is broken across lines in JSON

**Solution:** Ensure the entire base64 string is on one line in the JSON file. Use a text editor's "Join Lines" feature if needed.

---

## 📊 Comparison: URLs vs Base64

| Aspect | External URLs | Base64 Embedded |
|--------|---------------|-----------------|
| **Setup Complexity** | Upload to Imgur/Drive | Convert to base64 |
| **Dependencies** | Imgur/Cloudinary/Drive | None |
| **Can Break?** | Yes (deleted/moved) | No |
| **Load Time** | 100-500ms (HTTP request) | Instant (inline) |
| **Requires Internet** | Yes | No (after initial load) |
| **Needs API Keys** | Sometimes | No |
| **Version Control** | Separate files | Part of workflow |
| **Easy to Update?** | Very easy (just upload) | Need to re-convert |

**Verdict:** Base64 is better for production, URLs are better for frequent testing/changes.

---

## 🚀 Quick Start Commands

```bash
# Full workflow (macOS/Linux)
# 1. Convert images
base64 -i qr-live.png | tr -d '\n' > qr-live-base64.txt
base64 -i qr-video.png | tr -d '\n' > qr-video-base64.txt

# 2. Open workflow JSON in VS Code
code bootcamp-registration-simple.json

# 3. Find and replace (Cmd/Ctrl + F):
#    - Search: REPLACE_WITH_YOUR_LIVE_QR_BASE64
#    - Replace: [paste from qr-live-base64.txt]
#    - Search: REPLACE_WITH_YOUR_VIDEO_QR_BASE64
#    - Replace: [paste from qr-video-base64.txt]

# 4. Save and re-import to n8n

echo "✅ QR codes embedded! Your form is now fully self-contained."
```

---

## 💡 Tips

1. **Keep Original Images:** Save your original QR PNGs in case you need to regenerate
2. **Test Both QR Codes:** Scan both to ensure they work before converting
3. **Backup Workflow:** Keep a copy of the JSON file with working QR codes
4. **Use Git:** Track changes to your workflow JSON files
5. **Document QR Details:** Note what payment methods each QR supports (ABA, Wing, etc.)

---

## 🆘 Need Help?

If you get stuck:

1. Check that your base64 string starts immediately after `data:image/png;base64,`
2. Verify no line breaks in the base64 string
3. Test your base64 in a browser console:
   ```javascript
   const img = new Image();
   img.src = 'data:image/png;base64,YOUR_BASE64_HERE';
   document.body.appendChild(img);
   ```
4. Check n8n execution logs for errors

---

**Done!** 🎉 Your QR codes are now embedded directly in your n8n workflow.
