project('xi-gtk', 'vala', 'c')

sources = [
	'Application.vala',
	'Blinker.vala',
	'CoreConnection.vala',
	'EditView.vala',
	'Line.vala',
	'LinesCache.vala',
	'Notebook.vala',
	'Style.vala',
	'StyleMap.vala',
	'TabLabel.vala',
	'Utilities.vala',
]

dependencies = [
	dependency('gtk+-3.0', version: '>=3.18.0'),
	dependency('json-glib-1.0'),
	dependency('gio-unix-2.0'),
	meson.get_compiler('c').find_library('m')
]

executable('xi-gtk', sources, dependencies: dependencies, install: true)
install_data('com.github.eyelash.xi-gtk.desktop', install_dir: 'share/applications')
