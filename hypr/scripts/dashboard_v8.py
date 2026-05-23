#!/usr/bin/env python3
import os
import subprocess

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk, Pango

import dashboard_v5 as base

# GTK CSS supports normal numeric weights, not web-style arbitrary weights.
base.CSS = b"""
* {
    all: unset;
    font-family: "Inter", "JetBrainsMono Nerd Font", "Noto Color Emoji", sans-serif;
    color: #f4eaff;
    font-size: 13px;
}

window { background: transparent; }

.panel {
    background: linear-gradient(135deg, rgba(16, 11, 22, 0.78), rgba(27, 16, 34, 0.74));
    border: 1px solid rgba(255, 170, 235, 0.26);
    border-radius: 30px;
    padding: 14px;
    box-shadow: 0 28px 90px rgba(0, 0, 0, 0.52);
}

.header-title { font-size: 22px; font-weight: 900; color: #ffffff; }
.header-subtitle { font-size: 11px; color: rgba(244, 234, 255, 0.68); }

.tabs {
    background: rgba(20, 15, 28, 0.92);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 999px;
    padding: 4px;
}

.tab {
    min-height: 30px;
    padding: 0 14px;
    border-radius: 999px;
    color: rgba(244, 234, 255, 0.72);
    font-weight: 800;
}

.tab:hover {
    background: rgba(255, 170, 235, 0.16);
    color: #ffffff;
}

.tab-active {
    min-height: 30px;
    padding: 0 14px;
    border-radius: 999px;
    color: #ffffff;
    font-weight: 900;
    background: linear-gradient(135deg, rgba(255, 94, 202, 0.48), rgba(171, 139, 255, 0.40));
    border: 1px solid rgba(255, 196, 242, 0.54);
}

.card, .card-soft, .card-accent, .card-today {
    border-radius: 22px;
    padding: 12px;
}

.card {
    background: rgba(24, 19, 30, 0.94);
    border: 1px solid rgba(255, 255, 255, 0.10);
}

.card-soft {
    background: rgba(26, 21, 33, 0.95);
    border: 1px solid rgba(255, 255, 255, 0.11);
}

.card-accent {
    background: linear-gradient(135deg, rgba(42, 26, 48, 0.96), rgba(32, 24, 44, 0.95));
    border: 1px solid rgba(255, 170, 235, 0.30);
}

.card-today {
    background: linear-gradient(135deg, rgba(72, 36, 74, 0.98), rgba(50, 38, 72, 0.98));
    border: 1px solid rgba(255, 210, 245, 0.78);
}

.section-title { color: #ffb8ea; font-size: 12px; font-weight: 900; }
.muted { color: rgba(244, 234, 255, 0.68); font-size: 12px; }
.micro { color: rgba(244, 234, 255, 0.52); font-size: 11px; }
.big-time { font-size: 44px; font-weight: 900; color: #ffffff; }
.big-temp { font-size: 40px; font-weight: 900; color: #ffffff; }
.track-title { font-size: 17px; font-weight: 900; color: #ffffff; }
.track-title-big { font-size: 24px; font-weight: 900; color: #ffffff; }
.metric-value { font-size: 18px; font-weight: 900; color: #ffffff; }

.album-frame {
    background: rgba(18, 14, 24, 0.98);
    border: 1px solid rgba(255, 255, 255, 0.13);
    border-radius: 18px;
    padding: 0px;
}

.icon-button {
    min-width: 34px;
    min-height: 34px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.14);
    color: #ffffff;
    font-size: 14px;
    font-weight: 900;
}

.icon-button:hover { background: rgba(255, 116, 214, 0.26); border-color: rgba(255, 164, 232, 0.50); }

.play-button {
    min-width: 44px;
    min-height: 44px;
    border-radius: 999px;
    background: linear-gradient(135deg, rgba(255, 94, 202, 0.52), rgba(171, 139, 255, 0.42));
    border: 1px solid rgba(255, 210, 245, 0.68);
    color: #ffffff;
    font-size: 15px;
    font-weight: 900;
}

.close-button {
    min-width: 34px;
    min-height: 34px;
    border-radius: 999px;
    background: rgba(255, 116, 160, 0.18);
    border: 1px solid rgba(255, 116, 160, 0.40);
    color: #ff9cb6;
    font-weight: 900;
}
.close-button:hover { background: rgba(255, 116, 160, 0.32); color: #ffffff; }

scale trough { min-height: 8px; border-radius: 99px; background: rgba(255, 255, 255, 0.16); }
scale highlight { border-radius: 99px; background: linear-gradient(90deg, #ff74d6, #ab8bff); }
scale slider { min-width: 16px; min-height: 16px; border-radius: 99px; background: #ffffff; border: 2px solid rgba(255, 164, 232, 0.70); }

.calendar-title { color: #ffffff; font-size: 15px; font-weight: 900; }
.calendar-weekday { color: #ffb8ea; font-size: 11px; font-weight: 900; }
.calendar-day { min-width: 38px; min-height: 31px; border-radius: 11px; color: rgba(244, 234, 255, 0.82); font-weight: 800; }
.calendar-day-muted { color: rgba(244, 234, 255, 0.28); }
.calendar-day-today { min-width: 38px; min-height: 31px; border-radius: 11px; background: rgba(255, 116, 214, 0.34); color: #ffffff; font-weight: 900; border: 1px solid rgba(255, 196, 242, 0.76); }

.weather-day { font-size: 12px; font-weight: 800; }
"""

