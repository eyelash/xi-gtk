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

}
