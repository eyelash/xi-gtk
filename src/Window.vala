// Copyright 2017-2018 Elias Aebi
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
	private CoreConnection core_connection;
	private Xi.Notebook notebook;
	private Gtk.FileChooserNative dialog;

	public Window(Gtk.Application application, CoreConnection core_connection) {
		Object(application: application);
		this.core_connection = core_connection;

		set_default_size(800, 550);

		// actions
		var new_tab_action = new SimpleAction("new-tab", null);
		new_tab_action.activate.connect(() => {
			add_new_tab();
		});
		add_action(new_tab_action);
		var open_action = new SimpleAction("open", null);
		open_action.activate.connect(open);
		add_action(open_action);
		var save_action = new SimpleAction("save", null);
		save_action.activate.connect(save);
		add_action(save_action);
		var save_as_action = new SimpleAction("save-as", null);
		save_as_action.activate.connect(save_as);
		add_action(save_as_action);
		var find_action = new SimpleAction("find", null);
		find_action.activate.connect(() => {
			notebook.get_current_edit_view().show_find_bar();
		});
		add_action(find_action);

		var header_bar = new Gtk.HeaderBar();
		header_bar.show_close_button = true;
		header_bar.title = "Xi";
		var new_button = new Gtk.Button.from_icon_name("document-new-symbolic", Gtk.IconSize.BUTTON);
		new_button.tooltip_text = "New File";
		new_button.action_name = "win.new-tab";
		header_bar.pack_start(new_button);
		var open_button = new Gtk.Button.from_icon_name("document-open-symbolic", Gtk.IconSize.BUTTON);
		open_button.tooltip_text = "Open File";
		open_button.action_name = "win.open";
		header_bar.pack_start(open_button);
		var save_button = new Gtk.Button.from_icon_name("document-save-symbolic", Gtk.IconSize.BUTTON);
		save_button.tooltip_text = "Save File";
		save_button.action_name = "win.save";
		header_bar.pack_end(save_button);
		set_titlebar(header_bar);

		notebook = new Xi.Notebook();
		add(notebook);
	}

	public void add_new_tab(File? file = null) {
		core_connection.send_new_view.begin(file != null ? file.get_path() : null, (obj, res) => {
			string view_id = core_connection.send_new_view.end(res);
			this.notebook.add_edit_view(core_connection, view_id, file);
		});
	}

	private void open() {
		dialog = new Gtk.FileChooserNative(null, this, Gtk.FileChooserAction.OPEN, null, null);
		dialog.select_multiple = true;
		dialog.response.connect((response) => {
			if (response == Gtk.ResponseType.ACCEPT) {
				foreach (var file in dialog.get_files()) {
					add_new_tab(file);
				}
			}
			dialog.destroy();
		});
		dialog.show();
	}

	private void save() {
		unowned EditView edit_view = notebook.get_current_edit_view().get_edit_view();
		if (!edit_view.save()) {
			save_as();
		}
	}

	private void save_as() {
		EditView edit_view = notebook.get_current_edit_view().get_edit_view();
		dialog = new Gtk.FileChooserNative(null, this, Gtk.FileChooserAction.SAVE, null, null);
		dialog.do_overwrite_confirmation = true;
		dialog.response.connect((response) => {
			if (response == Gtk.ResponseType.ACCEPT) {
				edit_view.save_as(dialog.get_file());
			}
			dialog.destroy();
		});
		dialog.show();
	}
}

}
