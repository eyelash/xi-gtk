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

class EditViewContainer: Gtk.Box {
	private Xi.EditView edit_view;
	private Xi.FindBar find_bar;

	public EditViewContainer(EditView edit_view) {
		Object(orientation: Gtk.Orientation.VERTICAL);
		this.edit_view = edit_view;
		find_bar = new FindBar();
		find_bar.hide.connect(() => {
			edit_view.grab_focus();
		});
		var scrolled_window = new Gtk.ScrolledWindow(null, null);
		scrolled_window.add(edit_view);
		pack_start(scrolled_window, true, true);
		pack_start(find_bar, false, true);
		get_style_context().add_class(Gtk.STYLE_CLASS_BACKGROUND);
		scrolled_window.show_all();
	}

	public override void grab_focus() {
		edit_view.grab_focus();
	}

	public void show_find_bar() {
		find_bar.show_all();
		find_bar.grab_focus();
	}

	public void save() {
		edit_view.save();
	}
	public void save_as() {
		edit_view.save_as();
	}
}

}
