#!/usr/bin/env python3
import calendar
import datetime as dt
import json
import os
import re
import shutil
import socket
import subprocess
import threading
import time
import urllib.request
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk

try:
    gi.require_version("GtkLayerShell", "0.1")
    from gi.repository import GtkLayerShell
    HAS_LAYER_SHELL = True
except Exception:
    GtkLayerShell = None
    HAS_LAYER_SHELL = False

HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "hypr-dashboard"
CACHE.mkdir(parents=True, exist_ok=True)
AVATAR = HOME / ".face"
WEATHER_CACHE = CACHE / "weather-kyiv-7d.json"
TOP_MARGIN = 34
PANEL_WIDTH = 1080
PANEL_HEIGHT = 660

CSS = b"""
* {
    all: unset;
    font-family: "JetBrainsMono Nerd Font", "Noto Color Emoji", sans-serif;
    color: #cdd6f4;
}

window {
    background: transparent;
}

.panel {
    background: linear-gradient(135deg, rgba(12, 14, 20, 0.94), rgba(20, 22, 32, 0.92));
    border: 1px solid rgba(137, 180, 250, 0.28);
    border-radius: 26px;
    padding: 18px;
    box-shadow: 0 24px 70px rgba(0, 0, 0, 0.42);
}

.header-title {
    font-size: 23px;
    font-weight: 900;
    color: #ffffff;
}

.header-subtitle {
    font-size: 12px;
    color: #8f9bb3;
}

.pill {
    padding: 8px 13px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.055);
    border: 1px solid rgba(255, 255, 255, 0.08);
    color: #a6adc8;
}

.pill-active {
    padding: 8px 13px;
    border-radius: 999px;
    background: rgba(137, 180, 250, 0.25);
    border: 1px solid rgba(137, 180, 250, 0.52);
    color: #ffffff;
}

.card {
    background: rgba(255, 255, 255, 0.055);
    border: 1px solid rgba(255, 255, 255, 0.085);
    border-radius: 20px;
    padding: 14px;
}

.card-accent {
    background: linear-gradient(135deg, rgba(137, 180, 250, 0.20), rgba(203, 166, 247, 0.12));
    border: 1px solid rgba(137, 180, 250, 0.42);
    border-radius: 20px;
    padding: 14px;
}

.card-today {
    background: linear-gradient(135deg, rgba(137, 180, 250, 0.28), rgba(203, 166, 247, 0.18));
    border: 2px solid rgba(137, 180, 250, 0.82);
    border-radius: 20px;
    padding: 14px;
}

.section-title {
    color: #89b4fa;
    font-size: 13px;
    font-weight: 900;
}

.muted {
    color: #a6adc8;
    font-size: 12px;
}

.big-time {
    font-size: 46px;
    font-weight: 900;
    color: #ffffff;
}

.big-temp {
    font-size: 40px;
    font-weight: 900;
    color: #ffffff;
}

.track-title {
    font-size: 18px;
    font-weight: 900;
    color: #ffffff;
}

.track-title-big {
    font-size: 25px;
    font-weight: 900;
    color: #ffffff;
}

.media-button {
    min-width: 38px;
    min-height: 34px;
    padding: 7px 11px;
    border-radius: 13px;
    background: rgba(137, 180, 250, 0.16);
    border: 1px solid rgba(137, 180, 250, 0.30);
    color: #ffffff;
}

.media-button:hover {
    background: rgba(137, 180, 250, 0.30);
    border-color: rgba(137, 180, 250, 0.70);
}

.close-button {
    min-width: 34px;
    min-height: 34px;
    border-radius: 999px;
    background: rgba(243, 139, 168, 0.15);
    border: 1px solid rgba(243, 139, 168, 0.35);
    color: #f38ba8;
}

.close-button:hover {
    background: rgba(243, 139, 168, 0.28);
    color: #ffffff;
}

scale trough {
    min-height: 9px;
    border-radius: 99px;
    background: rgba(255, 255, 255, 0.13);
}

scale highlight {
    border-radius: 99px;
    background: linear-gradient(90deg, #89b4fa, #cba6f7);
}

scale slider {
    min-width: 17px;
    min-height: 17px;
    border-radius: 99px;
    background: #ffffff;
    border: 2px solid rgba(137, 180, 250, 0.72);
}

.calendar {
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 13px;
    color: #cdd6f4;
}

.cat {
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 22px;
    font-weight: 800;
    color: #ffffff;
}

.metric-value {
    font-size: 17px;
    font-weight: 900;
    color: #ffffff;
}

.weather-day {
    font-size: 12px;
    font-weight: 800;
}
"""

