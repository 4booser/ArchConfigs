#!/usr/bin/env bash
set -euo pipefail

asset_dir="$HOME/.config/quickshell/dashboard/assets"
icon_dir="$asset_dir/icons"
mkdir -p "$asset_dir" "$icon_dir"

write_icon() {
    local name="$1"
    local body="$2"
    cat > "$icon_dir/$name.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#dff8ff" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">
$body
</svg>
SVG
}

write_icon grid '<rect x="4" y="4" width="6" height="6" rx="1.5"/><rect x="14" y="4" width="6" height="6" rx="1.5"/><rect x="4" y="14" width="6" height="6" rx="1.5"/><rect x="14" y="14" width="6" height="6" rx="1.5"/>'
write_icon music '<path d="M9 18V5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16" r="3"/>'
write_icon activity '<path d="M4 13h4l2-7 4 13 2-6h4"/>'
write_icon cloud '<path d="M17.5 18H8a5 5 0 1 1 1.3-9.8A6 6 0 0 1 20 12.5 3.5 3.5 0 0 1 17.5 18Z"/>'
write_icon power '<path d="M12 3v8"/><path d="M7.1 6.2a8 8 0 1 0 9.8 0"/>'
write_icon apps '<rect x="4" y="4" width="5" height="5" rx="1"/><rect x="15" y="4" width="5" height="5" rx="1"/><rect x="4" y="15" width="5" height="5" rx="1"/><rect x="15" y="15" width="5" height="5" rx="1"/>'
write_icon network '<path d="M4 16.5a12 12 0 0 1 16 0"/><path d="M7.5 13a7 7 0 0 1 9 0"/><path d="M10.5 9.5a3 3 0 0 1 3 0"/><circle cx="12" cy="19" r="1"/>'
write_icon settings '<path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z"/><path d="M4 12h2m12 0h2M12 4v2m0 12v2M6.3 6.3l1.4 1.4m8.6 8.6 1.4 1.4m0-11.4-1.4 1.4m-8.6 8.6-1.4 1.4"/>'
write_icon refresh '<path d="M20 6v5h-5"/><path d="M4 18v-5h5"/><path d="M18 9a7 7 0 0 0-11.7-2.7L4 8.5"/><path d="M6 15a7 7 0 0 0 11.7 2.7L20 15.5"/>'
write_icon close '<path d="M6 6l12 12"/><path d="M18 6 6 18"/>'

bongo_file="$asset_dir/bongo-cat.gif"
if [[ ! -s "$bongo_file" ]]; then
    echo "Put your bongo cat gif here: $bongo_file" >&2
fi

avatar_file="$asset_dir/avatar.png"
if [[ ! -s "$avatar_file" ]]; then
    echo "Optional avatar slot: $avatar_file" >&2
fi

chmod -R u+rwX,go+rX "$asset_dir"
echo "Dashboard assets installed in: $asset_dir"
