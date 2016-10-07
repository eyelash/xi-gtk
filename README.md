# xi-gtk

[![Join the chat at https://gitter.im/eyelash/xi-gtk](https://badges.gitter.im/eyelash/xi-gtk.svg)](https://gitter.im/eyelash/xi-gtk)

![screenshot](https://raw.githubusercontent.com/eyelash/xi-gtk/master/screenshot.png)

## Instructions

### Install the Dependencies

```sh
# Debian/Ubuntu:
sudo apt install build-essential git cargo valac meson libgtk-3-dev libjson-glib-dev
# Arch:
sudo pacman -S git cargo vala meson
```

### Build and Install xi-core

```sh
git clone https://github.com/google/xi-editor.git
cd xi-editor/rust
cargo install
export PATH=~/.cargo/bin:$PATH
```

### Build and Install xi-gtk

```sh
git clone https://github.com/eyelash/xi-gtk.git
cd xi-gtk
mkdir build
cd build
meson ..
ninja
sudo ninja install
```

## Shortcuts

Shortcut                                         | Command
-------------------------------------------------|---------
<kbd>Control</kbd>+<kbd>N</kbd>                  | New File
<kbd>Control</kbd>+<kbd>O</kbd>                  | Open File
<kbd>Control</kbd>+<kbd>S</kbd>                  | Save
<kbd>Control</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> | Save As

## To Do

- [x] mouse input and selections
- [x] saving
- [x] follow the cursor (respect the `scrollto` parameter)
- [ ] undo / redo
- [ ] copy / paste
- [ ] i18n
- [ ] preferences (font family, font size, etc.)
