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

class TabLabel: Gtk.Box {
	private EditView edit_view;

	public signal void close_clicked(EditView edit_view);

	public TabLabel(EditView edit_view) {
		this.edit_view = edit_view;

		var label = new Gtk.Label(edit_view.label);
		edit_view.bind_property("label", label, "label");
		set_center_widget(label);

		var close_image = new Gtk.Image.from_icon_name("window-close-symbolic", Gtk.IconSize.MENU);
		var close_button = new Gtk.Button();
		close_button.add(close_image);
		close_button.relief = Gtk.ReliefStyle.NONE;
		close_button.focus_on_click = false;
		close_button.clicked.connect(() => close_clicked(this.edit_view));
		pack_end(close_button, false, true);

		show_all();
	}
}

class Notebook: Gtk.Notebook {

	public Notebook() {
		set_scrollable(true);
	}

	public void add_edit_view(EditView edit_view) {
		var scrolled_window = new Gtk.ScrolledWindow(null, null);
		scrolled_window.add(edit_view);
		var label = new TabLabel(edit_view);
		label.close_clicked.connect((edit_view) => {
			int index = page_num(edit_view.get_parent());
			remove_page(index);
		});
		append_page(scrolled_window, label);
		set_tab_reorderable(scrolled_window, true);
		child_set_property(scrolled_window, "tab-expand", true);
		show_all();
		set_current_page(page_num(scrolled_window));
		edit_view.grab_focus();
	}

	public unowned EditView get_current_edit_view() {
		int index = get_current_page();
		return (get_nth_page(index) as Gtk.Bin).get_child() as EditView;
	}

	public override void grab_focus() {
		get_current_edit_view().grab_focus();
	}
}

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
		core_connection.send_new_tab((result) => {
			string tab = result.get_string();
			notebook.add_edit_view(new EditView(tab, file, core_connection));
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
