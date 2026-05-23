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

HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "hypr-dashboard"
CACHE.mkdir(parents=True, exist_ok=True)
AVATAR = HOME / ".face"
WEATHER_CACHE = CACHE / "weather-kyiv-7d.json"

CSS = b"""
* { font-family: "JetBrainsMono Nerd Font", "Noto Color Emoji", sans-serif; color: #cdd6f4; }
window { background: transparent; }
.root { background: rgba(12,14,20,0.92); border: 1px solid rgba(137,180,250,0.32); border-radius: 24px; padding: 16px; }
.title { font-size: 22px; font-weight: 900; color: #fff; }
.sub { color: #8f9bb3; font-size: 12px; }
.card { background: rgba(255,255,255,0.055); border: 1px solid rgba(255,255,255,0.08); border-radius: 18px; padding: 13px; }
.card-today { background: rgba(137,180,250,0.20); border: 2px solid rgba(137,180,250,0.70); border-radius: 18px; padding: 13px; }
.metric { color: #89b4fa; font-weight: 800; }
.big-time { font-size: 44px; font-weight: 900; color: #fff; }
.big-temp { font-size: 38px; font-weight: 900; color: #fff; }
.track-title { font-size: 18px; font-weight: 900; color: #fff; }
.muted { color: #a6adc8; }
button { background: rgba(137,180,250,0.16); border: 1px solid rgba(137,180,250,0.30); border-radius: 14px; padding: 8px 12px; color: #fff; }
button:hover { background: rgba(137,180,250,0.28); }
scale trough { min-height: 8px; border-radius: 8px; background: rgba(255,255,255,0.12); }
scale highlight { border-radius: 8px; background: #89b4fa; }
scale slider { min-width: 16px; min-height: 16px; border-radius: 99px; background: #fff; }
.calendar { font-family: "JetBrainsMono Nerd Font", monospace; font-size: 13px; }
.cat { font-family: "JetBrainsMono Nerd Font", monospace; font-size: 18px; color: #fff; }
"""

CAT = [r""" /\_/\\
( o.o )
 > ^ <""", r""" /\_/\\
( -.- )
 > ^ <""", r""" /\_/\\
( o.o )っ
 > ^ <""", r""" /\_/\\
( =^.^= )
  /   \\"""]


def run(cmd, shell=False, timeout=2):
    try:
        return subprocess.run(cmd, shell=shell, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout).stdout.strip()
    except Exception:
        return ""


def has(cmd): return shutil.which(cmd) is not None

def clamp(v, a=0, b=100): return max(a, min(b, v))

class Graph(Gtk.DrawingArea):
    def __init__(self):
        super().__init__(); self.values=[]; self.set_size_request(260,82); self.connect("draw", self.draw)
    def push(self,v): self.values=(self.values+[float(clamp(v))])[-60:]; self.queue_draw()
    def draw(self,wid,cr):
        w,h=self.get_allocated_width(),self.get_allocated_height(); cr.set_source_rgba(1,1,1,.06); cr.rectangle(0,0,w,h); cr.fill()
        if len(self.values)<2: return False
        cr.set_line_width(2); cr.set_source_rgba(.54,.71,.98,.95); step=w/59
        for i,v in enumerate(self.values):
            x=(60-len(self.values)+i)*step; y=h-(v/100)*h
            cr.move_to(x,y) if i==0 else cr.line_to(x,y)
        cr.stroke(); return False

