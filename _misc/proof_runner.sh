cat > /storage/emulated/0/Download/_backup/planetary-restoration-archive/proof_root.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

termux-setup-storage || true
export PATH="$HOME/.local/bin:$PATH"

ROOT_DIR="/storage/emulated/0/Download/_backup/planetary-restoration-archive"

TS="$(date -u +%Y%m%d-%H%M%SZ)"
OUT_ZIP="${ROOT_DIR}/planetary-restoration-archive_${TS}.zip"
WORK="${ROOT_DIR}/.proofwork_root_${TS}"
MANIFEST="${WORK}/planetary-restoration-archive.ip_proof_manifest.json"
README="${WORK}/README_proof.txt"

mkdir -p "$WORK"
say(){ printf "%s\n" "$*" >&2; }

say "———"
say "Packaging full folder: $ROOT_DIR"

cd "$(dirname "$ROOT_DIR")"
zip -q -9 -r -X "$OUT_ZIP" "$(basename "$ROOT_DIR")"

# Hash the bundle itself
SHA256_ZIP="$(sha256sum "$OUT_ZIP" | awk '{print $1}')"
SHA512_ZIP="$(sha512sum "$OUT_ZIP" | awk '{print $1}')"
SIZE_ZIP="$(stat -c%s "$OUT_ZIP" 2>/dev/null || stat -f%z "$OUT_ZIP")"
MTIME_EPOCH="$(stat -c%Y "$OUT_ZIP" 2>/dev/null || stat -f%m "$OUT_ZIP")"
MTIME_ZIP="$(date -u -d "@$MTIME_EPOCH" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$MTIME_EPOCH" +%Y-%m-%dT%H:%M:%SZ)"

# Per-file hashes inside the root folder
TMP_JSONL="$WORK/files.jsonl"; : > "$TMP_JSONL"
cd "$ROOT_DIR"
find . -type f -print0 | sort -z | while IFS= read -r -d '' F; do
  H="$(sha256sum "$F" | awk '{print $1}')"
  S="$(stat -c%s "$F" 2>/dev/null || stat -f%z "$F")"
  jq -c --null-input --arg path "$F" --arg sha256 "$H" --arg size "$S" \
     '{path:$path, sha256:$sha256, size: ($size|tonumber? // $size)}' >> "$TMP_JSONL"
done

# Manifest includes both the whole-zip info and per-file proofs
jq -s --arg created "$TS" \
      --arg zip_path "$OUT_ZIP" \
      --arg sha256_zip "$SHA256_ZIP" \
      --arg sha512_zip "$SHA512_ZIP" \
      --arg size_zip "$SIZE_ZIP" \
      --arg mtime_zip "$MTIME_ZIP" \
      '{
        version:"1.0",
        created_utc:$created,
        target:{ path:$zip_path, size:($size_zip|tonumber), mtime_utc:$mtime_zip,
                 sha256:$sha256_zip, sha512:$sha512_zip },
        files: .
      }' "$TMP_JSONL" > "$MANIFEST"

# README instructions for court / third parties
cat > "$README" <<TXT
Planetary Restoration Archive — Proof Package
=============================================

Created UTC: $TS

Contents:
---------
1. Main archive: $(basename "$OUT_ZIP")
2. Manifest:     $(basename "$MANIFEST")
3. Checksums:    $(basename "$OUT_ZIP").checksums
4. OTS receipts: (if available, *.ots files)

Verification steps:
-------------------
1. Verify the archive against its checksums:
   sha256sum -c $(basename "$OUT_ZIP").checksums

2. Inspect the manifest:
   jq . $(basename "$MANIFEST") | less

3. Verify OTS receipts (if present):
   ots verify $(basename "$OUT_ZIP").ots
   ots verify $(basename "$MANIFEST").ots

4. Compare per-file hashes in the manifest against your local copy.

Legal note:
-----------
This package is tamper-evident. Any change in a single bit will break
its cryptographic hash and OTS receipt.
TXT

# Stamp everything if ots present
if command -v ots >/dev/null 2>&1; then
  ots stamp "$OUT_ZIP" || true
  ots stamp "$MANIFEST" || true
  ots stamp "$README" || true
fi

# Checksums
( sha256sum "$OUT_ZIP"; sha512sum "$OUT_ZIP" ) > "${OUT_ZIP}.checksums"

say "✓ Done."
say "Archive: $OUT_ZIP"
say "Manifest: $MANIFEST"
say "Checksums: ${OUT_ZIP}.checksums"
say "README: $README"
BASH

chmod +x /storage/emulated/0/Download/_backup/planetary-restoration-archive/proof_root.sh
