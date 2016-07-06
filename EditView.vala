// Copyright 2016 Elias Aebi
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

class EditView: Gtk.DrawingArea {
	private CoreConnection core_connection;
	private Gtk.IMContext im_context;

	public EditView(CoreConnection core_connection) {
		this.core_connection = core_connection;
		im_context = new Gtk.IMMulticontext();
		im_context.commit.connect(handle_commit);
		can_focus = true;
		add_events(Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK);
		core_connection.send_new_tab();
		core_connection.send_open("0", "CoreConnection.vala");
	}

	public override bool draw(Cairo.Context cr) {
		cr.set_source_rgb(1, 1, 1);
		cr.paint();
		return false;
	}

	public override bool key_press_event(Gdk.EventKey event) {
		im_context.filter_keypress(event);
		return false;
	}
	public override bool key_release_event(Gdk.EventKey event) {
		im_context.filter_keypress(event);
		return false;
	}

	private void handle_commit(string str) {
		stdout.printf("commit: %s\n", str);
	}

	public override bool button_press_event(Gdk.EventButton event) {
		stdout.printf("button press: (%f, %f)\n", event.x, event.y);
		return false;
	}
	public override bool button_release_event(Gdk.EventButton event) {
		return false;
	}
}

}
