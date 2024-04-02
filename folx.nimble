import os

version       = "0.1"
author        = "FolxTeam"
description   = "Lightweight IDE / text editor"
license       = "MIT"
srcDir        = "src"
bin           = @["folx"]

requires "nim >= 2.0.2"
requires "siwin ^= 0.8.4.6", "jsony", "pixie", "fusion", "winim"
requires "cligen"


let dataDir =
  when defined(linux): getHomeDir()/".local"/"share"/"folx"
  elif defined(windows): getHomeDir()/"AppData"/"Roaming"/"folx"
  else: "."


before install:
  echo "installing resources..."
  mkdir dataDir
  cpdir "resources", dataDir/"resources"


task buildWindows, "cross-compile from Linux to Windows":
  exec "nim cpp -d:mingw --os:windows --cc:gcc --gcc.exe:/usr/bin/x86_64-w64-mingw32-gcc --gcc.linkerexe:/usr/bin/x86_64-w64-mingw32-gcc -o:build-windows/folx.exe src/folx.nim"
