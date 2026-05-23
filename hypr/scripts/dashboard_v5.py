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

PANEL_WIDTH = 1040
PANEL_HEIGHT = 560
TOP_MARGIN = 36

CSS = b"""
* {
    all: unset;
    font-family: "Inter", "JetBrainsMono Nerd Font", "Noto Color Emoji", sans-serif;
    color: #f2eaff;
    font-size: 13px;
}

window { background: transparent; }

.panel {
    background: linear-gradient(135deg, rgba(18, 12, 25, 0.66), rgba(31, 18, 39, 0.58));
    border: 1px solid rgba(255, 164, 232, 0.22);
    border-radius: 30px;
    padding: 14px;
    box-shadow: 0 28px 90px rgba(0, 0, 0, 0.48);
}

.header-title { font-size: 22px; font-weight: 900; color: #ffffff; }
.header-subtitle { font-size: 11px; color: rgba(242, 234, 255, 0.60); }

.tabs {
    background: rgba(255, 255, 255, 0.055);
    border: 1px solid rgba(255, 255, 255, 0.09);
    border-radius: 999px;
    padding: 4px;
}

.tab {
    min-height: 29px;
    padding: 0 13px;
    border-radius: 999px;
    color: rgba(242, 234, 255, 0.68);
    font-weight: 850;
}

.tab:hover {
    background: rgba(255, 164, 232, 0.12);
    color: #ffffff;
}

.tab-active {
    min-height: 29px;
    padding: 0 13px;
    border-radius: 999px;
    color: #ffffff;
    font-weight: 900;
    background: linear-gradient(135deg, rgba(255, 116, 214, 0.36), rgba(171, 139, 255, 0.30));
    border: 1px solid rgba(255, 164, 232, 0.45);
}

.card {
    background: rgba(255, 255, 255, 0.045);
    border: 1px solid rgba(255, 255, 255, 0.075);
    border-radius: 22px;
    padding: 12px;
}

.card-soft {
    background: linear-gradient(145deg, rgba(255, 255, 255, 0.065), rgba(255, 255, 255, 0.030));
    border: 1px solid rgba(255, 255, 255, 0.09);
    border-radius: 22px;
    padding: 12px;
}

.card-accent {
    background: linear-gradient(135deg, rgba(255, 116, 214, 0.17), rgba(137, 180, 250, 0.12));
    border: 1px solid rgba(255, 164, 232, 0.26);
    border-radius: 22px;
    padding: 12px;
}

.card-today {
    background: linear-gradient(135deg, rgba(255, 116, 214, 0.30), rgba(171, 139, 255, 0.22));
    border: 1px solid rgba(255, 196, 242, 0.76);
    border-radius: 22px;
    padding: 12px;
}

.section-title {
    color: #ffb8ea;
    font-size: 12px;
    font-weight: 900;
}

.muted { color: rgba(242, 234, 255, 0.62); font-size: 12px; }
.micro { color: rgba(242, 234, 255, 0.48); font-size: 11px; }

.big-time { font-size: 44px; font-weight: 950; color: #ffffff; }
.big-temp { font-size: 40px; font-weight: 950; color: #ffffff; }
.track-title { font-size: 17px; font-weight: 950; color: #ffffff; }
.track-title-big { font-size: 24px; font-weight: 950; color: #ffffff; }
.metric-value { font-size: 18px; font-weight: 950; color: #ffffff; }

.album-frame {
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 18px;
    padding: 6px;
}

.icon-button {
    min-width: 34px;
    min-height: 34px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.065);
    border: 1px solid rgba(255, 255, 255, 0.12);
    color: #ffffff;
    font-size: 14px;
    font-weight: 900;
}

.icon-button:hover {
    background: rgba(255, 116, 214, 0.22);
    border-color: rgba(255, 164, 232, 0.44);
}

.play-button {
    min-width: 44px;
    min-height: 44px;
    border-radius: 999px;
    background: linear-gradient(135deg, rgba(255, 116, 214, 0.42), rgba(171, 139, 255, 0.35));
    border: 1px solid rgba(255, 196, 242, 0.60);
    color: #ffffff;
    font-size: 15px;
    font-weight: 950;
}

.close-button {
    min-width: 34px;
    min-height: 34px;
    border-radius: 999px;
    background: rgba(255, 116, 160, 0.14);
    border: 1px solid rgba(255, 116, 160, 0.35);
    color: #ff9cb6;
    font-weight: 900;
}
.close-button:hover { background: rgba(255, 116, 160, 0.28); color: #ffffff; }

scale trough { min-height: 8px; border-radius: 99px; background: rgba(255, 255, 255, 0.13); }
scale highlight { border-radius: 99px; background: linear-gradient(90deg, #ff74d6, #ab8bff); }
scale slider { min-width: 16px; min-height: 16px; border-radius: 99px; background: #ffffff; border: 2px solid rgba(255, 164, 232, 0.70); }

.calendar-title { color: #ffffff; font-size: 15px; font-weight: 950; }
.calendar-weekday { color: #ffb8ea; font-size: 11px; font-weight: 900; }
.calendar-day { min-width: 29px; min-height: 23px; border-radius: 9px; color: rgba(242, 234, 255, 0.78); font-weight: 850; }
.calendar-day-muted { color: rgba(242, 234, 255, 0.25); }
.calendar-day-today { min-width: 29px; min-height: 23px; border-radius: 9px; background: rgba(255, 116, 214, 0.30); color: #ffffff; font-weight: 950; border: 1px solid rgba(255, 196, 242, 0.72); }

.weather-day { font-size: 12px; font-weight: 850; }
"""


