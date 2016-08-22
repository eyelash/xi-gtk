project('xi-gtk', ['vala', 'c'])
sources = ['Application.vala', 'CoreConnection.vala', 'EditView.vala']
dependencies = [dependency('gtk+-3.0'), dependency('json-glib-1.0'), dependency('gio-unix-2.0'), meson.get_compiler('c').find_library('m')]
executable('xi-gtk', sources, dependencies: dependencies)
