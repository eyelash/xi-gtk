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

	public override void startup() {
		base.startup();
		core_connection = new CoreConnection({"./xi-core"});
		core_connection.update_received.connect(handle_update);
		tabs = new HashTable<string, EditView>(str_hash, str_equal);
		var window = new Gtk.ApplicationWindow(this);
		window.set_default_size(400, 400);
		notebook = new Gtk.Notebook();
		window.add(notebook);
		window.show_all();
	}

	public override void activate() {
		core_connection.send_new_tab((result) => {
			stdout.printf("new_tab response\n");
			var tab = result.get_string();
			var edit_view = new EditView(tab, core_connection);
			tabs[tab] = edit_view;
			notebook.append_page(edit_view, new Gtk.Label(tab));
			notebook.show_all();
		});
	}

	public override void open(File[] files, string hint) {
		foreach (var file in files) {
			core_connection.send_new_tab((result) => {
				var tab = result.get_string();
				var edit_view = new EditView(tab, core_connection);
				tabs[tab] = edit_view;
				notebook.append_page(edit_view, new Gtk.Label(tab));
				notebook.show_all();
				this.core_connection.send_open(tab, file.get_path());
			});
		}
	}

	public static int main(string[] args) {
		var app = new Application();
		return app.run(args);
	}
}

}
