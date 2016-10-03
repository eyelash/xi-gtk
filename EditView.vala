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

class EditView: Gtk.DrawingArea, Gtk.Scrollable {
	private File file;
	private CoreConnection core_connection;
	private Gtk.IMContext im_context;
	private Cairo.ImageSurface surface;
	private Cairo.Context cr;
	private double y_offset;
	private Pango.FontDescription font_description;
	private double ascent;
	private double line_height;
	private int total_lines;
	private int first_line;
	private Pango.Layout[] lines;
	private Position cursor_position;
	private int blink_time;
	private int blink_counter;
	private TimeoutSource blink_source;

	public string tab { private set; get; }
	public string label { private set; get; }
	public Gtk.Adjustment hadjustment { construct set; get; }
	public Gtk.ScrollablePolicy hscroll_policy { set; get; }
	private Gtk.Adjustment _vadjustment;
	public Gtk.Adjustment vadjustment {
		construct set {
			_vadjustment = value;
			if (value != null) {
				value.value_changed.connect(scroll);
			}
		}
		get {
			return _vadjustment;
		}
	}
	public Gtk.ScrollablePolicy vscroll_policy { set; get; }

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

	public override bool draw(Cairo.Context cr) {
		// draw the lines
		cr.set_source_surface(surface, 0, y_offset);
		cr.paint();
		// draw the cursors
		if (blink_counter % 2 == 0) {
			int index = cursor_position.line - first_line;
			if (index >= 0 && index < lines.length) {
				int x_pos = 0;
				var line = lines[index];
				if (line != null) line.get_line_readonly(0).index_to_x(cursor_position.column, false, out x_pos);
				cr.set_source_rgb(0, 0, 0);
				cr.rectangle(x_pos/Pango.SCALE, y_offset+index*line_height, 1, line_height);
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
			}
		}
		return true;
	}
	public override bool key_release_event(Gdk.EventKey event) {
		im_context.filter_keypress(event);
		return false;
	}

	private void handle_commit(string str) {
		core_connection.send_insert(tab, str);
	}

	private void convert_xy(double x, double y, out int line, out int column) {
		line = (int)((y - y_offset) / line_height);
		var layout = lines[line];
		if (layout != null) {
			int trailing;
			layout.get_line_readonly(0).x_to_index((int)(x*Pango.SCALE), out column, out trailing);
			column += trailing;
		} else {
			column = 0;
		}
		line += first_line;
	}

	public override bool button_press_event(Gdk.EventButton event) {
		int line, column;
		convert_xy(event.x, event.y, out line, out column);
		core_connection.send_click(tab, line, column, 0, 1);
		return true;
	}
	public override bool button_release_event(Gdk.EventButton event) {
		return false;
	}
	public override bool motion_notify_event(Gdk.EventMotion event) {
		int line, column;
		convert_xy(event.x, event.y, out line, out column);
		core_connection.send_drag(tab, line, column, 0);
		return true;
	}

	private void send_render_lines(int first_line, int last_line) {
		first_line = int.max(first_line, this.first_line);
		last_line = int.min(last_line, this.first_line + lines.length);
		core_connection.send_render_lines(tab, first_line, last_line, (result) => {
			update_lines(first_line, result.get_array());
		});
	}