Dashboard = base.Dashboard
GtkLayerShell = base.GtkLayerShell
HAS_LAYER_SHELL = base.HAS_LAYER_SHELL
PANEL_HEIGHT = base.PANEL_HEIGHT
PANEL_WIDTH = base.PANEL_WIDTH
TOP_MARGIN = base.TOP_MARGIN


def show_overlay(self):
    self.show_all()
    if HAS_LAYER_SHELL:
        self.anim_margin = -PANEL_HEIGHT
        GLib.timeout_add(12, self.animate_layer)
        return
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


def label(self, text, css=None, xalign=0):
    widget = Gtk.Label(label=text, xalign=xalign)
    widget.set_line_wrap(False)
    widget.set_ellipsize(Pango.EllipsizeMode.END)
    widget.set_max_width_chars(34)
    widget.set_width_chars(1)
    if css:
        widget.get_style_context().add_class(css)
    return widget


def multiline_label(self, text, css=None, xalign=0):
    widget = Gtk.Label(label=text, xalign=xalign)
    widget.set_line_wrap(True)
    widget.set_max_width_chars(42)
    if css:
        widget.get_style_context().add_class(css)
    return widget


def build_header(self, panel):
    header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    panel.pack_start(header, False, False, 0)
    title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    header.pack_start(title_box, True, True, 0)
    title_box.pack_start(self.label("Dashboard", "header-title"), False, False, 0)
    title_box.pack_start(self.label("music · weather · calendar · monitor", "header-subtitle"), False, False, 0)
    tab_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
    tab_box.get_style_context().add_class("tabs")
    header.pack_start(tab_box, False, False, 0)
    for idx, text in enumerate(["Home", "Music", "Stats", "Weather"]):
        button = Gtk.Button(label=text)
        button.connect("clicked", lambda _b, i=idx: self.set_tab(i))
        self.tabs.append(button)
        tab_box.pack_start(button, False, False, 0)
    close = Gtk.Button(label="×")
    close.get_style_context().add_class("close-button")
    close.connect("clicked", lambda *_: Gtk.main_quit())
    header.pack_end(close, False, False, 0)


def build_main_page(self):
    page = self.add_page(0)
    left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    middle = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    page.pack_start(left, True, True, 0)
    page.pack_start(middle, True, True, 0)
    page.pack_start(right, False, False, 0)

    weather = self.card("card-accent")
    weather.set_size_request(320, 124)
    weather.pack_start(self.label("Kyiv weather", "section-title"), False, False, 0)
    self.home_weather = self.label("--°C", "big-temp")
    self.home_weather_sub = self.label("loading…", "muted")
    weather.pack_start(self.home_weather, False, False, 0)
    weather.pack_start(self.home_weather_sub, False, False, 0)
    left.pack_start(weather, False, False, 0)
    self.build_media_card(left, small=True)

    clock = self.card("card-accent")
    clock.set_size_request(320, 112)
    clock.pack_start(self.label("Time", "section-title"), False, False, 0)
    self.time_label = self.label("--:--", "big-time", 0.5)
    self.date_label = self.label("", "muted", 0.5)
    clock.pack_start(self.time_label, False, False, 0)
    clock.pack_start(self.date_label, False, False, 0)
    middle.pack_start(clock, False, False, 0)

    calendar_card = self.card("card-soft")
    calendar_card.set_size_request(320, 372)
    self.calendar_title = self.label("Calendar", "calendar-title", 0.5)
    calendar_card.pack_start(self.calendar_title, False, False, 0)
    self.calendar_grid = Gtk.Grid(row_spacing=7, column_spacing=6)
    self.calendar_grid.set_halign(Gtk.Align.CENTER)
    self.calendar_grid.set_valign(Gtk.Align.CENTER)
    calendar_card.pack_start(self.calendar_grid, True, True, 0)
    middle.pack_start(calendar_card, True, True, 0)

    profile = self.card("card-soft")
    profile.set_size_request(178, 184)
    profile.pack_start(self.avatar(104), False, False, 0)
    profile.pack_start(self.label(os.environ.get("USER", "user"), "track-title", 0.5), False, False, 0)
    profile.pack_start(self.label("Arch · Hyprland", "muted", 0.5), False, False, 0)
    right.pack_start(profile, False, False, 0)

    mini_weather = self.card("card-accent")
    mini_weather.set_size_request(178, 142)
    mini_weather.pack_start(self.label("Today", "section-title"), False, False, 0)
    self.quick_weather = self.label("--", "metric-value")
    self.quick_sun = self.label("sunrise / sunset", "muted")
    mini_weather.pack_start(self.quick_weather, False, False, 0)
    mini_weather.pack_start(self.quick_sun, False, False, 0)
    right.pack_start(mini_weather, False, False, 0)

    now_card = self.card("card")
    now_card.set_size_request(178, -1)
    now_card.pack_start(self.label("Now", "section-title"), False, False, 0)
    self.quick_track = self.label("No track", "muted")
    now_card.pack_start(self.quick_track, True, True, 0)
    right.pack_start(now_card, True, True, 0)


