<p>
  <h3>Folx: lightweght text editor with syntax highlighting for Nim</h3>
</p>

![Screenshot](https://ie.wampi.ru/2022/04/21/41cfc2c0b351d171e.png)
<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/Version-0.1-x.svg?style=flat-square&logoColor=white&color=blue">
  &nbsp;&nbsp;
  <img alt="Nim" src="https://img.shields.io/badge/Nim-Nim.svg?style=flat-square&logo=nim&logoColor=white&color=cb9e50">
  &nbsp;&nbsp;
  <img alt="Code size" src="https://img.shields.io/github/languages/code-size/FolxTeam/folx?style=flat-square">
  <img alt="Total lines" src="https://img.shields.io/tokei/lines/github/FolxTeam/folx?color=purple&style=flat-square">
</p>

## Installation
Download binaries on [GitHub releases](https://github.com/FolxTeam/folx/releases) or build from source code:
```sh
nimble install https://github.com/FolxTeam/folx
```
<details><summary>Compile flags (write it after <code>nimble</code> but before <code>install</code>)</summary><p>
  <code>-u:useMalloc</code> - use nim <code>alloc</code> instead of c <code>malloc</code>
</p></details>

### Flatpak (from source code)
to build
```sh
flatpak-builder --user --install --force-clean build-flatpak org.FolxTeam.folx.yml
```
to run
```sh
flatpak run org.FolxTeam.folx
```
todo: add folx to flathub repos

todo:
- make folx more lightweight
- add text selection
- make folx self-contained
