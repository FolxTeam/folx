import os

version       = "0.1"
author        = "FolxTeam"
description   = "Lightweight IDE / text editor"
license       = "MIT"
srcDir        = "src"
bin           = @["folx"]

requires "nim >= 1.6.4"
requires "siwin", "jsony", "pixie", "cligen", "fusion", "winim"


let dataDir =
  when defined(linux): getHomeDir()/".local"/"share"/"folx"
  elif defined(windows): getHomeDir()/"AppData"/"Roaming"/"folx"
  else: "."


before install:
  echo "installing resources..."
  mkdir dataDir
  cpdir "resources", dataDir/"resources"