def build_media_card(self, parent, small):
    card = self.card("card-soft")
    parent.pack_start(card, True, True, 0)
    card.pack_start(self.label("Active track", "section-title"), False, False, 0)
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    card.pack_start(row, False, False, 0)
    album_frame = Gtk.Box()
    album_frame.get_style_context().add_class("album-frame")
    frame_size = 104 if small else 268
    album_frame.set_size_request(frame_size, frame_size)
    image = Gtk.Image()
    image.set_pixel_size(frame_size)
    album_frame.pack_start(image, True, True, 0)
    row.pack_start(album_frame, False, False, 0)
    info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    info.set_size_request(180 if small else 500, -1)
    row.pack_start(info, True, True, 0)
    title = self.label("No active track", "track-title" if small else "track-title-big")
    title.set_max_width_chars(28 if small else 48)
    artist = self.label("", "muted")
    artist.set_max_width_chars(28 if small else 48)
    info.pack_start(title, False, False, 0)
    info.pack_start(artist, False, False, 0)
    controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=9)
    info.pack_start(controls, False, False, 0)
    prev_btn = Gtk.Button(label="Prev")
    prev_btn.get_style_context().add_class("icon-button")
    prev_btn.connect("clicked", lambda *_: subprocess.Popen("playerctl previous", shell=True))
    play_btn = Gtk.Button(label="Play")
    play_btn.get_style_context().add_class("play-button")
    play_btn.connect("clicked", lambda *_: subprocess.Popen("playerctl play-pause", shell=True))
    next_btn = Gtk.Button(label="Next")
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
        self.volume.set_size_request(180, -1)
        self.volume.connect("value-changed", self.on_volume_changed)
        info.pack_start(self.volume, False, False, 0)
    else:
        self.big_album = image
        self.big_track_title = title
        self.big_track_artist = artist
        self.big_play_button = play_btn


old_tick_media = Dashboard.tick_media
old_apply_weather = Dashboard.apply_weather


def tick_media(self):
    result = old_tick_media(self)
    if hasattr(self, "quick_track"):
        title = self.track_title.get_text() if hasattr(self, "track_title") else "No track"
        self.quick_track.set_text(title)
    for btn in [getattr(self, "play_button", None), getattr(self, "big_play_button", None)]:
        if btn:
            label = btn.get_label()
            if label == "":
                btn.set_label("Pause")
            elif label == "":
                btn.set_label("Play")
    return result


def apply_weather(self, data):
    result = old_apply_weather(self, data)
    if data and hasattr(self, "quick_weather"):
        current = data.get("current", {})
        daily = data.get("daily", {})
        temp = current.get("temperature_2m", 0)
        hum = current.get("relative_humidity_2m", 0)
        wind = current.get("wind_speed_10m", 0)
        sunrise = daily.get("sunrise", [""])[0][-5:]
        sunset = daily.get("sunset", [""])[0][-5:]
        self.quick_weather.set_text(f"{temp:.0f}°C · {hum}%")
        self.quick_sun.set_text(f"wind {wind} km/h\n{sunrise} / {sunset}")
    return result


Dashboard.show_overlay = show_overlay
Dashboard.animate_layer = animate_layer
Dashboard.animate_window = animate_window
Dashboard.on_key = on_key
Dashboard.label = label
Dashboard.multiline_label = multiline_label
Dashboard.build_header = build_header
Dashboard.build_main_page = build_main_page
Dashboard.build_media_card = build_media_card
Dashboard.tick_media = tick_media
Dashboard.apply_weather = apply_weather


if __name__ == "__main__":
    Dashboard().show_overlay()
    Gtk.main()
