// Copyright 2016-2018 Elias Aebi
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

class EditView: Gtk.DrawingArea, Gtk.Scrollable {
	private string view_id;
	private File file;
	private CoreConnection core_connection;
	private Gtk.IMContext im_context;
	private LineCache line_cache;
	private double ascent;
	private double line_height;
	private double char_width;
	private double padding;
	private int64 first_line;
	private int64 last_line;
	private double gutter_width;
	private Blinker blinker;

	public string label { private set; get; }
	public bool has_unsaved_changes { private set; get; }

	// Gtk.Scrollable implementation
	public Gtk.Adjustment hadjustment { construct set; get; }
	public Gtk.ScrollablePolicy hscroll_policy { set; get; }
	private Gtk.Adjustment _vadjustment;
	public Gtk.Adjustment vadjustment {
		construct set {
			_vadjustment = value;
			if (value != null) value.value_changed.connect(handle_scroll);
		}
		get {
			return _vadjustment;
		}
	}
	public Gtk.ScrollablePolicy vscroll_policy { set; get; }
	public bool get_border(out Gtk.Border border) {
		border = Gtk.Border();
		return false;
	}

	// private helper methods
	private int64 get_line(double y) {
		return int64.max(0, (int64)((_vadjustment.value + y - padding) / line_height));
	}
	private int64 get_index(double x, int64 line) {
		var _line = line_cache.get_line(line);
		if (_line == null) {
			return 0;
		}
		return _line.x_to_index(x - (padding + gutter_width + 2 * char_width));
	}
	private double get_y(int64 line) {
		return line * line_height + padding - _vadjustment.value;
	}

	public EditView(string view_id, File? file, CoreConnection core_connection) {
		this.view_id = view_id;
		this.file = file;
		this.core_connection = core_connection;
		core_connection.update_received[view_id].connect(handle_update);
		core_connection.scroll_to_received[view_id].connect(handle_scroll_to);
		im_context = new Gtk.IMMulticontext();
		im_context.commit.connect(handle_commit);
		var settings = new Settings("org.gnome.desktop.interface");
		var font_description = Pango.FontDescription.from_string(settings.get_string("monospace-font-name"));
		var metrics = get_pango_context().get_metrics(font_description, null);
		line_cache = new LineCache(get_pango_context(), font_description);
		ascent = Pango.units_to_double(metrics.get_ascent());
		line_height = ascent + Pango.units_to_double(metrics.get_descent());
		char_width = Pango.units_to_double(metrics.get_approximate_char_width());
		padding = char_width;
		blinker = new Blinker(settings.get_int("cursor-blink-time") / 2);
		blinker.redraw.connect(this.queue_draw);
		can_focus = true;
		set_has_window(true);
		add_events(Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK|Gdk.EventMask.BUTTON_MOTION_MASK|Gdk.EventMask.SCROLL_MASK|Gdk.EventMask.SMOOTH_SCROLL_MASK);
		get_style_context().add_class("xi-edit-view");
		if (file != null) {
			label = file.get_basename();
		} else {
			label = "untitled";
		}
	}

	~EditView() {
		core_connection.send_close_view(view_id);
	}

	public override void realize() {
		base.realize();
		im_context.set_client_window(get_window());
		get_window().set_cursor(new Gdk.Cursor.for_display(get_display(), Gdk.CursorType.XTERM));
	}

	public override void size_allocate(Gtk.Allocation allocation) {
		base.size_allocate(allocation);
		int64 new_last_line = get_line(allocation.height) + 1;
		if (new_last_line != last_line) {
			last_line = new_last_line;
			core_connection.send_scroll(view_id, first_line, last_line);
		}
		_vadjustment.page_size = allocation.height;
		_vadjustment.upper = double.max(line_cache.get_height() * line_height + 2 * padding, allocation.height);
		if (_vadjustment.value > _vadjustment.upper - _vadjustment.page_size) {
			_vadjustment.value = _vadjustment.upper - _vadjustment.page_size;
		}
	}

	public override bool draw(Cairo.Context cr) {
		Gdk.cairo_set_source_rgba(cr, Theme.get_instance().background);
		cr.paint();
		for (int64 i = first_line; i < last_line; i++) {
			var line = line_cache.get_line(i);
			if (line != null) {
				double y = get_y(i);
				line.draw_background(cr, padding + gutter_width + 2 * char_width, y, get_allocated_width(), line_height);
			}
		}
		for (int64 i = first_line; i < last_line; i++) {
			var line = line_cache.get_line(i);
			if (line != null) {
				double y = get_y(i);
				line.draw(cr, padding + gutter_width + 2 * char_width, y, ascent);
				if (blinker.draw_cursor()) {
					line.draw_cursors(cr, padding + gutter_width + 2 * char_width, y, line_height);
				}
				line.draw_gutter(cr, padding + gutter_width, y, ascent);
			}
		}
		return Gdk.EVENT_STOP;
	}

	public override bool focus_in_event(Gdk.EventFocus event) {
		im_context.focus_in();
		blinker.restart();
		return Gdk.EVENT_STOP;
	}
	public override bool focus_out_event(Gdk.EventFocus event) {
		im_context.focus_out();
		blinker.stop();
		return Gdk.EVENT_STOP;
	}

	public override bool key_press_event(Gdk.EventKey event) {
		if (base.key_press_event(event)) {
			return Gdk.EVENT_STOP;
		}
		if (im_context.filter_keypress(event)) {
			return Gdk.EVENT_STOP;
		}
		return Gdk.EVENT_PROPAGATE;
	}
	public override bool key_release_event(Gdk.EventKey event) {
		if (base.key_release_event(event)) {
			return Gdk.EVENT_STOP;
		}
		if (im_context.filter_keypress(event)) {
			return Gdk.EVENT_STOP;
		}
		return Gdk.EVENT_PROPAGATE;
	}

