version       = "0.1.0"
author        = "levovix0"
description   = "Lightweight IDE"
license       = "MIT"
srcDir        = "src"
bin           = @["folx"]

requires "nim >= 1.4.8"
requires "https://github.com/treeform/windy", "boxy", "opengl", "pixie"
