// Copyright 2016 Elias Aebi
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

namespace Xi {

class Tab: Gtk.Box {
	private EditView edit_view;

	public signal void close_clicked(EditView edit_view);

	public Tab(EditView edit_view) {
		this.edit_view = edit_view;
		var label = new Gtk.Label(edit_view.label);
		edit_view.bind_property("label", label, "label");
		set_center_widget(label);
		var close_image = new Gtk.Image.from_icon_name("window-close-symbolic", Gtk.IconSize.MENU);
		var close_button = new Gtk.Button();
		close_button.add(close_image);
		close_button.clicked.connect(() => close_clicked(this.edit_view));
		pack_end(close_button, false, true);
		show_all();
	}
}

class Application: Gtk.Application {
	private CoreConnection core_connection;
	private Gtk.Notebook notebook;
	private HashTable<string, EditView> tabs;

	public Application() {
		Object(application_id: "com.github.eyelash.xi-gtk", flags: ApplicationFlags.HANDLES_OPEN);
	}

	private void handle_update(string tab, int64 first_line, int64 height, Json.Array lines, int64 scrollto_line, int64 scrollto_column) {
		var edit_view = tabs[tab];
		edit_view.update(first_line, height, lines, scrollto_line, scrollto_column);
	}

	private unowned EditView get_current_edit_view() {
		int index = notebook.get_current_page();
		return (notebook.get_nth_page(index) as Gtk.Bin).get_child() as EditView;
	}

	public override void startup() {
		base.startup();

		unowned string core_binary = GLib.Environment.get_variable("XI_CORE");
		if (core_binary == null)
			core_binary = "./xi-core";

		core_connection = new CoreConnection({core_binary});
		core_connection.update_received.connect(handle_update);
		tabs = new HashTable<string, EditView>(str_hash, str_equal);
		var window = new Gtk.ApplicationWindow(this);
		window.set_default_size(400, 400);
		var save_action = new SimpleAction("save", null);
		save_action.activate.connect(() => get_current_edit_view().save());
		window.add_action(save_action);
		const string[] accels = {"<Control>S"};
		set_accels_for_action("win.save", accels);
		notebook = new Gtk.Notebook();
		notebook.set_scrollable(true);
		window.add(notebook);
		window.show_all();
	}

	private void add_new_tab(string tab, File? file = null) {
		var edit_view = new EditView(tab, file, core_connection);
		tabs[tab] = edit_view;
		var scrolled_window = new Gtk.ScrolledWindow(null, null);
		scrolled_window.add(edit_view);
		var label = new Tab(edit_view);
		label.close_clicked.connect((edit_view) => {
			int index = notebook.page_num(edit_view.get_parent());
			notebook.remove_page(index);
			tabs.remove(edit_view.tab);
		});
		notebook.append_page(scrolled_window, label);
		notebook.set_tab_reorderable(scrolled_window, true);
		notebook.child_set_property(scrolled_window, "tab-expand", true);
		notebook.show_all();
		edit_view.grab_focus();
	}

	public override void activate() {
		core_connection.send_new_tab((result) => {
			var tab = result.get_string();
			add_new_tab(tab);
		});
	}

	public override void open(File[] files, string hint) {
		foreach (var file in files) {
			core_connection.send_new_tab((result) => {
				var tab = result.get_string();
				add_new_tab(tab, file);
			});
		}
	}

	public static int main(string[] args) {
		var app = new Application();
		return app.run(args);
	}
}

}