class Dash(Gtk.Window):
    def __init__(self):
        super().__init__(title="Dashboard"); self.set_decorated(False); self.set_keep_above(True); self.set_skip_taskbar_hint(True); self.set_default_size(980,640)
        self.connect("destroy", Gtk.main_quit); self.connect("key-press-event", self.on_key)
        css=Gtk.CssProvider(); css.load_from_data(CSS); Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.last_cpu=None; self.last_net=None; self.media_sink=None; self.vol_guard=False; self.cat_i=0
        root=Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12); root.get_style_context().add_class("root"); self.add(root)
        head=Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12); root.pack_start(head, False, False, 0)
        names=Gtk.Box(orientation=Gtk.Orientation.VERTICAL); head.pack_start(names, True, True, 0)
        t=Gtk.Label(label="󰕮 Dashboard", xalign=0); t.get_style_context().add_class("title"); names.pack_start(t,False,False,0)
        s=Gtk.Label(label="music · weather · calendar · system monitor", xalign=0); s.get_style_context().add_class("sub"); names.pack_start(s,False,False,0)
        close=Gtk.Button(label="✕"); close.connect("clicked", lambda *_: Gtk.main_quit()); head.pack_end(close,False,False,0)
        self.nb=Gtk.Notebook(); root.pack_start(self.nb, True, True, 0)
        self.build_tab1(); self.build_tab2(); self.build_tab3(); self.build_tab4()
        GLib.timeout_add_seconds(1,self.tick_clock); GLib.timeout_add_seconds(2,self.tick_media); GLib.timeout_add_seconds(2,self.tick_stats); GLib.timeout_add_seconds(900,self.tick_weather); GLib.timeout_add(420,self.tick_cat)
        self.tick_clock(); self.tick_media(); self.tick_stats(); self.tick_weather()
    def show_drop(self):
        self.show_all(); scr=Gdk.Screen.get_default(); g=scr.get_monitor_geometry(scr.get_primary_monitor()); w,h=self.get_size(); x=g.x+(g.width-w)//2; self.move(x,g.y-h); self.ax=g.y-h; self.ty=g.y+38; GLib.timeout_add(12,self.anim)
    def anim(self):
        self.ax += max(8,int((self.ty-self.ax)*.22)); self.move(self.get_position()[0], self.ax)
        return self.ax < self.ty
    def card(self,today=False):
        b=Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8); b.get_style_context().add_class("card-today" if today else "card"); return b
    def tab(self,name):
        p=Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12); p.set_border_width(4); self.nb.append_page(p, Gtk.Label(label=name)); return p
    def avatar(self,size):
        img=Gtk.Image();
        if AVATAR.exists():
            try: img.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(str(AVATAR), size, size, True)); return img
            except Exception: pass
        img.set_from_icon_name("avatar-default", Gtk.IconSize.DIALOG); return img
    def build_tab1(self):
        p=self.tab("󰃭 Main"); left=Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12); right=Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12); p.pack_start(left,True,True,0); p.pack_start(right,False,False,0)
        w=self.card(); w.pack_start(Gtk.Label(label="󰖕 Kyiv weather", xalign=0),False,False,0); self.home_weather=Gtk.Label(label="--°C", xalign=0); self.home_weather.get_style_context().add_class("big-temp"); self.home_weather_sub=Gtk.Label(label="", xalign=0); w.pack_start(self.home_weather,False,False,0); w.pack_start(self.home_weather_sub,False,False,0); left.pack_start(w,False,False,0)
        self.media_card(left, small=True)
        prof=self.card(); prof.pack_start(self.avatar(112),False,False,0); prof.pack_start(Gtk.Label(label=os.environ.get("USER","user")),False,False,0); right.pack_start(prof,False,False,0)
        c=self.card(); self.time=Gtk.Label(label="--:--"); self.time.get_style_context().add_class("big-time"); self.date=Gtk.Label(label=""); self.cal=Gtk.Label(label=""); self.cal.get_style_context().add_class("calendar"); c.pack_start(self.time,False,False,0); c.pack_start(self.date,False,False,0); c.pack_start(self.cal,False,False,0); right.pack_start(c,True,True,0)
    def media_card(self,parent,small=False):
        m=self.card(); parent.pack_start(m,True,True,0); m.pack_start(Gtk.Label(label=" Active track", xalign=0),False,False,0)
        row=Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12); m.pack_start(row,False,False,0); img=Gtk.Image(); img.set_pixel_size(88 if small else 230); row.pack_start(img,False,False,0)
        box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=7); row.pack_start(box,True,True,0); title=Gtk.Label(label="No active track", xalign=0); title.get_style_context().add_class("track-title"); artist=Gtk.Label(label="", xalign=0); artist.get_style_context().add_class("muted"); box.pack_start(title,False,False,0); box.pack_start(artist,False,False,0)
        ctr=Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8); box.pack_start(ctr,False,False,0)
        for label,cmd in [("󰒮","playerctl previous"),("⏯","playerctl play-pause"),("󰒭","playerctl next")]:
            b=Gtk.Button(label=label); b.connect("clicked", lambda _b,c=cmd: subprocess.Popen(c, shell=True)); ctr.pack_start(b,False,False,0)
        if small:
            self.album=img; self.track=title; self.artist=artist; self.vol_label=Gtk.Label(label="App volume",xalign=0); box.pack_start(self.vol_label,False,False,0); self.vol=Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL,0,150,1); self.vol.connect("value-changed",self.on_vol); box.pack_start(self.vol,False,False,0)
        else:
            self.big_album=img; self.big_track=title; self.big_artist=artist
    def build_tab2(self):
        p=self.tab(" Media"); left=Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12); right=self.card(); p.pack_start(left,True,True,0); p.pack_start(right,False,False,0); self.media_card(left, small=False); right.pack_start(self.avatar(120),False,False,0); self.cat=Gtk.Label(label=CAT[0]); self.cat.get_style_context().add_class("cat"); right.pack_start(self.cat,True,True,0)
    def build_tab3(self):
        p=Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12); p.set_border_width(4); self.nb.append_page(p,Gtk.Label(label="󰍛 Stats")); grid=Gtk.Grid(column_spacing=12,row_spacing=12); p.pack_start(grid,False,False,0)
        self.cpu=self.metric(grid,0,0,"CPU"); self.gpu=self.metric(grid,1,0,"GPU"); self.ram=self.metric(grid,2,0,"RAM"); self.disk=self.metric(grid,0,1,"Disk"); self.net=self.metric(grid,1,1,"Network"); self.ip=self.metric(grid,2,1,"IP")
        gr=Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12); p.pack_start(gr,True,True,0); self.cpu_g=Graph(); self.gpu_g=Graph(); self.net_g=Graph()
        for name,g in [("CPU graph",self.cpu_g),("GPU graph",self.gpu_g),("Internet graph",self.net_g)]: c=self.card(); c.pack_start(Gtk.Label(label=name,xalign=0),False,False,0); c.pack_start(g,True,True,0); gr.pack_start(c,True,True,0)
    def metric(self,grid,x,y,name):
        c=self.card(); l=Gtk.Label(label=name,xalign=0); l.get_style_context().add_class("metric"); v=Gtk.Label(label="--",xalign=0); c.pack_start(l,False,False,0); c.pack_start(v,False,False,0); grid.attach(c,x,y,1,1); return v
    def build_tab4(self):
        p=Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12); p.set_border_width(4); self.nb.append_page(p,Gtk.Label(label="󰖕 Weather 7d")); h=self.card(); self.w_head=Gtk.Label(label="Kyiv weather",xalign=0); self.w_head.get_style_context().add_class("big-temp"); self.sun=Gtk.Label(label="",xalign=0); h.pack_start(self.w_head,False,False,0); h.pack_start(self.sun,False,False,0); p.pack_start(h,False,False,0); self.days=Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8); p.pack_start(self.days,True,True,0)
    def on_key(self,_w,e):
        if Gdk.keyval_name(e.keyval)=="Escape": Gtk.main_quit(); return True
        return False
    def tick_clock(self):
        n=dt.datetime.now(); self.time.set_text(n.strftime("%H:%M")); self.date.set_text(n.strftime("%A, %d.%m.%Y")); self.cal.set_text(calendar.month(n.year,n.month)); return True
    def set_art(self,url,img,size):
        if not url: img.set_from_icon_name("audio-x-generic",Gtk.IconSize.DIALOG); return
        path=None
        if url.startswith("file://"): path=Path(urllib.request.url2pathname(url[7:]))
        if path and path.exists():
            try: img.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(str(path),size,size,True)); return
            except Exception: pass
        img.set_from_icon_name("audio-x-generic",Gtk.IconSize.DIALOG)
    def tick_media(self):
        if not has("playerctl"): return True
        title=run(["playerctl","metadata","title"]); artist=run(["playerctl","metadata","artist"]); art=run(["playerctl","metadata","mpris:artUrl"]); player=run(["playerctl","metadata","--format","{{playerName}}"])
        if not title: title="No active track"; artist=""
        for l in [self.track,self.big_track]: l.set_text(title)
        for l in [self.artist,self.big_artist]: l.set_text(artist)
        self.set_art(art,self.album,88); self.set_art(art,self.big_album,230); self.find_sink(player); return True
    def find_sink(self,player):
        if not has("pactl"): return
        data=run(["pactl","list","sink-inputs"]); blocks=re.split(r"Sink Input #",data)[1:]
        for b in blocks:
            sid=b.splitlines()[0].strip(); vol=re.search(r"Volume:.*?(\d+)%",b); text=b.lower()
            if (player and player.lower() in text) or self.media_sink is None:
                self.media_sink=sid; v=int(vol.group(1)) if vol else 100; self.vol_guard=True; self.vol.set_value(v); self.vol_guard=False; self.vol_label.set_text(f"App volume: {v}%"); return
    def on_vol(self,scale):
        if self.vol_guard or not self.media_sink: return
        v=int(scale.get_value()); subprocess.Popen(["pactl","set-sink-input-volume",self.media_sink,f"{v}%"]); self.vol_label.set_text(f"App volume: {v}%")
    def cpu_use(self):
        p=[int(x) for x in Path("/proc/stat").read_text().splitlines()[0].split()[1:]]; idle=p[3]+p[4]; total=sum(p)
        if not self.last_cpu: self.last_cpu=(total,idle); return 0
        pt,pi=self.last_cpu; self.last_cpu=(total,idle); return 100*(1-(idle-pi)/max(1,total-pt))
    def temp(self):
        vals=[]
        for p in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
            try: vals.append(int(p.read_text())/1000)
            except Exception: pass
        vals=[v for v in vals if 20<=v<=120]; return max(vals) if vals else None
    def gpu_use(self):
        if has("nvidia-smi"):
            o=run(["nvidia-smi","--query-gpu=utilization.gpu,temperature.gpu","--format=csv,noheader,nounits"])
            try: u,t=[float(x.strip()) for x in o.splitlines()[0].split(",")[:2]]; return u,t
            except Exception: pass
        return 0,None
    def tick_stats(self):
        c=self.cpu_use(); ct=self.temp(); g,gt=self.gpu_use(); mem={}
        for line in Path("/proc/meminfo").read_text().splitlines(): k,v=line.split(":",1); mem[k]=int(v.strip().split()[0])
        ram=100*(1-mem.get("MemAvailable",0)/mem.get("MemTotal",1)); du=shutil.disk_usage("/"); disk=du.used/du.total*100
        rx=tx=0
        for line in Path("/proc/net/dev").read_text().splitlines()[2:]:
            iface,rest=line.split(":",1); nums=rest.split()
            if iface.strip()!="lo": rx+=int(nums[0]); tx+=int(nums[8])
        now=time.time(); netp=0; nr=nt=0
        if self.last_net:
            lr,lt,tm=self.last_net; d=max(.1,now-tm); nr=(rx-lr)/d; nt=(tx-lt)/d; netp=min(100,(nr+nt)/1024/1024*10)
        self.last_net=(rx,tx,now)
        self.cpu.set_text(f"{c:.0f}%"+(f" · {ct:.0f}°C" if ct else "")); self.gpu.set_text(f"{g:.0f}%"+(f" · {gt:.0f}°C" if gt else "")); self.ram.set_text(f"{ram:.0f}%"); self.disk.set_text(f"{disk:.0f}%"); self.net.set_text(f"↓ {nr/1024:.0f} KiB/s ↑ {nt/1024:.0f} KiB/s"); self.ip.set_text(run("ip -4 addr show scope global | awk '/inet / {print $2, $NF; exit}'",shell=True) or socket.gethostbyname(socket.gethostname()))
        self.cpu_g.push(c); self.gpu_g.push(g); self.net_g.push(netp); return True
    def tick_weather(self):
        def worker():
            url="https://api.open-meteo.com/v1/forecast?latitude=50.4501&longitude=30.5234&current=temperature_2m,relative_humidity_2m,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,relative_humidity_2m_mean,wind_speed_10m_max,sunrise,sunset&timezone=Europe%2FKyiv&forecast_days=7"
            data=None
            try:
                data=json.loads(urllib.request.urlopen(url,timeout=5).read().decode()); WEATHER_CACHE.write_text(json.dumps(data))
            except Exception:
                if WEATHER_CACHE.exists(): data=json.loads(WEATHER_CACHE.read_text())
            GLib.idle_add(lambda: self.apply_weather(data))
        threading.Thread(target=worker,daemon=True).start(); return True
    def apply_weather(self,data):
        if not data: return False
        cur=data.get("current",{}); daily=data.get("daily",{}); temp=cur.get("temperature_2m",0); hum=cur.get("relative_humidity_2m",0); wind=cur.get("wind_speed_10m",0)
        self.home_weather.set_text(f"{temp:.0f}°C"); self.home_weather_sub.set_text(f"Kyiv · humidity {hum}% · wind {wind} km/h"); self.w_head.set_text(f"Kyiv · {temp:.0f}°C")
        sr0=daily.get("sunrise",[""])[0][-5:]; ss0=daily.get("sunset",[""])[0][-5:]; self.sun.set_text(f"Today: sunrise {sr0} · sunset {ss0} · humidity {hum}% · wind {wind} km/h")
        for ch in self.days.get_children(): self.days.remove(ch)
        today=dt.date.today().isoformat(); times=daily.get("time",[])[:7]
        for i,day in enumerate(times):
            is_today=(day==today); c=self.card(is_today); d=dt.datetime.strptime(day,"%Y-%m-%d"); name=("Today" if is_today else d.strftime("%a"))+d.strftime(" %d.%m")
            tmax=daily["temperature_2m_max"][i]; tmin=daily["temperature_2m_min"][i]; h=daily["relative_humidity_2m_mean"][i]; w=daily["wind_speed_10m_max"][i]; sr=daily["sunrise"][i][-5:]; ss=daily["sunset"][i][-5:]
            lab=Gtk.Label(label=f"{name}\n{tmin:.0f}° / {tmax:.0f}°\n󰖎 {h:.0f}%\n󰖝 {w:.0f} km/h\n󰖜 {sr}\n󰖛 {ss}",xalign=0); lab.get_style_context().add_class("metric"); c.pack_start(lab,True,True,0); self.days.pack_start(c,True,True,0)
        self.days.show_all(); return False
    def tick_cat(self): self.cat_i=(self.cat_i+1)%len(CAT); self.cat.set_text(CAT[self.cat_i]); return True

if __name__=="__main__":
    Dash().show_drop(); Gtk.main()
