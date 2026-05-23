#!/usr/bin/env python3
import calendar
import datetime as dt
import json
import math
import os
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk

HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "hypr-dashboard"
CACHE.mkdir(parents=True, exist_ok=True)
AVATAR = HOME / ".face"
WEATHER_CACHE = CACHE / "weather-kyiv.json"

CSS = b"""
* {
    font-family: "JetBrainsMono Nerd Font", "Noto Color Emoji", sans-serif;
    color: #cdd6f4;
}

window {
    background: transparent;
}

.root {
    background: rgba(12, 14, 20, 0.90);
    border: 1px solid rgba(137, 180, 250, 0.28);
    border-radius: 24px;
    padding: 16px;
}

.title {
    font-size: 22px;
    font-weight: 900;
    color: #ffffff;
}

.subtitle {
    color: #8f9bb3;
    font-size: 12px;
}

.card {
    background: rgba(255, 255, 255, 0.055);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 18px;
    padding: 14px;
}

.card:hover {
    border-color: rgba(137, 180, 250, 0.35);
}

.tab-header button {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 14px;
    padding: 8px 14px;
    margin-right: 8px;
    color: #a6adc8;
}

.tab-header button:checked {
    background: rgba(137, 180, 250, 0.28);
    border-color: rgba(137, 180, 250, 0.55);
    color: #ffffff;
}

.metric-title {
    color: #89b4fa;
    font-weight: 800;
    font-size: 13px;
}

.big-time {
    font-size: 44px;
    font-weight: 900;
    color: #ffffff;
}

.big-date {
    color: #f9e2af;
    font-weight: 700;
}

.track-title {
    font-size: 18px;
    font-weight: 900;
    color: #ffffff;
}

.track-artist {
    color: #a6adc8;
}

.media-button {
    background: rgba(137, 180, 250, 0.16);
    border: 1px solid rgba(137, 180, 250, 0.30);
    border-radius: 14px;
    padding: 8px 12px;
    color: #ffffff;
}

.media-button:hover {
    background: rgba(137, 180, 250, 0.28);
}

scale trough {
    min-height: 8px;
    border-radius: 8px;
    background: rgba(255, 255, 255, 0.12);
}

scale highlight {
    border-radius: 8px;
    background: #89b4fa;
}

scale slider {
    min-width: 16px;
    min-height: 16px;
    border-radius: 99px;
    background: #ffffff;
}

.calendar {
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 13px;
    color: #cdd6f4;
}

.cat {
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 18px;
    color: #ffffff;
}

.weather-temp {
    font-size: 36px;
    font-weight: 900;
    color: #ffffff;
}

.weather-day {
    font-weight: 800;
    color: #89b4fa;
}
"""

CAT_FRAMES = [
    r"""
 /\_/\\
( o.o )
 > ^ <
""",
    r"""
 /\_/\\
( -.- )
 > ^ <
""",
    r"""
 /\_/\\
( o.o )っ
 > ^ <
""",
    r"""
 /\_/\\
( =^.^= )
  /   \\
""",
]


def run(cmd, shell=False):
    try:
        return subprocess.run(cmd, shell=shell, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=2).stdout.strip()
    except Exception:
        return ""


def command_exists(name):
    return shutil.which(name) is not None


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def read_json_url(url, timeout=5):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception:
        return None


class Graph(Gtk.DrawingArea):
    def __init__(self, max_points=60, height=80):
        super().__init__()
        self.values = []
        self.max_points = max_points
        self.set_size_request(260, height)
        self.connect("draw", self.on_draw)

    def push(self, value):
        self.values.append(float(clamp(value, 0, 100)))
        self.values = self.values[-self.max_points:]
        self.queue_draw()

    def on_draw(self, widget, cr):
        w = self.get_allocated_width()
        h = self.get_allocated_height()
        cr.set_source_rgba(1, 1, 1, 0.06)
        cr.rectangle(0, 0, w, h)
        cr.fill()
        cr.set_line_width(2)
        cr.set_source_rgba(0.54, 0.71, 0.98, 0.95)
        if len(self.values) < 2:
            return False
        step = w / max(1, self.max_points - 1)
        start = self.max_points - len(self.values)
        for i, val in enumerate(self.values):
            x = (start + i) * step
            y = h - (val / 100.0) * h
            if i == 0:
                cr.move_to(x, y)
            else:
                cr.line_to(x, y)
        cr.stroke()
        return False


