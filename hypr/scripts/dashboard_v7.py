#!/usr/bin/env python3
import dashboard_v5 as base

# GTK CSS does not accept arbitrary web font weights like 850/950.
# Normalize them before Gtk.CssProvider.load_from_data() is called.
base.CSS = (
    base.CSS
    .replace(b"font-weight: 850", b"font-weight: 800")
    .replace(b"font-weight: 950", b"font-weight: 900")
)

import dashboard_v6 as fixed


if __name__ == "__main__":
    fixed.Dashboard().show_overlay()
    fixed.Gtk.main()
