#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk

HOME = Path.home()
SCRIPT_DIR = Path(__file__).resolve().parent
HYPR_DIR = SCRIPT_DIR.parent
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "hypr-control-center"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

CSS = b"""
window {
    background: rgba(12, 14, 20, 0.96);
    color: #cdd6f4;
    border-radius: 22px;
}

.root {
    padding: 18px;
}

.header-title {
    font-size: 23px;
    font-weight: 800;
    color: #ffffff;
}

.header-subtitle {
    font-size: 12px;
    color: #8f9bb3;
}

.search {
    min-height: 42px;
    padding: 0 14px;
    border-radius: 14px;
    border: 1px solid rgba(137, 180, 250, 0.22);
    background: rgba(255, 255, 255, 0.06);
    color: #ffffff;
}

.section-title {
    font-size: 13px;
    font-weight: 800;
    color: #89b4fa;
    margin-top: 8px;
    margin-bottom: 4px;
}

.window-card {
    padding: 9px;
    border-radius: 16px;
    background: rgba(255, 255, 255, 0.055);
    border: 1px solid rgba(255, 255, 255, 0.08);
}

.window-card:hover {
    background: rgba(137, 180, 250, 0.18);
    border: 1px solid rgba(137, 180, 250, 0.45);
}

.preview {
    border-radius: 12px;
    background: rgba(0, 0, 0, 0.28);
}

.window-title {
    font-weight: 800;
    color: #ffffff;
}

.window-meta {
    font-size: 11px;
    color: #a6adc8;
}

.action-button {
    padding: 10px 12px;
    border-radius: 14px;
    color: #cdd6f4;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.08);
}

.action-button:hover {
    color: #ffffff;
    background: rgba(137, 180, 250, 0.20);
    border: 1px solid rgba(137, 180, 250, 0.45);
}
"""


