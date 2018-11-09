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

class FindBar: Gtk.ActionBar {
	private CoreConnection core_connection;
	private string view_id;
	private Gtk.Entry find_entry;
	private Gtk.ToggleButton case_sensitive;
	private Gtk.ToggleButton regex;
	private Gtk.ToggleButton whole_words;
	private Gtk.Entry replace_entry;

	private void find() {
		core_connection.send_find(view_id, find_entry.text, case_sensitive.active, regex.active, whole_words.active);
	}
	private void find_next() {
		core_connection.send_find_next(view_id, true, false, "set");
	}
	private void find_previous() {
		core_connection.send_find_previous(view_id, true, false, "set");
	}
	private void find_all() {
		core_connection.send_edit(view_id, "find_all");
	}
	private void replace() {
		core_connection.send_replace(view_id, replace_entry.text);
	}
	private void replace_next() {
		core_connection.send_edit(view_id, "replace_next");
	}
	private void replace_all() {
		core_connection.send_edit(view_id, "replace_all");
	}

	public FindBar(CoreConnection core_connection, string view_id) {
		this.core_connection = core_connection;
		this.view_id = view_id;

		var grid = new Gtk.Grid();
		grid.column_spacing = 6;
		grid.row_spacing = 6;
		pack_start(grid);

		find_entry = new Gtk.Entry();
		find_entry.changed.connect(find);
		find_entry.activate.connect(find_next);

		case_sensitive = new Gtk.ToggleButton.with_label("Aa");
		case_sensitive.tooltip_text = "Case Sensitive";
		case_sensitive.toggled.connect(find);

		regex = new Gtk.ToggleButton.with_label(".*");
		regex.tooltip_text = "Regular Expression";
		regex.toggled.connect(find);

		whole_words = new Gtk.ToggleButton.with_label("«»");
		whole_words.tooltip_text = "Whole Words";
		whole_words.toggled.connect(find);

		var entry_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		entry_box.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
		entry_box.pack_start(find_entry, true, true);
		entry_box.pack_start(case_sensitive, false, true);
		entry_box.pack_start(regex, false, true);
		entry_box.pack_start(whole_words, false, true);
		entry_box.hexpand = true;
		grid.attach(entry_box, 0, 0);

		var find_prev_button = new Gtk.Button.from_icon_name("go-up-symbolic", Gtk.IconSize.BUTTON);
		find_prev_button.tooltip_text = "Find Previous";
		find_prev_button.clicked.connect(find_previous);

		var find_next_button = new Gtk.Button.from_icon_name("go-down-symbolic", Gtk.IconSize.BUTTON);
		find_next_button.tooltip_text = "Find Next";
		find_next_button.clicked.connect(find_next);

		var find_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		find_box.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
		find_box.pack_start(find_prev_button, true, true);
		find_box.pack_start(find_next_button, true, true);
		grid.attach(find_box, 1, 0);

		var find_all_button = new Gtk.Button.with_label("Find All");
		find_all_button.clicked.connect(find_all);
		grid.attach(find_all_button, 2, 0);

		var close_button = new Gtk.Button.from_icon_name("window-close-symbolic", Gtk.IconSize.BUTTON);
		close_button.relief = Gtk.ReliefStyle.NONE;
		close_button.clicked.connect(() => hide());
		grid.attach(close_button, 3, 0);

		replace_entry = new Gtk.Entry();
		replace_entry.changed.connect(replace);
		replace_entry.activate.connect(replace_next);
		replace_entry.hexpand = true;
		grid.attach(replace_entry, 0, 1);

		var replace_button = new Gtk.Button.with_label("Replace");
		replace_button.clicked.connect(replace_next);
		grid.attach(replace_button, 1, 1);

		var replace_all_button = new Gtk.Button.with_label("Replace All");
		replace_all_button.clicked.connect(replace_all);
		grid.attach(replace_all_button, 2, 1);
	}

	public override bool key_press_event(Gdk.EventKey event) {
		if (event.keyval == Gdk.Key.Escape) {
			hide();
			return Gdk.EVENT_STOP;
		}
		return Gdk.EVENT_PROPAGATE;
	}

	public override void show() {
		base.show();
		core_connection.send_highlight_find(view_id, true);
	}

	public override void hide() {
		base.hide();
		core_connection.send_highlight_find(view_id, false);
	}

	public override void grab_focus() {
		find_entry.grab_focus();
	}
}

}