	public override void size_allocate(Gtk.Allocation allocation) {
		base.size_allocate(allocation);
		int lines_length = (int)(allocation.height / line_height) + 2;
		int previous_lines_length = lines.length;
		if (lines_length != previous_lines_length) {
			lines.resize(lines_length);
			core_connection.send_scroll(tab, first_line, first_line+lines.length);
		}
		int surface_height = (int)(lines.length*line_height) + 1;
		if (surface == null) {
			// create a new surface and request all visible lines
			surface = (Cairo.ImageSurface)get_window().create_similar_image_surface(Cairo.Format.RGB24, allocation.width*get_scale_factor(), surface_height*get_scale_factor(), 0);
			cr = new Cairo.Context(surface);
			cr.set_source_rgb(1, 1, 1);
			cr.paint();
			send_render_lines(first_line, first_line+lines.length);
		} else if (allocation.width > surface.get_width()/get_scale_factor()) {
			// create a new surface, draw the current surface to the new surface and request all visible lines
			var new_surface = (Cairo.ImageSurface)get_window().create_similar_image_surface(Cairo.Format.RGB24, allocation.width*get_scale_factor(), surface_height*get_scale_factor(), 0);
			cr = new Cairo.Context(new_surface);
			cr.set_source_rgb(1, 1, 1);
			cr.paint();
			cr.set_source_surface(surface, 0, 0);
			cr.paint();
			surface = new_surface;
			send_render_lines(first_line, first_line+lines.length);
		} else if (allocation.width != surface.get_width()/get_scale_factor() || surface_height != surface.get_height()/get_scale_factor()) {
			// create a new surface, draw the current surface to the new surface and request only the newly visible lines
			var new_surface = (Cairo.ImageSurface)get_window().create_similar_image_surface(Cairo.Format.RGB24, allocation.width*get_scale_factor(), surface_height*get_scale_factor(), 0);
			cr = new Cairo.Context(new_surface);
			cr.set_source_rgb(1, 1, 1);
			cr.paint();
			cr.set_source_surface(surface, 0, 0);
			cr.paint();
			surface = new_surface;
			if (lines_length > previous_lines_length) {
				send_render_lines(first_line+previous_lines_length, first_line+lines.length);
			}
		}
		_vadjustment.page_size = allocation.height;
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
			cr.set_source_surface(surface, 0, -diff*line_height);
			cr.paint();
			send_render_lines(previous_first_line+lines.length, first_line+lines.length);
			core_connection.send_scroll(tab, first_line, first_line+lines.length);
		} else if (first_line < previous_first_line) {
			int diff = previous_first_line - first_line;
			for (int i = lines.length-diff-1; i >= 0; i--) {
				lines[i+diff] = lines[i];
			}
			var new_surface = (Cairo.ImageSurface)get_window().create_similar_image_surface(Cairo.Format.RGB24, surface.get_width(), surface.get_height(), 0);
			cr = new Cairo.Context(new_surface);
			cr.set_source_rgb(1, 1, 1);
			cr.paint();
			cr.set_source_surface(surface, 0, diff*line_height);
			cr.paint();
			surface = new_surface;
			send_render_lines(first_line, previous_first_line);
			core_connection.send_scroll(tab, first_line, first_line+lines.length);
		}
		y_offset = Math.round(first_line*line_height - value);
		queue_draw();
	}

	public override void get_preferred_height(out int minimum_height, out int natural_height) {
		minimum_height = (int)(total_lines * line_height);
		natural_height = minimum_height;
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
			var line = lines.get_array_element(i-first_line);
			var text = line.get_string_element(0);
			var layout = Pango.cairo_create_layout(cr);
			layout.set_text(text, -1);
			layout.set_font_description(font_description);
			cr.set_source_rgb(1, 1, 1);
			cr.rectangle(0, (i-this.first_line)*line_height, surface.get_width()/get_scale_factor(), line_height);
			cr.fill();
			var attributes = new Pango.AttrList();
			for (int j = 1; j < line.get_length(); j++) {
				var annotation = line.get_array_element(j);
				switch (annotation.get_string_element(0)) {
					case "cursor":
						int column = (int)annotation.get_int_element(1);
						cursor_position = {i, column};
						break;
					case "fg":
						uint start_index = (uint)annotation.get_int_element(1);
						uint end_index = (uint)annotation.get_int_element(2);
						uint32 color = (uint32)annotation.get_int_element(3);
						var attribute = Pango.attr_foreground_new((uint16)((color>>16)&0xFF)<<8, (uint16)((color>>8)&0xFF)<<8, (uint16)(color&0xFF)<<8);
						attribute.start_index = start_index;
						attribute.end_index = end_index;
						attributes.change((owned)attribute);
						int font_style = (int)annotation.get_int_element(4);
						if ((font_style & 1) != 0) {
							attribute = Pango.attr_weight_new(Pango.Weight.BOLD);
							attribute.start_index = start_index;
							attribute.end_index = end_index;
							attributes.change((owned)attribute);
						}
						if ((font_style & 2) != 0) {
							attribute = Pango.attr_underline_new(Pango.Underline.SINGLE);
							attribute.start_index = start_index;
							attribute.end_index = end_index;
							attributes.change((owned)attribute);
						}
						if ((font_style & 4) != 0) {
							attribute = Pango.attr_style_new(Pango.Style.ITALIC);
							attribute.start_index = start_index;
							attribute.end_index = end_index;
							attributes.change((owned)attribute);
						}
						break;
					case "sel":
						var attribute = Pango.attr_background_new(0xCC<<8, 0xCC<<8, 0xCC<<8);
						attribute.start_index = (uint)annotation.get_int_element(1);
						attribute.end_index = (uint)annotation.get_int_element(2);
						attributes.change((owned)attribute);
						break;
				}
			}
			layout.set_attributes(attributes);
			cr.set_source_rgb(0, 0, 0);
			cr.move_to(0, (i-this.first_line)*line_height+ascent);
			Pango.cairo_show_layout_line(cr, layout.get_line_readonly(0));
			this.lines[i-this.first_line] = layout;
		}
		queue_draw();
	}

	public void update(Json.Object update) {
		if (update.has_member("height")) {
			total_lines = (int)update.get_int_member("height");
			_vadjustment.upper = total_lines * line_height;
		}
		if (surface == null) return;
		int first_line = (int)update.get_int_member("first_line");
		update_lines(first_line, update.get_array_member("lines"));
		blink_start();
		if (update.has_member("scrollto")) {
			var scrollto_line = update.get_array_member("scrollto").get_int_element(0);
			if (scrollto_line * line_height < this.first_line * line_height - y_offset) {
				((get_parent() as Gtk.ScrolledWindow).get_vscrollbar() as Gtk.Range).set_value(scrollto_line * line_height);
			}
			else if ((scrollto_line + 1) * line_height > this.first_line * line_height - y_offset + get_allocated_height()) {
				((get_parent() as Gtk.ScrolledWindow).get_vscrollbar() as Gtk.Range).set_value((scrollto_line + 1) * line_height - get_allocated_height());
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
