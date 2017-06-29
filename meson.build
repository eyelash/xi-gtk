project('xi-gtk', 'vala', 'c')

sources = [
	'src/Application.vala',
	'src/Blinker.vala',
	'src/CoreConnection.vala',
	'src/EditView.vala',
	'src/Line.vala',
	'src/LineCache.vala',
	'src/Notebook.vala',
	'src/Style.vala',
	'src/StyleMap.vala',
	'src/Theme.vala',
	'src/Utilities.vala',
	'src/Window.vala',
]

dependencies = [
	dependency('gtk+-3.0', version: '>=3.18.0'),
	dependency('json-glib-1.0'),
	dependency('gio-unix-2.0'),
	meson.get_compiler('c').find_library('m')
]

sources += import('gnome').compile_resources('resources', 'resources/gresource.xml', source_dir: 'resources')
executable('xi-gtk', sources, dependencies: dependencies, install: true)
install_data('com.github.eyelash.xi-gtk.desktop', install_dir: 'share/applications')
