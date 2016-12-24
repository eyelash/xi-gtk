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

struct Position {
	public int line;
	public int column;
}

struct Line {
	Pango.Layout layout;

	public Line(Pango.Context context, string text, Pango.FontDescription font_description) {
		layout = new Pango.Layout(context);
		layout.set_text(text, -1);
		layout.set_font_description(font_description);
		layout.set_attributes(new Pango.AttrList());
	}

	public void set_foreground(uint start_index, uint end_index, uint32 color) {
		var attribute = Pango.attr_foreground_new(
			(uint16)(((color >> 16) & 0xFF) << 8),
			(uint16)(((color >> 8) & 0xFF) << 8),
			(uint16)((color & 0xFF) << 8)
		);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		layout.get_attributes().change((owned)attribute);
	}

	public void set_background(uint start_index, uint end_index, uint32 color) {
		var attribute = Pango.attr_background_new(
			(uint16)(((color >> 16) & 0xFF) << 8),
			(uint16)(((color >> 8) & 0xFF) << 8),
			(uint16)((color & 0xFF) << 8)
		);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		layout.get_attributes().change((owned)attribute);
	}

	public void set_weight(uint start_index, uint end_index, Pango.Weight weight) {
		var attribute = Pango.attr_weight_new(weight);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		layout.get_attributes().change((owned)attribute);
	}

	public void set_underline(uint start_index, uint end_index) {
		var attribute = Pango.attr_underline_new(Pango.Underline.SINGLE);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		layout.get_attributes().change((owned)attribute);
	}

	public void set_italic(uint start_index, uint end_index) {
		var attribute = Pango.attr_style_new(Pango.Style.ITALIC);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		layout.get_attributes().change((owned)attribute);
	}

	public void draw(Cairo.Context cr, double x, double y) {
		if (layout == null) return;
		cr.move_to(x, y);
		Pango.cairo_show_layout_line(cr, layout.get_line_readonly(0));
	}

	public double index_to_x(int index) {
		if (layout == null) return 0.0;
		int x_pos;
		layout.get_line_readonly(0).index_to_x(index, false, out x_pos);
		return x_pos / Pango.SCALE;
	}

	public int x_to_index(double x) {
		if (layout == null) return 0;
		int index, trailing;
		layout.get_line_readonly(0).x_to_index((int)(x*Pango.SCALE), out index, out trailing);
		return index + trailing;
	}
}

class EditView: Gtk.DrawingArea, Gtk.Scrollable {
	private File file;
	private CoreConnection core_connection;
	private Gtk.IMContext im_context;
	private double y_offset;
	private Pango.FontDescription font_description;
	private double ascent;
	private double line_height;
	private int total_lines;
	private int first_line;
	private Line[] lines;
	private Position cursor_position;
	private int blink_time;
	private int blink_counter;
	private TimeoutSource blink_source;