def run(args, *, shell=False, check=False, capture=True):
    kwargs = {
        "shell": shell,
        "check": check,
        "text": True,
    }
    if capture:
        kwargs.update({"stdout": subprocess.PIPE, "stderr": subprocess.PIPE})
    else:
        kwargs.update({"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL})
    return subprocess.run(args, **kwargs)


def hypr_json(command):
    result = run(["hyprctl", command, "-j"])
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def lua_eval(code):
    run(["hyprctl", "eval", code], capture=True)


def lua_focus_workspace(workspace):
    code = f"hl.dispatch(hl.dsp.focus({{ workspace = {json.dumps(str(workspace))} }}))"
    lua_eval(code)


def lua_focus_window(address):
    selector = f"address:{address}"
    code = f"hl.dispatch(hl.dsp.focus({{ window = {json.dumps(selector)} }}))"
    lua_eval(code)


def focus_window(address, workspace):
    lua_focus_workspace(workspace)
    time.sleep(0.06)
    lua_focus_window(address)
    run(["pkill", "-RTMIN+8", "waybar"], capture=True)


def clean_text(value, limit=80):
    value = str(value or "").replace("\n", " ").replace("\t", " ").strip()
    if not value:
        value = "untitled"
    return value[:limit] + "…" if len(value) > limit else value


def geometry_for_grim(client, monitor):
    at = client.get("at", [0, 0])
    size = client.get("size", [640, 360])
    mx = monitor.get("x", 0)
    my = monitor.get("y", 0)
    scale = float(monitor.get("scale", 1) or 1)

    x = int((at[0] - mx) * scale)
    y = int((at[1] - my) * scale)
    w = max(120, int(size[0] * scale))
    h = max(80, int(size[1] * scale))
    return f"{x},{y} {w}x{h}"


def active_workspace_name():
    ws = hypr_json("activeworkspace") or {}
    return str(ws.get("name") or ws.get("id") or "1")


def active_window_address():
    win = hypr_json("activewindow") or {}
    return win.get("address")


def monitor_for_client(client, monitors):
    mon_name = client.get("monitor")
    for mon in monitors:
        if mon.get("name") == mon_name:
            return mon
    focused = next((m for m in monitors if m.get("focused")), None)
    return focused or (monitors[0] if monitors else {"x": 0, "y": 0, "scale": 1})


def capture_previews(clients):
    if not clients or not shutil_available("grim"):
        return {}

    monitors = hypr_json("monitors") or []
    current_ws = active_workspace_name()
    current_win = active_window_address()
    previews = {}

    grouped = {}
    for client in clients:
        ws = str(client.get("workspace", {}).get("name") or client.get("workspace", {}).get("id"))
        grouped.setdefault(ws, []).append(client)

    try:
        for ws, group in grouped.items():
            lua_focus_workspace(ws)
            time.sleep(0.16)
            for client in group:
                address = client.get("address")
                if not address:
                    continue
                mon = monitor_for_client(client, monitors)
                geom = geometry_for_grim(client, mon)
                output = CACHE_DIR / f"{address.replace('0x', '')}.png"
                result = run(["grim", "-g", geom, str(output)], capture=True)
                if result.returncode == 0 and output.exists() and output.stat().st_size > 0:
                    previews[address] = output
    finally:
        if current_ws:
            lua_focus_workspace(current_ws)
            time.sleep(0.08)
        if current_win:
            lua_focus_window(current_win)

    return previews


def shutil_available(binary):
    return any((Path(p) / binary).exists() for p in os.environ.get("PATH", "").split(os.pathsep))


class WindowCard(Gtk.Button):
    def __init__(self, client, preview_path, on_activate):
        super().__init__()
        self.client = client
        self.on_activate = on_activate
        self.search_text = " ".join(
            [
                str(client.get("workspace", {}).get("name") or client.get("workspace", {}).get("id")),
                str(client.get("class") or ""),
                str(client.get("title") or ""),
            ]
        ).lower()

        self.get_style_context().add_class("window-card")
        self.set_relief(Gtk.ReliefStyle.NONE)
        self.connect("clicked", self._clicked)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.add(box)

        image_holder = Gtk.Box()
        image_holder.get_style_context().add_class("preview")
        image_holder.set_size_request(250, 140)

        if preview_path and preview_path.exists():
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(preview_path), 250, 140, True)
                image = Gtk.Image.new_from_pixbuf(pixbuf)
            except Exception:
                image = Gtk.Image.new_from_icon_name("application-x-executable", Gtk.IconSize.DIALOG)
        else:
            image = Gtk.Image.new_from_icon_name("application-x-executable", Gtk.IconSize.DIALOG)

        image_holder.pack_start(image, True, True, 0)
        box.pack_start(image_holder, False, False, 0)

        title = Gtk.Label(label=clean_text(client.get("title"), 44), xalign=0)
        title.get_style_context().add_class("window-title")
        box.pack_start(title, False, False, 0)

        ws = client.get("workspace", {}).get("name") or client.get("workspace", {}).get("id")
        meta = Gtk.Label(label=f"ws:{ws}  ·  {clean_text(client.get('class'), 28)}", xalign=0)
        meta.get_style_context().add_class("window-meta")
        box.pack_start(meta, False, False, 0)

    def _clicked(self, _button):
        ws = self.client.get("workspace", {}).get("name") or self.client.get("workspace", {}).get("id")
        self.on_activate(self.client.get("address"), str(ws))


class ActionButton(Gtk.Button):
    def __init__(self, label, command):
        super().__init__(label=label)
        self.command = command
        self.get_style_context().add_class("action-button")
        self.set_relief(Gtk.ReliefStyle.NONE)
        self.connect("clicked", self._clicked)

    def _clicked(self, _button):
        subprocess.Popen(self.command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        Gtk.main_quit()


class ControlCenter(Gtk.Window):
    def __init__(self):
        super().__init__(title="Hyprland Control Center")
        self.set_decorated(False)
        self.set_default_size(1120, 760)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self._key_press)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        root.get_style_context().add_class("root")
        self.add(root)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        root.pack_start(header, False, False, 0)

        titles = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        header.pack_start(titles, True, True, 0)

        title = Gtk.Label(label="󰍹  Window Overview", xalign=0)
        title.get_style_context().add_class("header-title")
        titles.pack_start(title, False, False, 0)

        subtitle = Gtk.Label(label="Click a preview to jump to its workspace and focus the window", xalign=0)
        subtitle.get_style_context().add_class("header-subtitle")
        titles.pack_start(subtitle, False, False, 0)

        self.search = Gtk.SearchEntry()
        self.search.get_style_context().add_class("search")
        self.search.set_placeholder_text("Search windows…")
        self.search.connect("search-changed", self._filter_cards)
        header.pack_start(self.search, False, False, 0)

        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        root.pack_start(body, True, True, 0)

        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        body.pack_start(left, True, True, 0)

        windows_label = Gtk.Label(label="Open windows", xalign=0)
        windows_label.get_style_context().add_class("section-title")
        left.pack_start(windows_label, False, False, 0)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        left.pack_start(scroll, True, True, 0)

        self.flow = Gtk.FlowBox()
        self.flow.set_valign(Gtk.Align.START)
        self.flow.set_max_children_per_line(3)
        self.flow.set_selection_mode(Gtk.SelectionMode.NONE)
        self.flow.set_row_spacing(10)
        self.flow.set_column_spacing(10)
        scroll.add(self.flow)

        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=9)
        right.set_size_request(250, -1)
        body.pack_start(right, False, False, 0)

        actions_label = Gtk.Label(label="Quick actions", xalign=0)
        actions_label.get_style_context().add_class("section-title")
        right.pack_start(actions_label, False, False, 0)

        actions = [
            ("  Kitty", "kitty"),
            ("󰉋  Nautilus", "nautilus"),
            ("  ~/.config", f"nautilus {shlex.quote(str(HOME / '.config'))}"),
            ("󰋊  Screenshots", f"nautilus {shlex.quote(str(HOME / 'Pictures/Screenshots'))}"),
            ("  btop", "kitty --class btop-g -e btop"),
            ("  Clipboard", "cliphist list | rofi -dmenu -p Clipboard | cliphist decode | wl-copy"),
            ("󰄀  Show desktop", shlex.quote(str(HYPR_DIR / "show-desktop.sh"))),
            ("󰹑  Screenshot area", shlex.quote(str(HYPR_DIR / "scripts/screenshot-area.sh"))),
            ("󰑓  Reload UI", "hyprctl reload; pkill waybar; setsid waybar >/dev/null 2>&1 &"),
            ("  Lock", "hyprlock"),
            ("  Power menu", shlex.quote(str(HYPR_DIR / "scripts/powermenu.sh"))),
        ]
        for label, cmd in actions:
            right.pack_start(ActionButton(label, cmd), False, False, 0)

        self.cards = []
        self._load_windows()
        GLib.idle_add(self.search.grab_focus)

    def _load_windows(self):
        clients = hypr_json("clients") or []
        clients = [c for c in clients if c.get("mapped", True)]
        clients.sort(key=lambda c: (c.get("workspace", {}).get("id", 999), c.get("class") or "", c.get("title") or ""))
        previews = capture_previews(clients)

        for client in clients:
            card = WindowCard(client, previews.get(client.get("address")), self._activate_window)
            self.cards.append(card)
            self.flow.add(card)

        self.show_all()

    def _activate_window(self, address, workspace):
        if address:
            focus_window(address, workspace)
        Gtk.main_quit()

    def _filter_cards(self, entry):
        query = entry.get_text().strip().lower()
        for card in self.cards:
            card.set_visible(not query or query in card.search_text)

    def _key_press(self, _widget, event):
        key = Gdk.keyval_name(event.keyval)
        if key == "Escape":
            Gtk.main_quit()
            return True
        return False


if __name__ == "__main__":
    try:
        ControlCenter().show_all()
        Gtk.main()
    except Exception as exc:
        print(f"control-center.py: {exc}", file=sys.stderr)
        fallback = SCRIPT_DIR / "control-center-rofi.sh"
        os.execv(str(fallback), [str(fallback)])
