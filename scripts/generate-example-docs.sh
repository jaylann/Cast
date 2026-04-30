#!/usr/bin/env bash
# Generate one DocC article per Examples/Sources/<Name>/main.swift.
# Output goes to Sources/Cast/Cast.docc/Examples/<Name>.md.
# Articles are checked into the repo so local DocC preview works without
# running this script first; CI regenerates them before publishing so any
# drift is corrected on merge.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLES_DIR="$ROOT/Examples/Sources"
OUT_DIR="$ROOT/Sources/Cast/Cast.docc/Examples"

mkdir -p "$OUT_DIR"
find "$OUT_DIR" -name '*.md' -delete

count=0
for src in "$EXAMPLES_DIR"/*/main.swift; do
    [ -f "$src" ] || continue
    name="$(basename "$(dirname "$src")")"
    out="$OUT_DIR/$name.md"

    # Pull the leading "// What this shows: ..." block (contiguous // lines
    # at top-of-file). Strip the "// " prefix and the "What this shows: " tag.
    description="$(awk '
        /^\/\// { sub(/^\/\/ ?/, ""); print; next }
        { exit }
    ' "$src" | sed '1s/^What this shows: //')"

    {
        printf '# %s\n\n' "$name"
        if [ -n "$description" ]; then
            printf '%s\n\n' "$description"
        fi
        printf '## Source\n\n'
        printf 'Full source: [Examples/Sources/%s/main.swift](https://github.com/jaylann/Cast/blob/main/Examples/Sources/%s/main.swift)\n\n' "$name" "$name"
        printf '```swift\n'
        cat "$src"
        printf '```\n'
    } > "$out"

    count=$((count + 1))
done

echo "Generated $count example article(s) in $OUT_DIR"