class Dashboard(Gtk.Window):
    def __init__(self):
        super().__init__(title="Dashboard")
        self.set_decorated(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_default_size(920, 620)
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.media_volume_id = None
        self.volume_guard = False
        self.last_cpu_total = None
        self.last_cpu_idle = None
        self.last_net_rx = None
        self.last_net_tx = None
        self.last_net_time = time.time()
        self.cat_index = 0

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        root.get_style_context().add_class("root")
        self.add(root)

        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        root.pack_start(top, False, False, 0)
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        top.pack_start(title_box, True, True, 0)
        title = Gtk.Label(label="󰕮  Personal Dashboard", xalign=0)
        title.get_style_context().add_class("title")
        title_box.pack_start(title, False, False, 0)
        subtitle = Gtk.Label(label="weather · media · calendar · system monitor", xalign=0)
        subtitle.get_style_context().add_class("subtitle")
        title_box.pack_start(subtitle, False, False, 0)

        close = Gtk.Button(label="✕")
        close.get_style_context().add_class("media-button")
        close.connect("clicked", lambda *_: Gtk.main_quit())
        top.pack_end(close, False, False, 0)

        self.tabs = Gtk.Notebook()
        self.tabs.set_tab_pos(Gtk.PositionType.TOP)
        root.pack_start(self.tabs, True, True, 0)

        self.build_home_tab()
        self.build_media_tab()
        self.build_stats_tab()
        self.build_weather_tab()

        GLib.timeout_add_seconds(1, self.tick_fast)
        GLib.timeout_add_seconds(3, self.tick_media)
        GLib.timeout_add_seconds(3, self.tick_stats)
        GLib.timeout_add_seconds(900, self.tick_weather)
        GLib.timeout_add(420, self.tick_cat)

        self.tick_fast()
        self.tick_media()
        self.tick_stats()
        self.tick_weather()

    def show_center_top(self):
        self.show_all()
        screen = Gdk.Screen.get_default()
        monitor = screen.get_primary_monitor()
        geom = screen.get_monitor_geometry(monitor)
        w, h = self.get_size()
        x = geom.x + (geom.width - w) // 2
        target_y = geom.y + 38
        self.move(x, geom.y - h)
        self._anim_y = geom.y - h
        self._target_y = target_y
        GLib.timeout_add(12, self.animate_down)

    def animate_down(self):
        self._anim_y += max(8, int((self._target_y - self._anim_y) * 0.22))
        if self._anim_y >= self._target_y:
            self.move(self.get_position()[0], self._target_y)
            return False
        self.move(self.get_position()[0], self._anim_y)
        return True

    def tab_label(self, text):
        label = Gtk.Label(label=text)
        label.set_margin_start(8)
        label.set_margin_end(8)
        return label

    def card(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.get_style_context().add_class("card")
        return box

    def build_home_tab(self):
        page = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        page.set_border_width(4)
        self.tabs.append_page(page, self.tab_label("󰃭 Main"))

        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        page.pack_start(left, True, True, 0)
        page.pack_start(right, False, False, 0)

        weather = self.card()
        self.home_weather = Gtk.Label(label="Loading Kyiv weather…", xalign=0)
        self.home_weather.get_style_context().add_class("weather-temp")
        self.home_weather_sub = Gtk.Label(label="", xalign=0)
        weather.pack_start(Gtk.Label(label="󰖕 Weather", xalign=0), False, False, 0)
        weather.pack_start(self.home_weather, False, False, 0)
        weather.pack_start(self.home_weather_sub, False, False, 0)
        left.pack_start(weather, False, False, 0)

        media = self.card()
        media.pack_start(Gtk.Label(label=" Active track", xalign=0), False, False, 0)
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        media.pack_start(row, False, False, 0)
        self.album_image = Gtk.Image()
        self.album_image.set_pixel_size(82)
        row.pack_start(self.album_image, False, False, 0)
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        row.pack_start(info, True, True, 0)
        self.track_title = Gtk.Label(label="No media", xalign=0)
        self.track_title.get_style_context().add_class("track-title")
        self.track_artist = Gtk.Label(label="", xalign=0)
        self.track_artist.get_style_context().add_class("track-artist")
        info.pack_start(self.track_title, False, False, 0)
        info.pack_start(self.track_artist, False, False, 0)
        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        info.pack_start(controls, False, False, 0)
        for label, cmd in [("󰒮", "playerctl previous"), ("⏯", "playerctl play-pause"), ("󰒭", "playerctl next")]:
            b = Gtk.Button(label=label)
            b.get_style_context().add_class("media-button")
            b.connect("clicked", lambda _b, c=cmd: subprocess.Popen(c, shell=True))
            controls.pack_start(b, False, False, 0)
        self.volume_label = Gtk.Label(label="App volume", xalign=0)
        media.pack_start(self.volume_label, False, False, 0)
        self.volume = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 150, 1)
        self.volume.set_value(100)
        self.volume.connect("value-changed", self.on_volume_changed)
        media.pack_start(self.volume, False, False, 0)
        left.pack_start(media, True, True, 0)

        profile = self.card()
        self.avatar = Gtk.Image()
        self.load_avatar(self.avatar, 110)
        profile.pack_start(self.avatar, False, False, 0)
        profile.pack_start(Gtk.Label(label=os.environ.get("USER", "user"), xalign=0.5), False, False, 0)
        right.pack_start(profile, False, False, 0)

        clock = self.card()
        self.time_label = Gtk.Label(label="--:--")
        self.time_label.get_style_context().add_class("big-time")
        self.date_label = Gtk.Label(label="")
        self.date_label.get_style_context().add_class("big-date")
        self.calendar_label = Gtk.Label(label="")
        self.calendar_label.get_style_context().add_class("calendar")
        clock.pack_start(self.time_label, False, False, 0)
        clock.pack_start(self.date_label, False, False, 0)
        clock.pack_start(self.calendar_label, False, False, 0)
        right.pack_start(clock, True, True, 0)

    def build_media_tab(self):
        page = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        page.set_border_width(4)
        self.tabs.append_page(page, self.tab_label(" Media"))

        left = self.card()
        page.pack_start(left, True, True, 0)
        self.big_album = Gtk.Image()
        self.big_album.set_pixel_size(230)
        left.pack_start(self.big_album, False, False, 0)
        self.big_title = Gtk.Label(label="No active track", xalign=0)
        self.big_title.get_style_context().add_class("track-title")
        self.big_artist = Gtk.Label(label="", xalign=0)
        left.pack_start(self.big_title, False, False, 0)
        left.pack_start(self.big_artist, False, False, 0)

        right = self.card()
        page.pack_start(right, False, False, 0)
        av = Gtk.Image()
        self.load_avatar(av, 120)
        right.pack_start(av, False, False, 0)
        self.cat_label = Gtk.Label(label=CAT_FRAMES[0])
        self.cat_label.get_style_context().add_class("cat")
        right.pack_start(self.cat_label, True, True, 0)

    def build_stats_tab(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        page.set_border_width(4)
        self.tabs.append_page(page, self.tab_label("󰍛 Stats"))

        grid = Gtk.Grid(column_spacing=12, row_spacing=12)
        page.pack_start(grid, False, False, 0)
        self.cpu_label = self.metric_card(grid, 0, 0, "CPU")
        self.gpu_label = self.metric_card(grid, 1, 0, "GPU")
        self.ram_label = self.metric_card(grid, 2, 0, "RAM")
        self.disk_label = self.metric_card(grid, 0, 1, "Disk")
        self.net_label = self.metric_card(grid, 1, 1, "Network")
        self.ip_label = self.metric_card(grid, 2, 1, "IP")

        graphs = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        page.pack_start(graphs, True, True, 0)
        self.cpu_graph = Graph()
        self.gpu_graph = Graph()
        self.net_graph = Graph()
        for title, graph in [("CPU load", self.cpu_graph), ("GPU load", self.gpu_graph), ("Network", self.net_graph)]:
            c = self.card()
            c.pack_start(Gtk.Label(label=title, xalign=0), False, False, 0)
            c.pack_start(graph, True, True, 0)
            graphs.pack_start(c, True, True, 0)

    def build_weather_tab(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        page.set_border_width(4)
        self.tabs.append_page(page, self.tab_label("󰖕 Weather"))
        header = self.card()
        self.weather_header = Gtk.Label(label="Kyiv weather", xalign=0)
        self.weather_header.get_style_context().add_class("weather-temp")
        self.sun_label = Gtk.Label(label="", xalign=0)
        header.pack_start(self.weather_header, False, False, 0)
        header.pack_start(self.sun_label, False, False, 0)
        page.pack_start(header, False, False, 0)
        self.weather_days = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        page.pack_start(self.weather_days, True, True, 0)

    def metric_card(self, grid, col, row, title):
        c = self.card()
        t = Gtk.Label(label=title, xalign=0)
        t.get_style_context().add_class("metric-title")
        v = Gtk.Label(label="--", xalign=0)
        c.pack_start(t, False, False, 0)
        c.pack_start(v, False, False, 0)
        grid.attach(c, col, row, 1, 1)
        return v

    def load_avatar(self, image, size):
        path = AVATAR if AVATAR.exists() else None
        if path:
            try:
                image.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(str(path), size, size, True))
                return
            except Exception:
                pass
        image.set_from_icon_name("avatar-default", Gtk.IconSize.DIALOG)

    def on_key(self, _w, event):
        if Gdk.keyval_name(event.keyval) == "Escape":
            Gtk.main_quit()
            return True
        return False

    def tick_fast(self):
        now = dt.datetime.now()
        self.time_label.set_text(now.strftime("%H:%M"))
        self.date_label.set_text(now.strftime("%A, %d.%m.%Y"))
        self.calendar_label.set_text(calendar.month(now.year, now.month))
        return True

    def player(self):
        if not command_exists("playerctl"):
            return None
        status = run(["playerctl", "status"])
        title = run(["playerctl", "metadata", "title"])
        artist = run(["playerctl", "metadata", "artist"])
        album = run(["playerctl", "metadata", "album"])
        art = run(["playerctl", "metadata", "mpris:artUrl"])
        player = run(["playerctl", "metadata", "--format", "{{playerName}}"])
        return {"status": status, "title": title, "artist": artist, "album": album, "art": art, "player": player}

    def find_media_sink(self, player_name):
        if not command_exists("pactl"):
            return None, None
        data = run(["pactl", "list", "sink-inputs"])
        blocks = re.split(r"Sink Input #", data)[1:]
        best = None
        for block in blocks:
            sid = block.splitlines()[0].strip()
            app = re.search(r'application.name = "([^"]+)"', block)
            media = re.search(r'media.name = "([^"]+)"', block)
            vol = re.search(r'Volume:.*?(\d+)%', block)
            text = f"{app.group(1) if app else ''} {media.group(1) if media else ''}".lower()
            if player_name and player_name.lower() in text:
                best = (sid, int(vol.group(1)) if vol else 100)
                break
            if best is None and vol:
                best = (sid, int(vol.group(1)))
        return best if best else (None, None)

    def set_album_art(self, art, image, size):
        if not art:
            image.set_from_icon_name("audio-x-generic", Gtk.IconSize.DIALOG)
            return
        path = None
        if art.startswith("file://"):
            path = Path(urllib.request.url2pathname(art[7:]))
        elif art.startswith("http"):
            safe = re.sub(r"[^a-zA-Z0-9]", "_", art)[-90:]
            path = CACHE / f"art_{safe}.jpg"
            if not path.exists():
                def dl():
                    try:
                        urllib.request.urlretrieve(art, path)
                        GLib.idle_add(lambda: self.set_album_art(art, image, size))
                    except Exception:
                        pass
                threading.Thread(target=dl, daemon=True).start()
                image.set_from_icon_name("audio-x-generic", Gtk.IconSize.DIALOG)
                return
        if path and path.exists():
            try:
                image.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(str(path), size, size, True))
                return
            except Exception:
                pass
        image.set_from_icon_name("audio-x-generic", Gtk.IconSize.DIALOG)

    def tick_media(self):
        p = self.player()
        if not p or not p.get("title"):
            for label in [self.track_title, self.big_title]:
                label.set_text("No active track")
            self.track_artist.set_text("")
            self.big_artist.set_text("")
            return True
        title = p.get("title") or "Unknown track"
        artist = p.get("artist") or p.get("player") or "Unknown artist"
        self.track_title.set_text(title)
        self.track_artist.set_text(f"{artist} · {p.get('status') or ''}")
        self.big_title.set_text(title)
        self.big_artist.set_text(f"{artist}\n{p.get('album') or ''}")
        self.set_album_art(p.get("art"), self.album_image, 82)
        self.set_album_art(p.get("art"), self.big_album, 230)
        sid, vol = self.find_media_sink(p.get("player"))
        self.media_volume_id = sid
        if vol is not None:
            self.volume_guard = True
            self.volume.set_value(vol)
            self.volume_guard = False
            self.volume_label.set_text(f"App volume: {vol}%")
        return True

    def on_volume_changed(self, scale):
        if self.volume_guard or not self.media_volume_id:
            return
        value = int(scale.get_value())
        subprocess.Popen(["pactl", "set-sink-input-volume", str(self.media_volume_id), f"{value}%"])
        self.volume_label.set_text(f"App volume: {value}%")

    def cpu_usage(self):
        try:
            parts = [int(x) for x in Path("/proc/stat").read_text().splitlines()[0].split()[1:]]
            idle = parts[3] + parts[4]
            total = sum(parts)
            if self.last_cpu_total is None:
                self.last_cpu_total, self.last_cpu_idle = total, idle
                return 0
            diff_total = total - self.last_cpu_total
            diff_idle = idle - self.last_cpu_idle
            self.last_cpu_total, self.last_cpu_idle = total, idle
            return 100 * (1 - diff_idle / max(1, diff_total))
        except Exception:
            return 0

    def ram_usage(self):
        vals = {}
        try:
            for line in Path("/proc/meminfo").read_text().splitlines():
                k, v = line.split(":", 1)
                vals[k] = int(v.strip().split()[0])
            total = vals.get("MemTotal", 1)
            avail = vals.get("MemAvailable", 0)
            return 100 * (1 - avail / total), (total - avail) / 1024 / 1024, total / 1024 / 1024
        except Exception:
            return 0, 0, 0

    def cpu_temp(self):
        paths = list(Path("/sys/class/thermal").glob("thermal_zone*/temp"))
        temps = []
        for p in paths:
            try:
                val = int(p.read_text().strip()) / 1000
                if 20 <= val <= 120:
                    temps.append(val)
            except Exception:
                pass
        return max(temps) if temps else None

    def gpu_stats(self):
        if command_exists("nvidia-smi"):
            out = run(["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"])
            if out:
                try:
                    u, t = [float(x.strip()) for x in out.splitlines()[0].split(",")[:2]]
                    return u, t
                except Exception:
                    pass
        return 0, None

    def disk_usage(self):
        usage = shutil.disk_usage("/")
        return usage.used / usage.total * 100, usage.used / 1024**3, usage.total / 1024**3

    def net_usage(self):
        rx = tx = 0
        try:
            for line in Path("/proc/net/dev").read_text().splitlines()[2:]:
                if ":" not in line:
                    continue
                iface, rest = line.split(":", 1)
                iface = iface.strip()
                if iface == "lo":
                    continue
                nums = rest.split()
                rx += int(nums[0])
                tx += int(nums[8])
        except Exception:
            return 0, 0, 0
        now = time.time()
        if self.last_net_rx is None:
            self.last_net_rx, self.last_net_tx, self.last_net_time = rx, tx, now
            return 0, 0, 0
        dt_s = max(0.1, now - self.last_net_time)
        drx = (rx - self.last_net_rx) / dt_s
        dtx = (tx - self.last_net_tx) / dt_s
        self.last_net_rx, self.last_net_tx, self.last_net_time = rx, tx, now
        return drx, dtx, min(100, (drx + dtx) / 1024 / 1024 * 10)

    def ip_address(self):
        out = run("ip -4 addr show scope global | awk '/inet / {print $2, $NF; exit}'", shell=True)
        return out or socket.gethostbyname(socket.gethostname())

    def tick_stats(self):
        cpu = self.cpu_usage()
        cpu_t = self.cpu_temp()
        gpu, gpu_t = self.gpu_stats()
        ram, ram_used, ram_total = self.ram_usage()
        disk, disk_used, disk_total = self.disk_usage()
        rx, tx, net_graph = self.net_usage()
        self.cpu_label.set_text(f"{cpu:.0f}%  ·  {cpu_t:.0f}°C" if cpu_t else f"{cpu:.0f}%")
        self.gpu_label.set_text(f"{gpu:.0f}%  ·  {gpu_t:.0f}°C" if gpu_t else f"{gpu:.0f}%")
        self.ram_label.set_text(f"{ram:.0f}%  ·  {ram_used:.1f}/{ram_total:.1f} GiB")
        self.disk_label.set_text(f"{disk:.0f}%  ·  {disk_used:.0f}/{disk_total:.0f} GiB")
        self.net_label.set_text(f"↓ {rx/1024:.0f} KiB/s  ↑ {tx/1024:.0f} KiB/s")
        self.ip_label.set_text(self.ip_address())
        self.cpu_graph.push(cpu)
        self.gpu_graph.push(gpu)
        self.net_graph.push(net_graph)
        return True

    def fetch_weather(self):
        url = "https://api.open-meteo.com/v1/forecast?latitude=50.4501&longitude=30.5234&current=temperature_2m,relative_humidity_2m,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,relative_humidity_2m_mean,wind_speed_10m_max,sunrise,sunset&timezone=Europe%2FKyiv&forecast_days=5"
        data = read_json_url(url)
        if data:
            WEATHER_CACHE.write_text(json.dumps(data))
            return data
        if WEATHER_CACHE.exists():
            try:
                return json.loads(WEATHER_CACHE.read_text())
            except Exception:
                pass
        return None

    def tick_weather(self):
        def worker():
            data = self.fetch_weather()
            GLib.idle_add(lambda: self.apply_weather(data))
        threading.Thread(target=worker, daemon=True).start()
        return True

    def apply_weather(self, data):
        if not data:
            self.home_weather.set_text("No weather")
            self.weather_header.set_text("Weather unavailable")
            return False
        cur = data.get("current", {})
        temp = cur.get("temperature_2m")
        hum = cur.get("relative_humidity_2m")
        wind = cur.get("wind_speed_10m")
        self.home_weather.set_text(f"{temp:.0f}°C" if isinstance(temp, (int, float)) else "--°C")
        self.home_weather_sub.set_text(f"Kyiv · humidity {hum}% · wind {wind} km/h")
        self.weather_header.set_text(f"Kyiv · {temp:.0f}°C")
        daily = data.get("daily", {})
        sunrise = daily.get("sunrise", [""])[0][-5:] if daily.get("sunrise") else "--:--"
        sunset = daily.get("sunset", [""])[0][-5:] if daily.get("sunset") else "--:--"
        self.sun_label.set_text(f"Sunrise {sunrise} · Sunset {sunset} · humidity {hum}% · wind {wind} km/h")
        for child in self.weather_days.get_children():
            self.weather_days.remove(child)
        times = daily.get("time", [])
        for i, day in enumerate(times[:5]):
            c = self.card()
            date = dt.datetime.strptime(day, "%Y-%m-%d")
            name = date.strftime("%a %d.%m")
            tmax = daily.get("temperature_2m_max", [None]*5)[i]
            tmin = daily.get("temperature_2m_min", [None]*5)[i]
            h = daily.get("relative_humidity_2m_mean", [None]*5)[i]
            w = daily.get("wind_speed_10m_max", [None]*5)[i]
            sr = daily.get("sunrise", [""]*5)[i][-5:]
            ss = daily.get("sunset", [""]*5)[i][-5:]
            lbl = Gtk.Label(label=f"{name}\n{tmin:.0f}° / {tmax:.0f}°\n󰖎 {h:.0f}%\n󰖝 {w:.0f} km/h\n󰖜 {sr}\n󰖛 {ss}", xalign=0)
            lbl.get_style_context().add_class("weather-day")
            c.pack_start(lbl, True, True, 0)
            self.weather_days.pack_start(c, True, True, 0)
        self.weather_days.show_all()
        return False

    def tick_cat(self):
        self.cat_index = (self.cat_index + 1) % len(CAT_FRAMES)
        self.cat_label.set_text(CAT_FRAMES[self.cat_index])
        return True


if __name__ == "__main__":
    missing = []
    for name in ["playerctl", "pactl"]:
        if not command_exists(name):
            missing.append(name)
    if missing:
        print("Missing optional runtime dependencies:", ", ".join(missing), file=sys.stderr)
    win = Dashboard()
    win.show_center_top()
    Gtk.main()