CAT_FRAMES = [
    " /\\_/\\\\\n( o.o )\n > ^ <",
    " /\\_/\\\\\n( -.- )\n > ^ <",
    " /\\_/\\\\\n( o.o )っ\n > ^ <",
    " /\\_/\\\\\n( =^.^= )\n  /   \\",
]


def run(cmd, shell=False, timeout=2):
    try:
        return subprocess.run(cmd, shell=shell, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout).stdout.strip()
    except Exception:
        return ""


def has(cmd):
    return shutil.which(cmd) is not None


def clamp(v, lo=0, hi=100):
    return max(lo, min(hi, v))


class Graph(Gtk.DrawingArea):
    def __init__(self, height=92):
        super().__init__()
        self.values = []
        self.set_size_request(292, height)
        self.connect("draw", self.on_draw)

    def push(self, value):
        self.values = (self.values + [float(clamp(value))])[-70:]
        self.queue_draw()

    def on_draw(self, _widget, cr):
        w = self.get_allocated_width()
        h = self.get_allocated_height()

        cr.set_source_rgba(1, 1, 1, 0.045)
        cr.rectangle(0, 0, w, h)
        cr.fill()

        cr.set_source_rgba(1, 1, 1, 0.07)
        cr.set_line_width(1)
        for i in range(1, 4):
            y = h * i / 4
            cr.move_to(0, y)
            cr.line_to(w, y)
        cr.stroke()

        if len(self.values) < 2:
            return False

        step = w / 69
        start = 70 - len(self.values)

        cr.set_source_rgba(0.54, 0.71, 0.98, 0.16)
        cr.move_to(start * step, h)
        for i, val in enumerate(self.values):
            x = (start + i) * step
            y = h - (val / 100) * h
            cr.line_to(x, y)
        cr.line_to(w, h)
        cr.close_path()
        cr.fill()

        cr.set_source_rgba(0.54, 0.71, 0.98, 0.98)
        cr.set_line_width(2.2)
        for i, val in enumerate(self.values):
            x = (start + i) * step
            y = h - (val / 100) * h
            if i == 0:
                cr.move_to(x, y)
            else:
                cr.line_to(x, y)
        cr.stroke()
        return False