	private void handle_commit(string str) {
		core_connection.send_insert(view_id, str);
	}

	public override bool button_press_event(Gdk.EventButton event) {
		if (focus_on_click && !has_focus) {
			grab_focus();
		}
		int64 line = get_line(event.y);
		int64 column = get_index(event.x, line);
		bool modify_selection = (event.state & get_modifier_mask(Gdk.ModifierIntent.MODIFY_SELECTION)) != 0;
		bool extend_selection = (event.state & get_modifier_mask(Gdk.ModifierIntent.EXTEND_SELECTION)) != 0;
		switch (event.type) {
			case Gdk.EventType.BUTTON_PRESS:
				if (modify_selection) {
					core_connection.send_gesture(view_id, line, column, "toggle_sel");
				} else if (extend_selection) {
					core_connection.send_gesture(view_id, line, column, "range_select");
				} else {
					core_connection.send_gesture(view_id, line, column, "point_select");
					if (event.button == Gdk.BUTTON_MIDDLE) {
						paste_primary();
					}
				}
				break;
			case Gdk.EventType.2BUTTON_PRESS:
				if (modify_selection) {
					core_connection.send_gesture(view_id, line, column, "multi_word_select");
				} else {
					core_connection.send_gesture(view_id, line, column, "word_select");
				}
				break;
			case Gdk.EventType.3BUTTON_PRESS:
				if (modify_selection) {
					core_connection.send_gesture(view_id, line, column, "multi_line_select");
				} else {
					core_connection.send_gesture(view_id, line, column, "line_select");
				}
				break;
		}
		return Gdk.EVENT_STOP;
	}
	public override bool button_release_event(Gdk.EventButton event) {
		return Gdk.EVENT_STOP;
	}
	public override bool motion_notify_event(Gdk.EventMotion event) {
		int64 line = get_line(event.y);
		int64 column = get_index(event.x, line);
		core_connection.send_drag(view_id, line, column, 0);
		return Gdk.EVENT_STOP;
	}

	private void handle_scroll() {
		int64 new_first_line = get_line(0);
		int64 new_last_line = get_line(get_allocated_height()) + 1;
		if (new_first_line != first_line || new_last_line != last_line) {
			first_line = new_first_line;
			last_line = new_last_line;
			core_connection.send_scroll(view_id, first_line, last_line);
		}
		queue_draw();
	}

	private void handle_update(Json.Object update) {
		line_cache.update(update);
		_vadjustment.upper = double.max(line_cache.get_height() * line_height + 2 * padding, get_allocated_height());
		if (_vadjustment.value > _vadjustment.upper - _vadjustment.page_size) {
			_vadjustment.value = _vadjustment.upper - _vadjustment.page_size;
		}
		gutter_width = Utilities.get_digits(line_cache.get_height()) * char_width;
		blinker.restart();
		queue_draw();
		if (update.has_member("pristine")) {
			has_unsaved_changes = !update.get_boolean_member("pristine");
		}
	}

	private void handle_scroll_to(int64 line, int64 col) {
		if ((line + 1) * line_height + 2 * padding > _vadjustment.value + get_allocated_height()) {
			_vadjustment.value = (line + 1) * line_height + 2 * padding - get_allocated_height();
		}
		if (line * line_height < _vadjustment.value) {
			_vadjustment.value = line * line_height;
		}
	}

	[Signal(action = true)]
	public virtual signal void send_edit(string method) {
		core_connection.send_edit(view_id, method, new Json.Object());
	}

	[Signal(action = true)]
	public virtual signal void copy() {
		core_connection.send_copy.begin(view_id, (obj, res) => {
			string result = core_connection.send_copy.end(res);
			if (result != null) {
				get_clipboard(Gdk.SELECTION_CLIPBOARD).set_text(result, -1);
			}
		});
	}
	[Signal(action = true)]
	public virtual signal void cut() {
		core_connection.send_cut.begin(view_id, (obj, res) => {
			string result = core_connection.send_cut.end(res);
			if (result != null) {
				get_clipboard(Gdk.SELECTION_CLIPBOARD).set_text(result, -1);
			}
		});
	}
	[Signal(action = true)]
	public virtual signal void paste() {
		get_clipboard(Gdk.SELECTION_CLIPBOARD).request_text((clipboard, text) => {
			if (text != null) {
				core_connection.send_insert(view_id, text);
			}
		});
	}

	private void paste_primary() {
		get_clipboard(Gdk.SELECTION_PRIMARY).request_text((clipboard, text) => {
			if (text != null) {
				core_connection.send_insert(view_id, text);
			}
		});
	}

	public void save() {
		if (file == null) {
			save_as();
			return;
		}
		core_connection.send_save(view_id, file.get_path());
	}
	public void save_as() {
		var dialog = new Gtk.FileChooserDialog(null, get_toplevel() as Gtk.Window, Gtk.FileChooserAction.SAVE, "Cancel", Gtk.ResponseType.CANCEL, "Save", Gtk.ResponseType.ACCEPT);
		dialog.do_overwrite_confirmation = true;
		if (dialog.run() == Gtk.ResponseType.ACCEPT) {
			file = dialog.get_file();
			label = file.get_basename();
			core_connection.send_save(view_id, file.get_path());
		}
		dialog.destroy();
	}

	public void find(string chars) {
		core_connection.send_find.begin(view_id, chars, false);
	}
	public void find_next() {
		core_connection.send_find_next(view_id, true, false);
	}
	public void find_previous() {
		core_connection.send_find_previous(view_id, true);
	}
}

}
