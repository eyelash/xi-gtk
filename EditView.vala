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

class EditView: Gtk.DrawingArea, Gtk.Scrollable {
	private File file;
	private CoreConnection core_connection;
	private Gtk.IMContext im_context;
	private double ascent;
	private double line_height;
	private double char_width;

	private double padding;
	private double y_offset;
	private LinesCache lines_cache;
	private int first_line;
	private int visible_lines;
	private int blink_time;
	private int blink_counter;
	private TimeoutSource blink_source;

	public string view_id { private set; get; }
	public string label { private set; get; }

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
	private void convert_xy(double x, double y, out int line, out int column) {
		line = int.max(0, (int)((y - y_offset) / line_height) + first_line);
		var _line = lines_cache.get_line(line);
		column = _line != null ? _line.x_to_index(x-padding) : 0;
	}

	public EditView(string view_id, File? file, CoreConnection core_connection) {
		this.view_id = view_id;
		this.file = file;
		this.core_connection = core_connection;
		core_connection.update_received.connect(update);
		core_connection.scroll_to_received.connect(scroll_to);
		im_context = new Gtk.IMMulticontext();
		im_context.commit.connect(handle_commit);
		var settings = new Settings("org.gnome.desktop.interface");
		var font_description = Pango.FontDescription.from_string(settings.get_string("monospace-font-name"));
		var metrics = get_pango_context().get_metrics(font_description, null);
		ascent = Pango.units_to_double(metrics.get_ascent());
		line_height = ascent + Pango.units_to_double(metrics.get_descent());
		char_width = Pango.units_to_double(metrics.get_approximate_char_width());
		padding = char_width;
		lines_cache = new LinesCache(get_pango_context(), font_description);
		blink_time = settings.get_int("cursor-blink-time") / 2;
		can_focus = true;
		set_has_window(true);
		add_events(Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK|Gdk.EventMask.BUTTON_MOTION_MASK|Gdk.EventMask.SCROLL_MASK|Gdk.EventMask.SMOOTH_SCROLL_MASK);
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
		if (_vadjustment.value > _vadjustment.upper - _vadjustment.page_size) {
			_vadjustment.value = _vadjustment.upper - _vadjustment.page_size;
		}
	}

	public override void get_preferred_height(out int minimum_height, out int natural_height) {
		minimum_height = (int)(lines_cache.get_height() * line_height);
		natural_height = minimum_height;
	}

	public override bool draw(Cairo.Context cr) {
		Gdk.cairo_set_source_rgba(cr, Utilities.convert_color(0xffffffffu));
		cr.paint();
		for (int i = first_line; i < first_line + visible_lines; i++) {
			var line = lines_cache.get_line(i);
			if (line != null) {
				line.draw(cr, padding, y_offset + (i - first_line) * line_height, get_allocated_width(), ascent, line_height, blink_counter % 2 == 0);
			}
		}
		return Gdk.EVENT_STOP;
	}

	public override bool key_press_event(Gdk.EventKey event) {
		if (!im_context.filter_keypress(event)) {
			unowned string suffix = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0 ? "_and_modify_selection" : "";
			switch (event.keyval) {
				case Gdk.Key.Return:
					send_edit("insert_newline");
					break;
				case Gdk.Key.BackSpace:
					send_edit("delete_backward");
					break;
				case Gdk.Key.Delete:
					send_edit("delete_forward");
					break;
				case Gdk.Key.Tab:
					send_edit("insert_tab");
					break;
				case Gdk.Key.Up:
					send_edit("move_up" + suffix);
					break;
				case Gdk.Key.Right:
					unowned string command = (event.state & Gdk.ModifierType.CONTROL_MASK) != 0 ? "move_word_right" : "move_right";
					send_edit(command + suffix);
					break;
				case Gdk.Key.Down:
					send_edit("move_down" + suffix);
					break;
				case Gdk.Key.Left:
					unowned string command = (event.state & Gdk.ModifierType.CONTROL_MASK) != 0 ? "move_word_left" : "move_left";
					send_edit(command + suffix);
					break;
				case Gdk.Key.Page_Up:
					send_edit("page_up" + suffix);
					break;
				case Gdk.Key.Page_Down:
					send_edit("page_down" + suffix);
					break;
			}
		}
		return Gdk.EVENT_STOP;
	}
	public override bool key_release_event(Gdk.EventKey event) {
		im_context.filter_keypress(event);
		return Gdk.EVENT_STOP;
	}

	private void handle_commit(string str) {
		core_connection.send_insert(view_id, str);
	}

	public override bool button_press_event(Gdk.EventButton event) {
		int line, column;
		convert_xy(event.x, event.y, out line, out column);
		switch (event.type) {
			case Gdk.EventType.BUTTON_PRESS:
				core_connection.send_click(view_id, line, column, 0, 1);
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
		int line, column;
		convert_xy(event.x, event.y, out line, out column);
		core_connection.send_drag(view_id, line, column, 0);
		return Gdk.EVENT_STOP;
	}

	private void scroll() {
		double value = _vadjustment.value - padding;
		int previous_first_line = first_line;
		first_line = int.max(0, (int)(value / line_height));
		if (first_line != previous_first_line) {
			core_connection.send_scroll(view_id, first_line, first_line + visible_lines);
		}
		y_offset = Math.round(first_line*line_height - value);
		queue_draw();
	}

	private bool blink() {
		blink_counter++;
		queue_draw();
		return blink_counter < 18;
	}
	private void blink_start() {
		if (blink_source != null) blink_source.destroy();
		blink_counter = 0;
		blink_source = new TimeoutSource(blink_time);
		blink_source.set_callback(blink);
		blink_source.attach(null);
	}

	// public interface
	public void update(string view_id, Json.Object update) {
		if (view_id != this.view_id) return;
		lines_cache.update(update);
		_vadjustment.upper = lines_cache.get_height() * line_height + 2 * padding;
		if (_vadjustment.value > _vadjustment.upper - _vadjustment.page_size) {
			_vadjustment.value = _vadjustment.upper - _vadjustment.page_size;
		}
		blink_start();
		queue_draw();
	}

	public void scroll_to(string view_id, int line, int col) {
		if (view_id != this.view_id) return;
		if (line * line_height < first_line * line_height - y_offset) {
			_vadjustment.value = line * line_height;
		} else if ((line + 1) * line_height > first_line * line_height - y_offset + get_allocated_height()) {
			_vadjustment.value = (line + 1) * line_height - get_allocated_height();
		}
	}

	public void send_edit(string method, Json.Object edit_params = new Json.Object()) {
		core_connection.send_edit(view_id, method, edit_params);
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

	public void undo() {
		core_connection.send_edit(view_id, "undo");
	}
	public void redo() {
		core_connection.send_edit(view_id, "redo");
	}
}

}
