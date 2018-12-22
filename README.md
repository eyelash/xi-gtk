# xi-gtk

a GTK+ front-end for the [Xi editor](https://github.com/xi-editor/xi-editor)

![screenshot](https://raw.githubusercontent.com/eyelash/xi-gtk/master/screenshot.png)

## Instructions

We recommend to use flatpak-builder for building xi-gtk.
To get started, make sure you have flatpak-builder installed and the flathub repo configured correctly.

```sh
# add the flathub repo
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

Once you are ready, you can build and install xi-gtk with a single command.

```sh
flatpak-builder --from-git=https://github.com/eyelash/xi-gtk.git --install-deps-from=flathub --install ~/.xi-gtk-build flatpak.json
```

Finally, you can run xi-gtk.

```sh
flatpak run com.github.eyelash.xi-gtk
```

## Roadmap

- [x] mouse input and selections
- [x] saving
- [x] follow the cursor (respect the `scrollto` parameter)
- [x] undo / redo
- [x] copy / paste
- [x] line numbers
- [x] find / replace
- [ ] command palette
- [ ] i18n
- [ ] preferences (font family, font size, etc.)
