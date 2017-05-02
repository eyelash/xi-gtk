// Copyright 2017 Elias Aebi
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

class Window: Gtk.ApplicationWindow {
	public CoreConnection core_connection { construct; get; }
	private Xi.Notebook notebook;

	public Window(Gtk.Application application, CoreConnection core_connection) {
		Object(application: application, core_connection: core_connection);
	}

	construct {
		set_default_size(600, 400);

		var accel_group = new Gtk.AccelGroup();
		accel_group.connect(Gdk.Key.N, Gdk.ModifierType.CONTROL_MASK, 0, () => {
			add_new_tab();
			return true;
		});
		accel_group.connect(Gdk.Key.O, Gdk.ModifierType.CONTROL_MASK, 0, () => {
			var dialog = new Gtk.FileChooserDialog(null, this, Gtk.FileChooserAction.OPEN, "Cancel", Gtk.ResponseType.CANCEL, "Open", Gtk.ResponseType.ACCEPT);
			dialog.select_multiple = true;
			if (dialog.run() == Gtk.ResponseType.ACCEPT) {
				foreach (var file in dialog.get_files()) {
					add_new_tab(file);
				}
			}
			dialog.destroy();
			return true;
		});
		accel_group.connect(Gdk.Key.S, Gdk.ModifierType.CONTROL_MASK, 0, () => {
			notebook.get_current_edit_view().save();
			return true;
		});
		accel_group.connect(Gdk.Key.S, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK, 0, () => {
			notebook.get_current_edit_view().save_as();
			return true;
		});
		accel_group.connect(Gdk.Key.Q, Gdk.ModifierType.CONTROL_MASK, 0, () => {
			close();
			return true;
		});
		add_accel_group(accel_group);

		notebook = new Xi.Notebook();
		add(notebook);
	}

	public void add_new_tab(File? file = null) {
		core_connection.send_new_view(file != null ? file.get_path() : null, (result) => {
			string view_id = result.get_string();
			this.notebook.add_edit_view(new EditView(view_id, file, core_connection));
		});
	}
}

}
