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

		var image = new Gtk.Image.from_icon_name("media-record-symbolic", Gtk.IconSize.MENU);
		pack_end(image, false, true);
		edit_view.bind_property("has-unsaved-changes", image, "visible");

		show_all();
	}
}

}
