// Copyright 2016-2017 Elias Aebi
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
	private Gtk.ApplicationWindow window;
	private Notebook notebook;

	public Application() {
		Object(application_id: "com.github.eyelash.xi-gtk", flags: ApplicationFlags.HANDLES_OPEN);
	}

	private delegate void ActionHandler();
	private new void add_accelerator(string action_name, string accelerator, ActionHandler callback) {
		var action = new SimpleAction(action_name, null);
		action.activate.connect(() => callback());
		window.add_action(action);
		set_accels_for_action("win."+action_name, {accelerator});
	}

	private void add_new_tab(File? file = null) {
		core_connection.send_new_view(file != null ? file.get_path() : null, (result) => {
			string view_id = result.get_string();
			notebook.add_edit_view(new EditView(view_id, file, core_connection));
		});
	}

	public override void startup() {
		base.startup();

		unowned string core_binary = GLib.Environment.get_variable("XI_CORE");
		if (core_binary == null) {
			core_binary = "xi-core";
		}

		core_connection = new CoreConnection({core_binary});
		core_connection.def_style_received.connect((style) => {
			StyleMap.get_instance().def_style(style);
		});
		window = new Gtk.ApplicationWindow(this);
		window.set_default_size(600, 400);
		add_accelerator("new", "<Control>N", () => add_new_tab());
		add_accelerator("open", "<Control>O", () => {
			var dialog = new Gtk.FileChooserDialog(null, window, Gtk.FileChooserAction.OPEN, "Cancel", Gtk.ResponseType.CANCEL, "Open", Gtk.ResponseType.ACCEPT);
			dialog.select_multiple = true;
			if (dialog.run() == Gtk.ResponseType.ACCEPT) {
				foreach (var file in dialog.get_files()) {
					add_new_tab(file);
				}
			}
			dialog.destroy();
		});
		add_accelerator("save", "<Control>S", () => notebook.get_current_edit_view().save());
		add_accelerator("save-as", "<Control><Shift>S", () => notebook.get_current_edit_view().save_as());
		add_accelerator("undo", "<Control>Z", () => notebook.get_current_edit_view().undo());
		add_accelerator("redo", "<Control>Y", () => notebook.get_current_edit_view().redo());
		add_accelerator("quit", "<Control>Q", () => window.close());
		notebook = new Notebook();
		window.add(notebook);
		window.show_all();
	}

	public override void activate() {
		add_new_tab();
	}

	public override void open(File[] files, string hint) {
		foreach (var file in files) {
			add_new_tab(file);
		}
	}

	public static int main(string[] args) {
		var app = new Application();
		return app.run(args);
	}
}

}