def run(cmd, shell=False, timeout=2):
    try:
        return subprocess.run(cmd, shell=shell, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout).stdout.strip()
    except Exception:
        return ""


def has(cmd):
    return shutil.which(cmd) is not None


def clamp(value, low=0, high=100):
    return max(low, min(high, value))


class BongoCat(Gtk.DrawingArea):
    def __init__(self):
        super().__init__()
        self.frame = 0
        self.set_size_request(250, 250)
        self.connect("draw", self.on_draw)

    def tick(self):
        self.frame = (self.frame + 1) % 4
        self.queue_draw()
        return True

    def on_draw(self, _widget, cr):
        w = self.get_allocated_width()
        h = self.get_allocated_height()
        t = self.frame
        cx = w / 2
        cy = h / 2 + 2

        def rgba(hex_color, alpha=1.0):
            hex_color = hex_color.lstrip("#")
            r = int(hex_color[0:2], 16) / 255
            g = int(hex_color[2:4], 16) / 255
            b = int(hex_color[4:6], 16) / 255
            cr.set_source_rgba(r, g, b, alpha)

        def rounded_rect(x, y, ww, hh, r):
            cr.new_sub_path()
            cr.arc(x + ww - r, y + r, r, -math.pi / 2, 0)
            cr.arc(x + ww - r, y + hh - r, r, 0, math.pi / 2)
            cr.arc(x + r, y + hh - r, r, math.pi / 2, math.pi)
            cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
            cr.close_path()

        # keyboard
        rounded_rect(cx - 86, cy + 62, 172, 38, 12)
        rgba("#211727", 0.96)
        cr.fill_preserve()
        rgba("#ffb8ea", 0.26)
        cr.set_line_width(1.2)
        cr.stroke()
        for i in range(8):
            rounded_rect(cx - 72 + i * 18, cy + 73, 12, 8, 3)
            rgba("#ffffff", 0.12)
            cr.fill()

        # body
        cr.arc(cx, cy + 38, 70, math.pi, 2 * math.pi)
        cr.line_to(cx + 70, cy + 95)
        cr.line_to(cx - 70, cy + 95)
        cr.close_path()
        rgba("#fff8ff", 0.96)
        cr.fill_preserve()
        rgba("#ffb8ea", 0.45)
        cr.set_line_width(2)
        cr.stroke()

        # head
        cr.arc(cx, cy - 14, 62, 0, 2 * math.pi)
        rgba("#fff8ff", 0.98)
        cr.fill_preserve()
        rgba("#ffb8ea", 0.52)
        cr.set_line_width(2.2)
        cr.stroke()

        # ears
        cr.move_to(cx - 48, cy - 52)
        cr.line_to(cx - 68, cy - 100)
        cr.line_to(cx - 20, cy - 72)
        cr.close_path()
        rgba("#fff8ff", 0.98)
        cr.fill_preserve()
        rgba("#ffb8ea", 0.52)
        cr.stroke()
        cr.move_to(cx + 48, cy - 52)
        cr.line_to(cx + 68, cy - 100)
        cr.line_to(cx + 20, cy - 72)
        cr.close_path()
        rgba("#fff8ff", 0.98)
        cr.fill_preserve()
        rgba("#ffb8ea", 0.52)
        cr.stroke()
        cr.move_to(cx - 50, cy - 62)
        cr.line_to(cx - 60, cy - 88)
        cr.line_to(cx - 32, cy - 70)
        cr.close_path()
        rgba("#ffb8ea", 0.25)
        cr.fill()
        cr.move_to(cx + 50, cy - 62)
        cr.line_to(cx + 60, cy - 88)
        cr.line_to(cx + 32, cy - 70)
        cr.close_path()
        rgba("#ffb8ea", 0.25)
        cr.fill()

        # face
        rgba("#231827", 0.96)
        cr.arc(cx - 22, cy - 20, 5, 0, 2 * math.pi)
        cr.fill()
        cr.arc(cx + 22, cy - 20, 5, 0, 2 * math.pi)
        cr.fill()
        cr.set_line_width(2)
        cr.move_to(cx - 6, cy - 4)
        cr.curve_to(cx - 2, cy + 2, cx + 2, cy + 2, cx + 6, cy - 4)
        cr.stroke()
        for side in [-1, 1]:
            for yy in [-7, 0, 7]:
                cr.move_to(cx + side * 30, cy + yy)
                cr.line_to(cx + side * 52, cy + yy - side * 4)
        rgba("#231827", 0.38)
        cr.set_line_width(1.3)
        cr.stroke()

        # paws animate
        left_up = t in [0, 3]
        right_up = t in [1, 2]
        left_y = cy + (40 if left_up else 72)
        right_y = cy + (40 if right_up else 72)
        for x, y in [(cx - 44, left_y), (cx + 44, right_y)]:
            cr.arc(x, y, 19, 0, 2 * math.pi)
            rgba("#fff8ff", 0.98)
            cr.fill_preserve()
            rgba("#ffb8ea", 0.48)
            cr.set_line_width(2)
            cr.stroke()

        return False


