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

struct Style {
	Gdk.RGBA? foreground;
	Gdk.RGBA? background;
	Pango.Weight? weight;
	bool italic;
}

class StyleMap {
	private static StyleMap instance;
	private GenericArray<Style?> map;

	public static StyleMap get_instance() {
		if (instance == null) {
			instance = new StyleMap();
		}
		return instance;
	}

	public StyleMap() {
		map = new GenericArray<Style?>();
		// style id 0: selection
		map.add(Style() {
			background = {0.8, 0.8, 0.8, 1.0}
		});
	}

	private static Gdk.RGBA convert_color(uint32 color) {
		return Gdk.RGBA() {
			red = ((color >> 16) & 0xFF) / 255.0,
			green = ((color >> 8) & 0xFF) / 255.0,
			blue = (color & 0xFF) / 255.0,
			alpha = ((color >> 24) & 0xFF) / 255.0
		};
	}

	private static Pango.Weight convert_weight(int weight) {
		switch (weight) {
			case 400: return Pango.Weight.NORMAL;
			case 700: return Pango.Weight.BOLD;
			default: return Pango.Weight.NORMAL;
		}
	}

	public void def_style(Json.Object json_style) {
		int id = (int)json_style.get_int_member("id");
		Style style = Style();
		if (json_style.has_member("fg_color")) {
			style.foreground = convert_color((uint32)json_style.get_int_member("fg_color"));
		}
		if (json_style.has_member("bg_color")) {
			style.background = convert_color((uint32)json_style.get_int_member("bg_color"));
		}
		if (json_style.has_member("weight")) {
			style.weight = convert_weight((int)json_style.get_int_member("weight"));
		}
		if (json_style.has_member("italic")) {
			style.italic = json_style.get_boolean_member("italic");
		}
		if (id < map.length) {
			map[id] = style;
		} else {
			for (int i = map.length; i < id; i++) {
				map.add(null);
			}
			map.add(style);
		}
	}

	public Style get_style(int id) {
		return map[id];
	}
}

class Line {
	private Pango.Layout layout;
	private double[] cursors;

	public Line(Pango.Context context, string text, Pango.FontDescription font_description) {
		layout = new Pango.Layout(context);
		layout.set_text(text, -1);
		layout.set_font_description(font_description);
		layout.set_attributes(new Pango.AttrList());
	}

	public void set_cursors(Json.Array json_cursors) {
		cursors.resize((int)json_cursors.get_length());
		for (uint i = 0; i < json_cursors.get_length(); i++) {
			cursors[i] = index_to_x((int)json_cursors.get_int_element(i));
		}
	}

	public void set_style(uint start_index, uint end_index, Style style) {
		if (style.foreground != null) {
			set_foreground(start_index, end_index, style.foreground);
		}
		if (style.background != null) {
			set_background(start_index, end_index, style.background);
		}
		if (style.weight != null) {
			set_weight(start_index, end_index, style.weight);
		}
		if (style.italic) {
			set_italic(start_index, end_index);
		}
	}

	public void set_styles(Json.Array styles) {
		uint offset = 0;
		for (int i = 0; i < styles.get_length(); i += 3) {
			uint start = offset + (uint)styles.get_int_element(i);
			uint end = start + (uint)styles.get_int_element(i+1);
			int style_id = (int)styles.get_int_element(i+2);
			Style style = StyleMap.get_instance().get_style(style_id);
			set_style(start, end, style);
			offset = end;
		}
	}

	public void set_foreground(uint start_index, uint end_index, Gdk.RGBA color) {
		var attributes = layout.get_attributes();
		var attribute = Pango.attr_foreground_new((uint16)(color.red*uint16.MAX), (uint16)(color.green*uint16.MAX), (uint16)(color.blue*uint16.MAX));
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
		/*attribute = Pango.attr_foreground_alpha_new((uint16)(color.alpha*uint16.MAX));
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);*/
		layout.set_attributes(attributes);
	}

