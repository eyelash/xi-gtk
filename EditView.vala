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

class EditView: Gtk.DrawingArea, Gtk.Scrollable {
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

	public string tab { private set; get; }
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

	public EditView(string tab, CoreConnection core_connection) {
		this.tab = tab;
		this.core_connection = core_connection;
		im_context = new Gtk.IMMulticontext();
		im_context.commit.connect(handle_commit);
		font_description = Pango.FontDescription.from_string("Monospace 11");
		var metrics = get_pango_context().get_metrics(font_description, null);
		ascent = metrics.get_ascent() / Pango.SCALE;
		line_height = ascent + metrics.get_descent() / Pango.SCALE;
		can_focus = true;
		add_events(Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK|Gdk.EventMask.SCROLL_MASK|Gdk.EventMask.SMOOTH_SCROLL_MASK);
	}

	public override bool draw(Cairo.Context cr) {
		cr.set_source_surface(surface, 0, y_offset);
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

	private void send_render_lines(int first_line, int last_line) {
		core_connection.send_render_lines(tab, first_line, last_line, (result) => {
			update_lines(first_line, result.get_array());
		});
	}

	public override void size_allocate(Gtk.Allocation allocation) {
		base.size_allocate(allocation);
		int lines_length = (int)(allocation.height / line_height) + 2;
		int previous_lines_length = lines.length;
		lines.resize(lines_length);
		int surface_height = (int)(lines.length*line_height) + 1;
		if (surface == null) {
			surface = (Cairo.ImageSurface)get_window().create_similar_image_surface(Cairo.Format.RGB24, allocation.width, surface_height, 0);
			cr = new Cairo.Context(surface);
			cr.set_source_rgb(1, 1, 1);
			cr.paint();
			send_render_lines(first_line, first_line+lines.length);
		} else if (allocation.width > surface.get_width()) {
			var new_surface = (Cairo.ImageSurface)get_window().create_similar_image_surface(Cairo.Format.RGB24, allocation.width, surface_height, 0);
			cr = new Cairo.Context(new_surface);
			cr.set_source_rgb(1, 1, 1);
			cr.paint();
			cr.set_source_surface(surface, 0, 0);
			cr.paint();
			surface = new_surface;
			send_render_lines(first_line, first_line+lines.length);
		} else if (allocation.width != surface.get_width() || surface_height != surface_height) {
			var new_surface = (Cairo.ImageSurface)get_window().create_similar_image_surface(Cairo.Format.RGB24, allocation.width, surface_height, 0);
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
		}
		y_offset = Math.round(first_line*line_height - value);
		queue_draw();
	}

	public override void get_preferred_height(out int minimum_height, out int natural_height) {
		minimum_height = (int)(total_lines * line_height);
		natural_height = minimum_height;
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
			cr.rectangle(0, (i-this.first_line)*line_height, surface.get_width(), line_height);
			cr.fill();
			cr.set_source_rgb(0, 0, 0);
			for (int j = 1; j < line.get_length(); j++) {
				var annotation = line.get_array_element(j);
				switch (annotation.get_string_element(0)) {
					case "cursor":
						var cursor = annotation.get_int_element(1);
						int x_pos;
						layout.index_to_line_x((int)cursor, false, null, out x_pos);
						cr.rectangle(x_pos/Pango.SCALE, (i-this.first_line)*line_height, 1, line_height);
						cr.fill();
						break;
					case "fg":
						break;
				}
			}
			cr.move_to(0, (i-this.first_line)*line_height+ascent);
			Pango.cairo_show_layout_line(cr, layout.get_line_readonly(0));
			this.lines[i-this.first_line] = layout;
		}
		queue_draw();
	}

	public void update(int64 first_line, int64 height, Json.Array lines, int64 scrollto_line, int64 scrollto_column) {
		total_lines = (int)height;
		update_lines((int)first_line, lines);
		_vadjustment.upper = total_lines * line_height;
	}
}

}