	public string tab { private set; get; }
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
		line = (int)((y - y_offset) / line_height) + first_line;
		column = lines[line-first_line].x_to_index(x);
	}

	private void send_render_lines(int first_line, int last_line) {
		first_line = int.max(first_line, this.first_line);
		last_line = int.min(last_line, this.first_line + lines.length);
		if (first_line == last_line) return;
		core_connection.send_render_lines(tab, first_line, last_line, (result) => {
			update_lines(first_line, result.get_array());
		});
	}

	public EditView(string tab, File? file, CoreConnection core_connection) {
		this.tab = tab;
		this.file = file;
		this.core_connection = core_connection;
		im_context = new Gtk.IMMulticontext();
		im_context.commit.connect(handle_commit);
		var settings = new Settings("org.gnome.desktop.interface");
		font_description = Pango.FontDescription.from_string(settings.get_string("monospace-font-name"));
		var metrics = get_pango_context().get_metrics(font_description, null);
		ascent = metrics.get_ascent() / Pango.SCALE;
		line_height = ascent + metrics.get_descent() / Pango.SCALE;
		blink_time = settings.get_int("cursor-blink-time") / 2;
		can_focus = true;
		set_has_window(true);
		add_events(Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK|Gdk.EventMask.BUTTON_MOTION_MASK|Gdk.EventMask.SCROLL_MASK|Gdk.EventMask.SMOOTH_SCROLL_MASK);
		if (file != null) {
			core_connection.send_open(tab, file.get_path());
			label = file.get_basename();
		} else {
			label = "untitled";
		}
	}

	~EditView() {
		core_connection.send_delete_tab(tab);
	}

	public override void realize() {
		base.realize();
		get_window().set_cursor(new Gdk.Cursor.for_display(get_display(), Gdk.CursorType.XTERM));
	}

	public override void size_allocate(Gtk.Allocation allocation) {
		base.size_allocate(allocation);
		int lines_length = (int)(allocation.height / line_height) + 2;
		int previous_lines_length = lines.length;
		if (lines_length != previous_lines_length) {
			lines.resize(lines_length);
			core_connection.send_scroll(tab, first_line, first_line+lines.length);
			if (lines_length > previous_lines_length) {
				send_render_lines(first_line+previous_lines_length, first_line+lines.length);
			}
		}
		_vadjustment.page_size = allocation.height;
	}

	public override void get_preferred_height(out int minimum_height, out int natural_height) {
		minimum_height = (int)(total_lines * line_height);
		natural_height = minimum_height;
	}

	public override bool draw(Cairo.Context cr) {
		// draw the lines
		for (int i = 0; i < lines.length; i++) {
			lines[i].draw(cr, 0, y_offset + i * line_height + ascent);
		}
		// draw the cursors
		if (blink_counter % 2 == 0) {
			int index = cursor_position.line - first_line;
			if (index >= 0 && index < lines.length) {
				double x = lines[index].index_to_x(cursor_position.column);
				cr.set_source_rgb(0, 0, 0);
				cr.rectangle(x, y_offset+index*line_height, 1, line_height);
				cr.fill();
			}
		}
		return Gdk.EVENT_STOP;
	}

	public override bool key_press_event(Gdk.EventKey event) {
		if (!im_context.filter_keypress(event)) {
			string suffix = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0 ? "_and_modify_selection" : "";
			switch (event.keyval) {
				case Gdk.Key.Return:
					core_connection.send_edit(tab, "insert_newline");
					break;
				case Gdk.Key.BackSpace:
					core_connection.send_edit(tab, "delete_backward");
					break;
				case Gdk.Key.Delete:
					core_connection.send_edit(tab, "delete_forward");
					break;
				case Gdk.Key.Tab:
					core_connection.send_edit(tab, "insert_tab");
					break;
				case Gdk.Key.Up:
					core_connection.send_edit(tab, "move_up" + suffix);
					break;
				case Gdk.Key.Right:
					core_connection.send_edit(tab, "move_right" + suffix);
					break;
				case Gdk.Key.Down:
					core_connection.send_edit(tab, "move_down" + suffix);
					break;
				case Gdk.Key.Left:
					core_connection.send_edit(tab, "move_left" + suffix);
					break;
				case Gdk.Key.Page_Up:
					core_connection.send_edit(tab, "page_up" + suffix);
					break;
				case Gdk.Key.Page_Down:
					core_connection.send_edit(tab, "page_down" + suffix);
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
		core_connection.send_insert(tab, str);
	}

	public override bool button_press_event(Gdk.EventButton event) {
		int line, column;
		convert_xy(event.x, event.y, out line, out column);
		core_connection.send_click(tab, line, column, 0, 1);
		return Gdk.EVENT_STOP;
	}
	public override bool button_release_event(Gdk.EventButton event) {
		return Gdk.EVENT_STOP;
	}
	public override bool motion_notify_event(Gdk.EventMotion event) {
		int line, column;
		convert_xy(event.x, event.y, out line, out column);
		core_connection.send_drag(tab, line, column, 0);
		return Gdk.EVENT_STOP;
	}

	private void scroll() {
		double value = _vadjustment.value;
		int previous_first_line = first_line;
		first_line = (int)(value / line_height);
		if (first_line > previous_first_line) {
			int diff = first_line - previous_first_line;
			for (int i = diff; i < lines.length; i++) {
				lines[i-diff] = lines[i];
			}
			send_render_lines(previous_first_line+lines.length, first_line+lines.length);
			core_connection.send_scroll(tab, first_line, first_line+lines.length);
		} else if (first_line < previous_first_line) {
			int diff = previous_first_line - first_line;
			for (int i = lines.length-diff-1; i >= 0; i--) {
				lines[i+diff] = lines[i];
			}
			send_render_lines(first_line, previous_first_line);
			core_connection.send_scroll(tab, first_line, first_line+lines.length);
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

	private void update_lines(int first_line, Json.Array lines) {
		int start = int.max(this.first_line, first_line);
		int end = int.min(this.first_line + this.lines.length, first_line + (int)lines.get_length());
		for (int i = start; i < end; i++) {
			var line_json = lines.get_array_element(i-first_line);
			var text = line_json.get_string_element(0);
			var line = Line(get_pango_context(), text, font_description);
			for (int j = 1; j < line_json.get_length(); j++) {
				var annotation = line_json.get_array_element(j);
				switch (annotation.get_string_element(0)) {
					case "cursor":
						int column = (int)annotation.get_int_element(1);
						cursor_position = {i, column};
						break;
					case "fg":
						uint start_index = (uint)annotation.get_int_element(1);
						uint end_index = (uint)annotation.get_int_element(2);
						uint32 color = (uint32)annotation.get_int_element(3);
						line.set_foreground(start_index, end_index, color);
						int font_style = (int)annotation.get_int_element(4);
						if ((font_style & 1) != 0) {
							line.set_weight(start_index, end_index, Pango.Weight.BOLD);
						}
						if ((font_style & 2) != 0) {
							line.set_underline(start_index, end_index);
						}
						if ((font_style & 4) != 0) {
							line.set_italic(start_index, end_index);
						}
						break;
					case "sel":
						uint start_index = (uint)annotation.get_int_element(1);
						uint end_index = (uint)annotation.get_int_element(2);
						line.set_background(start_index, end_index, 0xCCCCCC);
						break;
				}
			}
			this.lines[i-this.first_line] = line;
		}
		queue_draw();
	}

	// public interface
	public void update(Json.Object update) {
		if (update.has_member("height")) {
			total_lines = (int)update.get_int_member("height");
			_vadjustment.upper = total_lines * line_height;
		}
		int first_line = (int)update.get_int_member("first_line");
		update_lines(first_line, update.get_array_member("lines"));
		blink_start();
		if (update.has_member("scrollto")) {
			var scrollto_line = update.get_array_member("scrollto").get_int_element(0);
			if (scrollto_line * line_height < this.first_line * line_height - y_offset) {
				_vadjustment.value = scrollto_line * line_height;
			}
			else if ((scrollto_line + 1) * line_height > this.first_line * line_height - y_offset + get_allocated_height()) {
				_vadjustment.value = (scrollto_line + 1) * line_height - get_allocated_height();
			}
		}
	}

	public void save() {
		if (file == null) {
			save_as();
			return;
		}
		core_connection.send_save(tab, file.get_path());
	}
	public void save_as() {
		var dialog = new Gtk.FileChooserDialog(null, get_toplevel() as Gtk.Window, Gtk.FileChooserAction.SAVE, "Cancel", Gtk.ResponseType.CANCEL, "Save", Gtk.ResponseType.ACCEPT);
		dialog.do_overwrite_confirmation = true;
		if (dialog.run() == Gtk.ResponseType.ACCEPT) {
			file = dialog.get_file();
			label = file.get_basename();
			core_connection.send_save(tab, file.get_path());
		}
		dialog.destroy();
	}
}

}