	public void set_background(uint start_index, uint end_index, Gdk.RGBA color) {
		var attributes = layout.get_attributes();
		var attribute = Pango.attr_background_new((uint16)(color.red*uint16.MAX), (uint16)(color.green*uint16.MAX), (uint16)(color.blue*uint16.MAX));
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
		/*attribute = Pango.attr_background_alpha_new((uint16)(color.alpha*uint16.MAX));
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);*/
		layout.set_attributes(attributes);
	}

	public void set_weight(uint start_index, uint end_index, Pango.Weight weight) {
		var attributes = layout.get_attributes();
		var attribute = Pango.attr_weight_new(weight);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
		layout.set_attributes(attributes);
	}

	public void set_underline(uint start_index, uint end_index) {
		var attributes = layout.get_attributes();
		var attribute = Pango.attr_underline_new(Pango.Underline.SINGLE);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
		layout.set_attributes(attributes);
	}

	public void set_italic(uint start_index, uint end_index) {
		var attributes = layout.get_attributes();
		var attribute = Pango.attr_style_new(Pango.Style.ITALIC);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
		layout.set_attributes(attributes);
	}

	public void draw(Cairo.Context cr, double y, double width, double ascent, double line_height, bool draw_cursors) {
		cr.move_to(0, y + ascent);
		Pango.cairo_show_layout_line(cr, layout.get_line_readonly(0));
		if (draw_cursors) {
			foreach (double cursor in cursors) {
				cr.rectangle(cursor, y, 1, line_height);
				cr.fill();
			}
		}
	}

	public double index_to_x(int index) {
		int x_pos;
		layout.get_line_readonly(0).index_to_x(index, false, out x_pos);
		return Pango.units_to_double(x_pos);
	}

	public int x_to_index(double x) {
		int index, trailing;
		layout.get_line_readonly(0).x_to_index(Pango.units_from_double(x), out index, out trailing);
		return index + trailing;
	}
}

class LinesCache {
	private GenericArray<Line?> lines;
	private int invalid_before;
	private int invalid_after;
	private Pango.Context context;
	private Pango.FontDescription font_description;

	public LinesCache(Pango.Context context, Pango.FontDescription font_description) {
		this.lines = new GenericArray<Line?>();
		this.context = context;
		this.font_description = font_description;
	}

	private static void add_invalid(GenericArray<Line?> lines, ref int invalid_before, ref int invalid_after, int n) {
		if (lines.length == 0) {
			invalid_before += n;
		} else {
			invalid_after += n;
		}
	}

	private static void add_line(GenericArray<Line?> lines, ref int invalid_before, ref int invalid_after, Line? line) {
		if (line != null) {
			for (int i = 0; i < invalid_after; i++) {
				lines.add(null);
			}
			invalid_after = 0;
			lines.add(line);
		} else {
			add_invalid(lines, ref invalid_before, ref invalid_after, 1);
		}
	}

	public void update(Json.Object update) {
		var ops = update.get_array_member("ops");
		var new_lines = new GenericArray<Line?>();
		int new_invalid_before = 0;
		int new_invalid_after = 0;
		int index = 0;
		for (int i = 0; i < ops.get_length(); i++) {
			var op = ops.get_object_element(i);
			switch (op.get_string_member("op")) {
				case "copy":
					stdout.printf("op: copy\n");
					int n = (int)op.get_int_member("n");
					if (index < invalid_before) {
						int invalid = int.min(n, invalid_before - index);
						add_invalid(new_lines, ref new_invalid_before, ref new_invalid_after, invalid);
						n -= invalid;
						index += invalid;
					}
					while (n > 0 && index < invalid_before + lines.length) {
						add_line(new_lines, ref new_invalid_before, ref new_invalid_after, lines[index-invalid_before]);
						n--;
						index++;
					}
					add_invalid(new_lines, ref new_invalid_before, ref new_invalid_after, n);
					index += n;
					break;
				case "skip":
					stdout.printf("op: skip\n");
					int n = (int)op.get_int_member("n");
					index += n;
					break;
				case "invalidate":
					stdout.printf("op: invalidate\n");
					int n = (int)op.get_int_member("n");
					add_invalid(new_lines, ref new_invalid_before, ref new_invalid_after, n);
					break;
				case "ins":
					stdout.printf("op: ins\n");
					var json_lines = op.get_array_member("lines");
					for (int j = 0; j < json_lines.get_length(); j++) {
						var json_line = json_lines.get_object_element(j);
						var text = json_line.get_string_member("text");
						var line = new Line(context, text, font_description);
						if (json_line.has_member("cursor")) {
							line.set_cursors(json_line.get_array_member("cursor"));
						}
						if (json_line.has_member("styles")) {
							line.set_styles(json_line.get_array_member("styles"));
						}
						add_line(new_lines, ref new_invalid_before, ref new_invalid_after, line);
					}
					break;
				case "update":
					stdout.printf("op: update\n");
					var json_lines = op.get_array_member("lines");
					// TODO: implement
					break;
			}
		}
		lines = new_lines;
		invalid_before = new_invalid_before;
		invalid_after = new_invalid_after;
	}

