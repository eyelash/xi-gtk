project('xi-gtk', 'vala', 'c', meson_version: '>= 0.37.0')

sources = [
	'src/Application.vala',
	'src/Blinker.vala',
	'src/CoreConnection.vala',
	'src/EditView.vala',
	'src/EditViewContainer.vala',
	'src/FindBar.vala',
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
	dependency('gtk+-3.0', version: '>= 3.20.0'),
	dependency('json-glib-1.0'),
	dependency('gio-unix-2.0'),
	meson.get_compiler('c').find_library('m')
]

config = configuration_data()
config.set_quoted('PLUGIN_DIR', join_paths(get_option('prefix'), get_option('datadir'), 'xi-gtk', 'plugins'))
configure_file(configuration: config, output: 'config.h')
dependencies += meson.get_compiler('vala').find_library('config', dirs: meson.current_source_dir())

sources += import('gnome').compile_resources('resources', 'resources/gresource.xml', source_dir: 'resources')
executable('xi-gtk', sources, dependencies: dependencies, install: true)
configuration = configuration_data()
configuration.set('bindir', join_paths(get_option('prefix'), get_option('bindir')))
install_data('com.github.eyelash.xi-gtk.desktop', install_dir: join_paths(get_option('datadir'), 'applications'))
configure_file(input: 'com.github.eyelash.xi-gtk.service.in', output: 'com.github.eyelash.xi-gtk.service', configuration: configuration, install_dir: join_paths(get_option('datadir'), 'dbus-1', 'services'))
