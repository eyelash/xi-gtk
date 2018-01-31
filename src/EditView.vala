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
	private double ascent;
	private double line_height;
	private double char_width;

	private double padding;
	private double y_offset;
	private LineCache line_cache;
	private int64 first_line;
	private int visible_lines;
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
			if (value != null) value.value_changed.connect(scroll);
		}
		get {
			return _vadjustment;
		}
	}
	public Gtk.ScrollablePolicy vscroll_policy { set; get; }

	// private helper methods
	private void convert_xy(double x, double y, out int64 line, out int64 column) {
		line = int64.max(0, (int64)((y - y_offset) / line_height) + first_line);
		var _line = line_cache.get_line(line);
		column = _line != null ? _line.x_to_index(x - (padding + gutter_width + 2 * char_width)) : 0;
	}

	public EditView(string view_id, File? file, CoreConnection core_connection) {
		this.view_id = view_id;
		this.file = file;
		this.core_connection = core_connection;
		core_connection.update_received[view_id].connect(update);
		core_connection.scroll_to_received[view_id].connect(scroll_to);
		im_context = new Gtk.IMMulticontext();
		im_context.commit.connect(handle_commit);
		var settings = new Settings("org.gnome.desktop.interface");
		var font_description = Pango.FontDescription.from_string(settings.get_string("monospace-font-name"));
		var metrics = get_pango_context().get_metrics(font_description, null);
		ascent = Pango.units_to_double(metrics.get_ascent());
		line_height = ascent + Pango.units_to_double(metrics.get_descent());
		char_width = Pango.units_to_double(metrics.get_approximate_char_width());
		padding = char_width;
		y_offset = padding;
		line_cache = new LineCache(get_pango_context(), font_description);
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
		int previous_visible_lines = visible_lines;
		visible_lines = (int)(allocation.height / line_height) + 2;
		if (visible_lines != previous_visible_lines) {
			core_connection.send_scroll(view_id, first_line, first_line + visible_lines);
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
		for (int64 i = first_line; i < first_line + visible_lines; i++) {
			var line = line_cache.get_line(i);
			if (line != null) {
				double y = y_offset + (i - first_line) * line_height;
				line.draw_background(cr, padding + gutter_width + 2 * char_width, y, get_allocated_width(), line_height);
			}
		}
		for (int64 i = first_line; i < first_line + visible_lines; i++) {
			var line = line_cache.get_line(i);
			if (line != null) {
				double y = y_offset + (i - first_line) * line_height;
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
		int64 line, column;
		convert_xy(event.x, event.y, out line, out column);
		switch (event.type) {
			case Gdk.EventType.BUTTON_PRESS:
				if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
					core_connection.send_gesture(view_id, line, column, "toggle_sel");
				} else {
					core_connection.send_click(view_id, line, column, 0, 1);
					if (event.button == Gdk.BUTTON_MIDDLE) {
						paste_primary();
					}
				}
				break;
			case Gdk.EventType.2BUTTON_PRESS:
				core_connection.send_click(view_id, line, column, 0, 2);
				break;
			case Gdk.EventType.3BUTTON_PRESS:
				core_connection.send_click(view_id, line, column, 0, 3);
				break;
		}
		return Gdk.EVENT_STOP;
	}
	public override bool button_release_event(Gdk.EventButton event) {
		return Gdk.EVENT_STOP;
	}
	public override bool motion_notify_event(Gdk.EventMotion event) {
		int64 line, column;
		convert_xy(event.x, event.y, out line, out column);
		core_connection.send_drag(view_id, line, column, 0);
		return Gdk.EVENT_STOP;
	}

	private void scroll() {
		double value = _vadjustment.value - padding;
		int64 previous_first_line = first_line;
		first_line = int64.max(0, (int64)(value / line_height));
		if (first_line != previous_first_line) {
			core_connection.send_scroll(view_id, first_line, first_line + visible_lines);
		}
		y_offset = Math.round(first_line*line_height - value);
		queue_draw();
	}

	private void update(Json.Object update) {
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

	private void scroll_to(int64 line, int64 col) {
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
		core_connection.send_copy(view_id, (result) => {
			if (!result.is_null()) {
				get_clipboard(Gdk.SELECTION_CLIPBOARD).set_text(result.get_string(), -1);
			}
		});
	}
	[Signal(action = true)]
	public virtual signal void cut() {
		core_connection.send_cut(view_id, (result) => {
			if (!result.is_null()) {
				get_clipboard(Gdk.SELECTION_CLIPBOARD).set_text(result.get_string(), -1);
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
		core_connection.send_find(view_id, chars, false, () => {});
	}
	public void find_next() {
		core_connection.send_find_next(view_id, true, false);
	}
	public void find_previous() {
		core_connection.send_find_previous(view_id, true);
	}
}

}