	public int get_height() {
		return invalid_before + lines.length + invalid_after;
	}

	public Line? get_line(int index) {
		if (index < invalid_before || index >= invalid_before + lines.length) {
			return null;
		}
		return lines[index - invalid_before];
	}
}

class EditView: Gtk.DrawingArea, Gtk.Scrollable {
	private File file;
	private CoreConnection core_connection;
	private Gtk.IMContext im_context;
	private double ascent;
	private double line_height;

	private double y_offset;
	private LinesCache lines_cache;
	private int total_lines;
	private int first_line;
	private int visible_lines;
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
		var _line = lines_cache.get_line(line);
		column = _line != null ? _line.x_to_index(x) : 0;
	}

	private void send_request_lines(int first_line, int last_line) {
		first_line = int.max(first_line, this.first_line);
		last_line = int.min(last_line, this.first_line + visible_lines);
		if (first_line == last_line) return;
		core_connection.send_request_lines(tab, first_line, last_line);
	}

	public EditView(string tab, File? file, CoreConnection core_connection) {
		this.tab = tab;
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
		lines_cache = new LinesCache(get_pango_context(), font_description);
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
		int previous_visible_lines = visible_lines;
		visible_lines = (int)(allocation.height / line_height) + 2;
		if (visible_lines != previous_visible_lines) {
			core_connection.send_scroll(tab, first_line, first_line + visible_lines);
			if (visible_lines > previous_visible_lines) {
				send_request_lines(first_line + previous_visible_lines, first_line + visible_lines);
			}
		}
		_vadjustment.page_size = allocation.height;
		if (_vadjustment.value > _vadjustment.upper - _vadjustment.page_size) {
			_vadjustment.value = _vadjustment.upper - _vadjustment.page_size;
		}
	}

	public override void get_preferred_height(out int minimum_height, out int natural_height) {
		minimum_height = (int)(total_lines * line_height);
		natural_height = minimum_height;
	}

	public override bool draw(Cairo.Context cr) {
		for (int i = first_line; i < first_line + visible_lines; i++) {
			var line = lines_cache.get_line(i);
			if (line != null) {
				line.draw(cr, y_offset + (i - first_line) * line_height, get_allocated_width(), ascent, line_height, blink_counter % 2 == 0);
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
			send_request_lines(previous_first_line + visible_lines, first_line + visible_lines);
			core_connection.send_scroll(tab, first_line, first_line + visible_lines);
		} else if (first_line < previous_first_line) {
			send_request_lines(first_line, previous_first_line);
			core_connection.send_scroll(tab, first_line, first_line + visible_lines);
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
	public void update(string tab, Json.Object update) {
		if (tab != this.tab) return;
		lines_cache.update(update);
		_vadjustment.upper = lines_cache.get_height() * line_height;
		if (_vadjustment.value > _vadjustment.upper - _vadjustment.page_size) {
			_vadjustment.value = _vadjustment.upper - _vadjustment.page_size;
		}
		blink_start();
		queue_draw();
	}

	public void scroll_to(string tab, int line, int col) {
		if (tab != this.tab) return;
		if (line * line_height < first_line * line_height - y_offset) {
			_vadjustment.value = line * line_height;
		} else if ((line + 1) * line_height > first_line * line_height - y_offset + get_allocated_height()) {
			_vadjustment.value = (line + 1) * line_height - get_allocated_height();
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