class Graph(Gtk.DrawingArea):
    def __init__(self):
        super().__init__()
        self.values = []
        self.set_size_request(294, 84)
        self.connect("draw", self.on_draw)

    def push(self, value):
        self.values = (self.values + [float(clamp(value))])[-70:]
        self.queue_draw()

    def on_draw(self, _widget, cr):
        width = self.get_allocated_width()
        height = self.get_allocated_height()
        cr.set_source_rgba(1, 1, 1, 0.04)
        cr.rectangle(0, 0, width, height)
        cr.fill()
        if len(self.values) < 2:
            return False
        step = width / 69
        start = 70 - len(self.values)
        cr.set_source_rgba(1.0, 0.45, 0.84, 0.14)
        cr.move_to(start * step, height)
        for i, value in enumerate(self.values):
            x = (start + i) * step
            y = height - (value / 100) * height
            cr.line_to(x, y)
        cr.line_to(width, height)
        cr.close_path()
        cr.fill()
        cr.set_source_rgba(1.0, 0.66, 0.92, 0.96)
        cr.set_line_width(2.2)
        for i, value in enumerate(self.values):
            x = (start + i) * step
            y = height - (value / 100) * height
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
            GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, -PANEL_HEIGHT)
            GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.tabs = []
        self.media_sink = None
        self.volume_guard = False
        self.last_cpu = None
        self.last_net = None

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        panel.set_size_request(PANEL_WIDTH, PANEL_HEIGHT)
        panel.get_style_context().add_class("panel")
        self.add(panel)

        self.build_header(panel)
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(180)
        panel.pack_start(self.stack, True, True, 0)

        self.build_main_page()
        self.build_media_page()
        self.build_stats_page()
        self.build_weather_page()
        self.set_tab(0)

        GLib.timeout_add_seconds(1, self.tick_clock)
        GLib.timeout_add_seconds(2, self.tick_media)
        GLib.timeout_add_seconds(2, self.tick_stats)
        GLib.timeout_add_seconds(900, self.tick_weather)
        self.tick_clock()
        self.tick_media()
        self.tick_stats()
        self.tick_weather()

    def build_header(self, panel):
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        panel.pack_start(header, False, False, 0)
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        header.pack_start(title_box, True, True, 0)
        title_box.pack_start(self.label("󰕮 Dashboard", "header-title"), False, False, 0)
        title_box.pack_start(self.label("media · weather · calendar · system", "header-subtitle"), False, False, 0)
        tab_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        tab_box.get_style_context().add_class("tabs")
        header.pack_start(tab_box, False, False, 0)
        for idx, text in enumerate(["󰃭 Main", " Media", "󰍛 Stats", "󰖕 Weather"]):
            button = Gtk.Button(label=text)
            button.connect("clicked", lambda _b, i=idx: self.set_tab(i))
            self.tabs.append(button)
            tab_box.pack_start(button, False, False, 0)
        close = Gtk.Button(label="×")
        close.get_style_context().add_class("close-button")
        close.connect("clicked", lambda *_: Gtk.main_quit())
        header.pack_end(close, False, False, 0)

    def set_tab(self, idx):
        self.stack.set_visible_child_name(str(idx))
        for i, button in enumerate(self.tabs):
            ctx = button.get_style_context()
            ctx.remove_class("tab")
            ctx.remove_class("tab-active")
            ctx.add_class("tab-active" if i == idx else "tab")

    def label(self, text, css=None, xalign=0):
        label = Gtk.Label(label=text, xalign=xalign)
        label.set_line_wrap(True)
        label.set_max_width_chars(44)
        if css:
            label.get_style_context().add_class(css)
        return label

    def card(self, style="card"):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.get_style_context().add_class(style)
        return box

    def add_page(self, idx, orientation=Gtk.Orientation.HORIZONTAL):
        page = Gtk.Box(orientation=orientation, spacing=12)
        self.stack.add_named(page, str(idx))
        return page

    def avatar(self, size):
        image = Gtk.Image()
        if AVATAR.exists():
            try:
                image.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(str(AVATAR), size, size, True))
                return image
            except Exception:
                pass
        image.set_from_icon_name("avatar-default", Gtk.IconSize.DIALOG)
        return image

    def build_main_page(self):
        page = self.add_page(0)
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        middle = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        page.pack_start(left, True, True, 0)
        page.pack_start(middle, True, True, 0)
        page.pack_start(right, False, False, 0)

        weather = self.card("card-accent")
        weather.set_size_request(320, 120)
        weather.pack_start(self.label("󰖕 Kyiv weather", "section-title"), False, False, 0)
        self.home_weather = self.label("--°C", "big-temp")
        self.home_weather_sub = self.label("loading…", "muted")
        weather.pack_start(self.home_weather, False, False, 0)
        weather.pack_start(self.home_weather_sub, False, False, 0)
        left.pack_start(weather, False, False, 0)
        self.build_media_card(left, small=True)

        clock = self.card("card-accent")
        clock.set_size_request(320, 134)
        clock.pack_start(self.label(" Time", "section-title"), False, False, 0)
        self.time_label = self.label("--:--", "big-time", 0.5)
        self.date_label = self.label("", "muted", 0.5)
        clock.pack_start(self.time_label, False, False, 0)
        clock.pack_start(self.date_label, False, False, 0)
        middle.pack_start(clock, False, False, 0)

        calendar_card = self.card("card-soft")
        calendar_card.set_size_request(320, 320)
        self.calendar_title = self.label("Calendar", "calendar-title", 0.5)
        calendar_card.pack_start(self.calendar_title, False, False, 0)
        self.calendar_grid = Gtk.Grid(row_spacing=4, column_spacing=4)
        calendar_card.pack_start(self.calendar_grid, True, True, 0)
        middle.pack_start(calendar_card, True, True, 0)

        profile = self.card("card-soft")
        profile.set_size_request(178, 190)
        profile.pack_start(self.avatar(108), False, False, 0)
        profile.pack_start(self.label(os.environ.get("USER", "user"), "track-title", 0.5), False, False, 0)
        profile.pack_start(self.label("Arch · Hyprland", "muted", 0.5), False, False, 0)
        right.pack_start(profile, False, False, 0)

        quick = self.card("card")
        quick.set_size_request(178, -1)
        quick.pack_start(self.label("Keys", "section-title"), False, False, 0)
        quick.pack_start(self.label("Esc close\n1–4 tabs\nSuper+M toggle", "muted"), True, True, 0)
        right.pack_start(quick, True, True, 0)

    def build_media_card(self, parent, small):
        card = self.card("card-soft")
        parent.pack_start(card, True, True, 0)
        card.pack_start(self.label(" Active track", "section-title"), False, False, 0)
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        card.pack_start(row, False, False, 0)
        album_frame = Gtk.Box()
        album_frame.get_style_context().add_class("album-frame")
        image = Gtk.Image()
        image.set_pixel_size(90 if small else 252)
        album_frame.pack_start(image, True, True, 0)
        row.pack_start(album_frame, False, False, 0)
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        row.pack_start(info, True, True, 0)
        title = self.label("No active track", "track-title" if small else "track-title-big")
        artist = self.label("", "muted")
        info.pack_start(title, False, False, 0)
        info.pack_start(artist, False, False, 0)
        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=9)
        info.pack_start(controls, False, False, 0)
        prev_btn = Gtk.Button(label="")
        prev_btn.get_style_context().add_class("icon-button")
        prev_btn.connect("clicked", lambda *_: subprocess.Popen("playerctl previous", shell=True))
        play_btn = Gtk.Button(label="")
        play_btn.get_style_context().add_class("play-button")
        play_btn.connect("clicked", lambda *_: subprocess.Popen("playerctl play-pause", shell=True))
        next_btn = Gtk.Button(label="")
        next_btn.get_style_context().add_class("icon-button")
        next_btn.connect("clicked", lambda *_: subprocess.Popen("playerctl next", shell=True))
        controls.pack_start(prev_btn, False, False, 0)
        controls.pack_start(play_btn, False, False, 0)
        controls.pack_start(next_btn, False, False, 0)
        if small:
            self.album = image
            self.track_title = title
            self.track_artist = artist
            self.play_button = play_btn
            self.volume_label = self.label("App volume", "muted")
            info.pack_start(self.volume_label, False, False, 0)
            self.volume = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 150, 1)
            self.volume.connect("value-changed", self.on_volume_changed)
            info.pack_start(self.volume, False, False, 0)
        else:
            self.big_album = image
            self.big_track_title = title
            self.big_track_artist = artist
            self.big_play_button = play_btn

    def build_media_page(self):
        page = self.add_page(1)
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        side = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        page.pack_start(left, True, True, 0)
        page.pack_start(side, False, False, 0)
        self.build_media_card(left, small=False)
        cat_card = self.card("card-accent")
        cat_card.set_size_request(270, -1)
        cat_card.pack_start(self.avatar(92), False, False, 0)
        self.bongo = BongoCat()
        cat_card.pack_start(self.bongo, True, True, 0)
        side.pack_start(cat_card, True, True, 0)
        GLib.timeout_add(260, self.bongo.tick)

    def build_stats_page(self):
        page = self.add_page(2, Gtk.Orientation.VERTICAL)
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
        for title, graph in [("CPU", self.cpu_graph), ("GPU", self.gpu_graph), ("Internet", self.net_graph)]:
            graph_card = self.card("card-soft")
            graph_card.pack_start(self.label(title, "section-title"), False, False, 0)
            graph_card.pack_start(graph, True, True, 0)
            graphs.pack_start(graph_card, True, True, 0)

    def metric(self, grid, col, row, name):
        card = self.card("card-soft")
        card.set_size_request(320, 68)
        card.pack_start(self.label(name, "section-title"), False, False, 0)
        value = self.label("--", "metric-value")
        card.pack_start(value, False, False, 0)
        grid.attach(card, col, row, 1, 1)
        return value

    def build_weather_page(self):
        page = self.add_page(3, Gtk.Orientation.VERTICAL)
        header = self.card("card-accent")
        header.set_size_request(-1, 104)
        self.weather_header = self.label("Kyiv weather", "big-temp")
        self.sun_label = self.label("loading…", "muted")
        header.pack_start(self.weather_header, False, False, 0)
        header.pack_start(self.sun_label, False, False, 0)
        page.pack_start(header, False, False, 0)
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
        self.anim_margin += max(10, int((TOP_MARGIN - self.anim_margin) * 0.24))
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, self.anim_margin)
        if self.anim_margin >= TOP_MARGIN:
            GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, TOP_MARGIN)
            return False
        return True

    def animate_window(self):
        self.y += max(10, int((self.target_y - self.y) * 0.24))
        self.move(self.x, self.y)
        return self.y < self.target_y

    def on_key(self, _window, event):
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
        self.update_calendar(now.date())
        return True

    def update_calendar(self, today):
        for child in self.calendar_grid.get_children():
            self.calendar_grid.remove(child)
        self.calendar_title.set_text(today.strftime("%B %Y"))
        weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        for col, name in enumerate(weekdays):
            self.calendar_grid.attach(self.label(name, "calendar-weekday", 0.5), col, 0, 1, 1)
        cal = calendar.Calendar(firstweekday=0)
        for row, week in enumerate(cal.monthdatescalendar(today.year, today.month), start=1):
            for col, day in enumerate(week):
                label = self.label(str(day.day), "calendar-day", 0.5)
                if day.month != today.month:
                    label.get_style_context().add_class("calendar-day-muted")
                if day == today:
                    label.get_style_context().remove_class("calendar-day")
                    label.get_style_context().add_class("calendar-day-today")
                self.calendar_grid.attach(label, col, row, 1, 1)
        self.calendar_grid.show_all()

    def set_album_art(self, url, image, size):
        if not url:
            image.set_from_icon_name("audio-x-generic", Gtk.IconSize.DIALOG)
            return
        path = None
        if url.startswith("file://"):
            path = Path(urllib.request.url2pathname(url[7:]))
        elif url.startswith("http"):
            safe = re.sub(r"[^a-zA-Z0-9]", "_", url)[-100:]
            path = CACHE / f"art_{safe}.jpg"
            if not path.exists():
                def download():
                    try:
                        urllib.request.urlretrieve(url, path)
                        GLib.idle_add(lambda: self.set_album_art(url, image, size))
                    except Exception:
                        pass
                threading.Thread(target=download, daemon=True).start()
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
        if not has("playerctl"):
            return True
        title = run(["playerctl", "metadata", "title"])
        artist = run(["playerctl", "metadata", "artist"])
        art = run(["playerctl", "metadata", "mpris:artUrl"])
        player = run(["playerctl", "metadata", "--format", "{{playerName}}"])
        status = run(["playerctl", "status"])
        playing = status.lower() == "playing"
        if not title:
            title = "No active track"
            artist = ""
        for label in [self.track_title, self.big_track_title]:
            label.set_text(title)
        for label in [self.track_artist, self.big_track_artist]:
            label.set_text(f"{artist} · {status}" if artist else status)
        self.play_button.set_label("" if playing else "")
        self.big_play_button.set_label("" if playing else "")
        self.set_album_art(art, self.album, 90)
        self.set_album_art(art, self.big_album, 252)
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
            self.volume_guard = True
            self.volume.set_value(volume)
            self.volume_guard = False
            self.volume_label.set_text(f"App volume · {volume}%")

    def on_volume_changed(self, scale):
        if self.volume_guard or not self.media_sink:
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
            prev_total, prev_idle = self.last_cpu
            self.last_cpu = (total, idle)
            return 100 * (1 - (idle - prev_idle) / max(1, total - prev_total))
        except Exception:
            return 0

    def cpu_temp(self):
        vals = []
        for path in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
            try:
                value = int(path.read_text().strip()) / 1000
                if 20 <= value <= 120:
                    vals.append(value)
            except Exception:
                pass
        return max(vals) if vals else None

    def gpu_stats(self):
        if has("nvidia-smi"):
            out = run(["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"])
            try:
                return tuple(float(x.strip()) for x in out.splitlines()[0].split(",")[:2])
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
        prev_rx, prev_tx, prev_time = self.last_net
        self.last_net = (rx, tx, now)
        elapsed = max(0.1, now - prev_time)
        down = (rx - prev_rx) / elapsed
        up = (tx - prev_tx) / elapsed
        graph = min(100, (down + up) / 1024 / 1024 * 10)
        return down, up, graph

    def tick_stats(self):
        cpu = self.cpu_usage()
        ctemp = self.cpu_temp()
        gpu, gtemp = self.gpu_stats()
        mem = {}
        try:
            for line in Path("/proc/meminfo").read_text().splitlines():
                key, value = line.split(":", 1)
                mem[key] = int(value.strip().split()[0])
            ram = 100 * (1 - mem.get("MemAvailable", 0) / mem.get("MemTotal", 1))
        except Exception:
            ram = 0
        disk_usage = shutil.disk_usage("/")
        disk = disk_usage.used / disk_usage.total * 100
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
        current = data.get("current", {})
        daily = data.get("daily", {})
        temp = current.get("temperature_2m", 0)
        humidity = current.get("relative_humidity_2m", 0)
        wind = current.get("wind_speed_10m", 0)
        self.home_weather.set_text(f"{temp:.0f}°C")
        self.home_weather_sub.set_text(f"Kyiv · humidity {humidity}% · wind {wind} km/h")
        self.weather_header.set_text(f"Kyiv · {temp:.0f}°C")
        sunrise = daily.get("sunrise", [""])[0][-5:]
        sunset = daily.get("sunset", [""])[0][-5:]
        self.sun_label.set_text(f"Today · sunrise {sunrise} · sunset {sunset} · humidity {humidity}% · wind {wind} km/h")
        for child in self.days_box.get_children():
            self.days_box.remove(child)
        today = dt.date.today().isoformat()
        for i, day in enumerate(daily.get("time", [])[:7]):
            card = self.card("card-today" if day == today else "card-soft")
            date = dt.datetime.strptime(day, "%Y-%m-%d")
            name = ("Today" if day == today else date.strftime("%a")) + date.strftime(" %d.%m")
            tmax = daily["temperature_2m_max"][i]
            tmin = daily["temperature_2m_min"][i]
            hum = daily["relative_humidity_2m_mean"][i]
            win = daily["wind_speed_10m_max"][i]
            sr = daily["sunrise"][i][-5:]
            ss = daily["sunset"][i][-5:]
            label = self.label(f"{name}\n\n{tmin:.0f}° / {tmax:.0f}°\n󰖎 {hum:.0f}%\n󰖝 {win:.0f} km/h\n󰖜 {sr}\n󰖛 {ss}", "weather-day")
            card.pack_start(label, True, True, 0)
            self.days_box.pack_start(card, True, True, 0)
        self.days_box.show_all()
        return False


if __name__ == "__main__":
    Dashboard().show_overlay()
    Gtk.main()
