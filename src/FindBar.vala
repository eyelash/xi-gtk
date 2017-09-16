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

class FindBar: Gtk.ActionBar {
	private EditView edit_view;
	private Gtk.Entry entry;

	public FindBar(EditView edit_view) {
		this.edit_view = edit_view;
		entry = new Gtk.Entry();
		entry.hexpand = true;
		entry.changed.connect(() => edit_view.find(entry.text));
		entry.activate.connect(edit_view.find_next);
		pack_start(entry);
		var find_button = new Gtk.Button.with_label("Find");
		find_button.clicked.connect(edit_view.find_next);
		pack_start(find_button);
		var find_prev_button = new Gtk.Button.with_label("Find Prev");
		find_prev_button.clicked.connect(edit_view.find_previous);
		pack_start(find_prev_button);
		var close_button = new Gtk.Button.from_icon_name("window-close-symbolic", Gtk.IconSize.BUTTON);
		close_button.relief = Gtk.ReliefStyle.NONE;
		close_button.clicked.connect(() => hide());
		pack_start(close_button);
	}

	public override bool key_press_event(Gdk.EventKey event) {
		if (event.keyval == Gdk.Key.Escape) {
			hide();
			return Gdk.EVENT_STOP;
		}
		return Gdk.EVENT_PROPAGATE;
	}

	public override void grab_focus() {
		entry.grab_focus();
	}
}

}