class Dashboard(Gtk.Window):
    def __init__(self):
        super().__init__(title="Hypr Dashboard")
        self.set_decorated(False)
        self.set_default_size(PANEL_WIDTH, PANEL_HEIGHT)
        self.set_resizable(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key)

        if HAS_LAYER_SHELL:
            GtkLayerShell.init_for_window(self)
            GtkLayerShell.set_namespace(self, "hypr-dashboard")
            GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
            GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
            GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, False)
            GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, False)
            GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, False)
            GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, -PANEL_HEIGHT)
            GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.active_tab = 0
        self.tabs = []
        self.pages = []
        self.media_sink = None
        self.vol_guard = False
        self.last_cpu = None
        self.last_net = None
        self.cat_i = 0

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        outer.set_size_request(PANEL_WIDTH, PANEL_HEIGHT)
        outer.get_style_context().add_class("panel")
        self.add(outer)

        self.build_header(outer)
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(220)
        outer.pack_start(self.stack, True, True, 0)

        self.build_main_page()
        self.build_media_page()
        self.build_stats_page()
        self.build_weather_page()
        self.set_tab(0)

        GLib.timeout_add_seconds(1, self.tick_clock)
        GLib.timeout_add_seconds(2, self.tick_media)
        GLib.timeout_add_seconds(2, self.tick_stats)
        GLib.timeout_add_seconds(900, self.tick_weather)
        GLib.timeout_add(430, self.tick_cat)

        self.tick_clock()
        self.tick_media()
        self.tick_stats()
        self.tick_weather()

    def build_header(self, outer):
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        header.set_margin_bottom(12)
        outer.pack_start(header, False, False, 0)

        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        header.pack_start(title_box, True, True, 0)
        title = Gtk.Label(label="󰕮  Dashboard", xalign=0)
        title.get_style_context().add_class("header-title")
        subtitle = Gtk.Label(label="fixed layer-shell overlay · media · weather · system", xalign=0)
        subtitle.get_style_context().add_class("header-subtitle")
        title_box.pack_start(title, False, False, 0)
        title_box.pack_start(subtitle, False, False, 0)

        tab_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        header.pack_start(tab_box, False, False, 0)
        for i, label in enumerate(["󰃭 Main", " Media", "󰍛 Stats", "󰖕 Weather"]):
            btn = Gtk.Button(label=label)
            btn.connect("clicked", lambda _b, idx=i: self.set_tab(idx))
            self.tabs.append(btn)
            tab_box.pack_start(btn, False, False, 0)

        close = Gtk.Button(label="✕")
        close.get_style_context().add_class("close-button")
        close.connect("clicked", lambda *_: Gtk.main_quit())
        header.pack_end(close, False, False, 0)

    def set_tab(self, idx):
        self.active_tab = idx
        self.stack.set_visible_child_name(str(idx))
        for i, btn in enumerate(self.tabs):
            ctx = btn.get_style_context()
            ctx.remove_class("pill")
            ctx.remove_class("pill-active")
            ctx.add_class("pill-active" if i == idx else "pill")

    def card(self, accent=False, today=False):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.get_style_context().add_class("card-today" if today else "card-accent" if accent else "card")
        return box

    def add_page(self, idx):
        page = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.stack.add_named(page, str(idx))
        return page

    def label(self, text, cls=None, xalign=0):
        l = Gtk.Label(label=text, xalign=xalign)
        if cls:
            l.get_style_context().add_class(cls)
        return l

    def avatar(self, size):
        img = Gtk.Image()
        if AVATAR.exists():
            try:
                img.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(str(AVATAR), size, size, True))
                return img
            except Exception:
                pass
        img.set_from_icon_name("avatar-default", Gtk.IconSize.DIALOG)
        return img

    def build_main_page(self):
        page = self.add_page(0)
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        mid = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        page.pack_start(left, True, True, 0)
        page.pack_start(mid, True, True, 0)
        page.pack_start(right, False, False, 0)

        w = self.card(accent=True)
        w.pack_start(self.label("󰖕 Kyiv weather", "section-title"), False, False, 0)
        self.home_weather = self.label("--°C", "big-temp")
        self.home_weather_sub = self.label("loading…", "muted")
        w.pack_start(self.home_weather, False, False, 0)
        w.pack_start(self.home_weather_sub, False, False, 0)
        left.pack_start(w, False, False, 0)

        self.build_media_card(left, small=True)

        clock = self.card(accent=True)
        self.time_label = self.label("--:--", "big-time", 0.5)
        self.date_label = self.label("", "muted", 0.5)
        self.calendar_label = self.label("", "calendar", 0)
        clock.pack_start(self.time_label, False, False, 0)
        clock.pack_start(self.date_label, False, False, 0)
        clock.pack_start(self.calendar_label, False, False, 0)
        mid.pack_start(clock, True, True, 0)

        profile = self.card()
        profile.pack_start(self.avatar(122), False, False, 0)
        profile.pack_start(self.label(os.environ.get("USER", "user"), "track-title", 0.5), False, False, 0)
        profile.pack_start(self.label("Arch · Hyprland", "muted", 0.5), False, False, 0)
        right.pack_start(profile, False, False, 0)

    def build_media_card(self, parent, small):
        card = self.card()
        parent.pack_start(card, True, True, 0)
        card.pack_start(self.label(" Active track", "section-title"), False, False, 0)
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        card.pack_start(row, False, False, 0)
        img = Gtk.Image()
        img.set_pixel_size(92 if small else 250)
        row.pack_start(img, False, False, 0)
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        row.pack_start(info, True, True, 0)
        title = self.label("No active track", "track-title" if small else "track-title-big")
        artist = self.label("", "muted")
        info.pack_start(title, False, False, 0)
        info.pack_start(artist, False, False, 0)
        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        info.pack_start(controls, False, False, 0)
        for label, cmd in [("󰒮", "playerctl previous"), ("⏯", "playerctl play-pause"), ("󰒭", "playerctl next")]:
            b = Gtk.Button(label=label)
            b.get_style_context().add_class("media-button")
            b.connect("clicked", lambda _b, c=cmd: subprocess.Popen(c, shell=True))
            controls.pack_start(b, False, False, 0)
        if small:
            self.album = img
            self.track_title = title
            self.track_artist = artist
            self.volume_label = self.label("App volume", "muted")
            info.pack_start(self.volume_label, False, False, 0)
            self.volume = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 150, 1)
            self.volume.connect("value-changed", self.on_volume_changed)
            info.pack_start(self.volume, False, False, 0)
        else:
            self.big_album = img
            self.big_track_title = title
            self.big_track_artist = artist

    def build_media_page(self):
        page = self.add_page(1)
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        page.pack_start(left, True, True, 0)
        page.pack_start(right, False, False, 0)
        self.build_media_card(left, small=False)
        side = self.card(accent=True)
        side.pack_start(self.avatar(128), False, False, 0)
        self.cat = self.label(CAT_FRAMES[0], "cat", 0.5)
        side.pack_start(self.cat, True, True, 0)
        right.pack_start(side, True, True, 0)

    def build_stats_page(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.stack.add_named(page, "2")
        grid = Gtk.Grid(column_spacing=12, row_spacing=12)
        page.pack_start(grid, False, False, 0)
        self.cpu_label = self.metric(grid, 0, 0, "CPU")
        self.gpu_label = self.metric(grid, 1, 0, "GPU")
        self.ram_label = self.metric(grid, 2, 0, "RAM")
        self.disk_label = self.metric(grid, 0, 1, "Disk")
        self.net_label = self.metric(grid, 1, 1, "Network")
        self.ip_label = self.metric(grid, 2, 1, "IP")
        graphs = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        page.pack_start(graphs, True, True, 0)
        self.cpu_graph = Graph()
        self.gpu_graph = Graph()
        self.net_graph = Graph()
        for title, graph in [("CPU load", self.cpu_graph), ("GPU load", self.gpu_graph), ("Internet load", self.net_graph)]:
            c = self.card()
            c.pack_start(self.label(title, "section-title"), False, False, 0)
            c.pack_start(graph, True, True, 0)
            graphs.pack_start(c, True, True, 0)

    def metric(self, grid, x, y, name):
        c = self.card()
        c.set_size_request(330, 78)
        c.pack_start(self.label(name, "section-title"), False, False, 0)
        v = self.label("--", "metric-value")
        c.pack_start(v, False, False, 0)
        grid.attach(c, x, y, 1, 1)
        return v

    def build_weather_page(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.stack.add_named(page, "3")
        head = self.card(accent=True)
        self.weather_header = self.label("Kyiv weather", "big-temp")
        self.sun_label = self.label("loading…", "muted")
        head.pack_start(self.weather_header, False, False, 0)
        head.pack_start(self.sun_label, False, False, 0)
        page.pack_start(head, False, False, 0)
        self.days_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        page.pack_start(self.days_box, True, True, 0)

    def show_overlay(self):
        self.show_all()
        if HAS_LAYER_SHELL:
            self.anim_margin = -PANEL_HEIGHT
            GLib.timeout_add(12, self.animate_layer)
        else:
            screen = Gdk.Screen.get_default()
            geom = screen.get_monitor_geometry(screen.get_primary_monitor())
            self.x = geom.x + (geom.width - PANEL_WIDTH) // 2
            self.y = geom.y - PANEL_HEIGHT
            self.target_y = geom.y + TOP_MARGIN
            self.move(self.x, self.y)
            GLib.timeout_add(12, self.animate_window)

    def animate_layer(self):
        self.anim_margin += max(9, int((TOP_MARGIN - self.anim_margin) * 0.22))
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, self.anim_margin)
        if self.anim_margin >= TOP_MARGIN:
            GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, TOP_MARGIN)
            return False
        return True

    def animate_window(self):
        self.y += max(9, int((self.target_y - self.y) * 0.22))
        self.move(self.x, self.y)
        return self.y < self.target_y

    def on_key(self, _w, event):
        key = Gdk.keyval_name(event.keyval)
        if key == "Escape":
            Gtk.main_quit()
            return True
        if key in ["1", "2", "3", "4"]:
            self.set_tab(int(key) - 1)
            return True
        return False

    def tick_clock(self):
        now = dt.datetime.now()
        self.time_label.set_text(now.strftime("%H:%M"))
        self.date_label.set_text(now.strftime("%A, %d.%m.%Y"))
        self.calendar_label.set_text(calendar.month(now.year, now.month))
        return True

    def set_album_art(self, url, img, size):
        if not url:
            img.set_from_icon_name("audio-x-generic", Gtk.IconSize.DIALOG)
            return
        path = None
        if url.startswith("file://"):
            path = Path(urllib.request.url2pathname(url[7:]))
        elif url.startswith("http"):
            safe = re.sub(r"[^a-zA-Z0-9]", "_", url)[-100:]
            path = CACHE / f"art_{safe}.jpg"
            if not path.exists():
                def dl():
                    try:
                        urllib.request.urlretrieve(url, path)
                        GLib.idle_add(lambda: self.set_album_art(url, img, size))
                    except Exception:
                        pass
                threading.Thread(target=dl, daemon=True).start()
                img.set_from_icon_name("audio-x-generic", Gtk.IconSize.DIALOG)
                return
        if path and path.exists():
            try:
                img.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(str(path), size, size, True))
                return
            except Exception:
                pass
        img.set_from_icon_name("audio-x-generic", Gtk.IconSize.DIALOG)

    def tick_media(self):
        if not has("playerctl"):
            return True
        title = run(["playerctl", "metadata", "title"])
        artist = run(["playerctl", "metadata", "artist"])
        art = run(["playerctl", "metadata", "mpris:artUrl"])
        player = run(["playerctl", "metadata", "--format", "{{playerName}}"])
        status = run(["playerctl", "status"])
        if not title:
            title = "No active track"
            artist = ""
        for label in [self.track_title, self.big_track_title]:
            label.set_text(title)
        for label in [self.track_artist, self.big_track_artist]:
            label.set_text(f"{artist} · {status}" if artist else status)
        self.set_album_art(art, self.album, 92)
        self.set_album_art(art, self.big_album, 250)
        self.update_media_sink(player)
        return True

    def update_media_sink(self, player):
        if not has("pactl"):
            return
        data = run(["pactl", "list", "sink-inputs"])
        blocks = re.split(r"Sink Input #", data)[1:]
        best = None
        for block in blocks:
            sid = block.splitlines()[0].strip()
            vol = re.search(r"Volume:.*?(\d+)%", block)
            text = block.lower()
            if player and player.lower() in text:
                best = (sid, int(vol.group(1)) if vol else 100)
                break
            if best is None and vol:
                best = (sid, int(vol.group(1)))
        if best:
            self.media_sink, volume = best
            self.vol_guard = True
            self.volume.set_value(volume)
            self.vol_guard = False
            self.volume_label.set_text(f"App volume · {volume}%")

    def on_volume_changed(self, scale):
        if self.vol_guard or not self.media_sink:
            return
        value = int(scale.get_value())
        subprocess.Popen(["pactl", "set-sink-input-volume", self.media_sink, f"{value}%"])
        self.volume_label.set_text(f"App volume · {value}%")

    def cpu_usage(self):
        try:
            vals = [int(x) for x in Path("/proc/stat").read_text().splitlines()[0].split()[1:]]
            idle = vals[3] + vals[4]
            total = sum(vals)
            if self.last_cpu is None:
                self.last_cpu = (total, idle)
                return 0
            pt, pi = self.last_cpu
            self.last_cpu = (total, idle)
            return 100 * (1 - (idle - pi) / max(1, total - pt))
        except Exception:
            return 0

    def cpu_temp(self):
        vals = []
        for p in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
            try:
                v = int(p.read_text().strip()) / 1000
                if 20 <= v <= 120:
                    vals.append(v)
            except Exception:
                pass
        return max(vals) if vals else None

    def gpu_stats(self):
        if has("nvidia-smi"):
            out = run(["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"])
            try:
                u, t = [float(x.strip()) for x in out.splitlines()[0].split(",")[:2]]
                return u, t
            except Exception:
                pass
        return 0, None

    def net_usage(self):
        rx = tx = 0
        try:
            for line in Path("/proc/net/dev").read_text().splitlines()[2:]:
                iface, rest = line.split(":", 1)
                if iface.strip() == "lo":
                    continue
                nums = rest.split()
                rx += int(nums[0])
                tx += int(nums[8])
        except Exception:
            return 0, 0, 0
        now = time.time()
        if self.last_net is None:
            self.last_net = (rx, tx, now)
            return 0, 0, 0
        prx, ptx, pt = self.last_net
        self.last_net = (rx, tx, now)
        d = max(0.1, now - pt)
        down = (rx - prx) / d
        up = (tx - ptx) / d
        graph = min(100, (down + up) / 1024 / 1024 * 10)
        return down, up, graph

    def tick_stats(self):
        cpu = self.cpu_usage()
        ctemp = self.cpu_temp()
        gpu, gtemp = self.gpu_stats()
        mem = {}
        try:
            for line in Path("/proc/meminfo").read_text().splitlines():
                k, v = line.split(":", 1)
                mem[k] = int(v.strip().split()[0])
            ram = 100 * (1 - mem.get("MemAvailable", 0) / mem.get("MemTotal", 1))
        except Exception:
            ram = 0
        disk_u = shutil.disk_usage("/")
        disk = disk_u.used / disk_u.total * 100
        down, up, net_graph = self.net_usage()
        ip = run("ip -4 addr show scope global | awk '/inet / {print $2, $NF; exit}'", shell=True) or socket.gethostbyname(socket.gethostname())

        self.cpu_label.set_text(f"{cpu:.0f}%" + (f" · {ctemp:.0f}°C" if ctemp else ""))
        self.gpu_label.set_text(f"{gpu:.0f}%" + (f" · {gtemp:.0f}°C" if gtemp else ""))
        self.ram_label.set_text(f"{ram:.0f}%")
        self.disk_label.set_text(f"{disk:.0f}%")
        self.net_label.set_text(f"↓ {down/1024:.0f} KiB/s · ↑ {up/1024:.0f} KiB/s")
        self.ip_label.set_text(ip)
        self.cpu_graph.push(cpu)
        self.gpu_graph.push(gpu)
        self.net_graph.push(net_graph)
        return True

    def tick_weather(self):
        def worker():
            url = "https://api.open-meteo.com/v1/forecast?latitude=50.4501&longitude=30.5234&current=temperature_2m,relative_humidity_2m,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,relative_humidity_2m_mean,wind_speed_10m_max,sunrise,sunset&timezone=Europe%2FKyiv&forecast_days=7"
            data = None
            try:
                data = json.loads(urllib.request.urlopen(url, timeout=5).read().decode())
                WEATHER_CACHE.write_text(json.dumps(data))
            except Exception:
                if WEATHER_CACHE.exists():
                    try:
                        data = json.loads(WEATHER_CACHE.read_text())
                    except Exception:
                        data = None
            GLib.idle_add(lambda: self.apply_weather(data))
        threading.Thread(target=worker, daemon=True).start()
        return True

    def apply_weather(self, data):
        if not data:
            self.home_weather.set_text("--°C")
            self.home_weather_sub.set_text("Weather unavailable")
            return False
        cur = data.get("current", {})
        daily = data.get("daily", {})
        temp = cur.get("temperature_2m", 0)
        hum = cur.get("relative_humidity_2m", 0)
        wind = cur.get("wind_speed_10m", 0)
        self.home_weather.set_text(f"{temp:.0f}°C")
        self.home_weather_sub.set_text(f"Kyiv · humidity {hum}% · wind {wind} km/h")
        self.weather_header.set_text(f"Kyiv · {temp:.0f}°C")
        sr0 = daily.get("sunrise", [""])[0][-5:]
        ss0 = daily.get("sunset", [""])[0][-5:]
        self.sun_label.set_text(f"Today · sunrise {sr0} · sunset {ss0} · humidity {hum}% · wind {wind} km/h")
        for child in self.days_box.get_children():
            self.days_box.remove(child)
        today = dt.date.today().isoformat()
        for i, day in enumerate(daily.get("time", [])[:7]):
            is_today = day == today
            card = self.card(today=is_today)
            date = dt.datetime.strptime(day, "%Y-%m-%d")
            name = ("Today" if is_today else date.strftime("%a")) + date.strftime(" %d.%m")
            tmax = daily["temperature_2m_max"][i]
            tmin = daily["temperature_2m_min"][i]
            h = daily["relative_humidity_2m_mean"][i]
            w = daily["wind_speed_10m_max"][i]
            sr = daily["sunrise"][i][-5:]
            ss = daily["sunset"][i][-5:]
            label = self.label(f"{name}\n\n{tmin:.0f}° / {tmax:.0f}°\n󰖎 {h:.0f}%\n󰖝 {w:.0f} km/h\n󰖜 {sr}\n󰖛 {ss}", "weather-day")
            card.pack_start(label, True, True, 0)
            self.days_box.pack_start(card, True, True, 0)
        self.days_box.show_all()
        return False

    def tick_cat(self):
        self.cat_i = (self.cat_i + 1) % len(CAT_FRAMES)
        self.cat.set_text(CAT_FRAMES[self.cat_i])
        return True


if __name__ == "__main__":
    Dashboard().show_overlay()
    Gtk.main()
