#!/usr/bin/env python3
from dashboard_v5 import (
    Dashboard,
    Gdk,
    GLib,
    Gtk,
    HAS_LAYER_SHELL,
    GtkLayerShell,
    PANEL_HEIGHT,
    PANEL_WIDTH,
    TOP_MARGIN,
)


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


Dashboard.show_overlay = show_overlay
Dashboard.animate_layer = animate_layer
Dashboard.animate_window = animate_window
Dashboard.on_key = on_key


if __name__ == "__main__":
    Dashboard().show_overlay()
    Gtk.main()
