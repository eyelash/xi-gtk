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

class Notebook: Gtk.Notebook {

	public Notebook() {
		set_scrollable(true);
	}

	public Gtk.Box create_tab_label(EditView edit_view) {
		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

		var label = new Gtk.Label(edit_view.label);
		edit_view.bind_property("label", label, "label");
		box.set_center_widget(label);

		var close_button = new Gtk.Button();
		var close_image = new Gtk.Image.from_icon_name("window-close-symbolic", Gtk.IconSize.MENU);
		close_button.add(close_image);
		close_button.relief = Gtk.ReliefStyle.NONE;
		close_button.focus_on_click = false;
		close_button.clicked.connect(() => {
			int index = page_num(edit_view.get_parent());
			remove_page(index);
		});
		box.pack_end(close_button, false, true);

		var image = new Gtk.Image.from_icon_name("media-record-symbolic", Gtk.IconSize.MENU);
		edit_view.bind_property("has-unsaved-changes", image, "visible");
		box.pack_end(image, false, true);

		label.show();
		close_button.show_all();
		return box;
	}

	public void add_edit_view(EditView edit_view) {
		var scrolled_window = new Gtk.ScrolledWindow(null, null);
		scrolled_window.add(edit_view);
		var label = create_tab_label(edit_view);
		append_page(scrolled_window, label);
		set_tab_reorderable(scrolled_window, true);
		child_set_property(scrolled_window, "tab-expand", true);
		scrolled_window.show_all();
		label.show();
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

}
