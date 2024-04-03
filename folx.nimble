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
requires "shady ^= 0.1.3"  # writing shaders in nim instead of glsl
requires "fusion ^= 1.2"  # pattern matching and ast dsl
requires "opengl ^= 1.2.9"


let dataDir =
  when defined(linux): getHomeDir()/".local"/"share"/"folx"
  elif defined(windows): getHomeDir()/"AppData"/"Roaming"/"folx"
  else: "."


proc installResources =
  echo "installing resources..."
  if dirExists dataDir: rmDir dataDir
  mkdir dataDir
  cpdir "resources", dataDir/"resources"


before install:
  installResources()

before build:
  installResources()


task buildWindows, "cross-compile from Linux to Windows":
  exec "nim cpp -d:mingw --os:windows --cc:gcc --gcc.exe:/usr/bin/x86_64-w64-mingw32-gcc --gcc.linkerexe:/usr/bin/x86_64-w64-mingw32-gcc -o:build-windows/folx.exe src/folx.nim"
