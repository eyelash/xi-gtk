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
	private Cairo.ImageSurface surface;
	private Cairo.Context cr;
	private Pango.FontDescription font_description;
	private double ascent;
	private double line_height;
	private int first_line;
	private Pango.Layout[] lines;

	public string tab { private set; get; }

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
		add_events(Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK);
	}

	public override bool draw(Cairo.Context cr) {
		cr.set_source_surface(surface, 0, 0);
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

	public override void size_allocate(Gtk.Allocation allocation) {
		base.size_allocate(allocation);
		surface = (Cairo.ImageSurface)get_window().create_similar_image_surface(Cairo.Format.RGB24, allocation.width, allocation.height, 0);
		cr = new Cairo.Context(surface);
		cr.set_source_rgb(1, 1, 1);
		cr.paint();
		cr.set_source_rgb(0, 0, 0);
		int lines_length = (int)(allocation.height / line_height) + 1;
		int previous_lines_length = lines.length;
		lines.resize(lines_length);
		// draw the lines that were already visible
		for (int i = 0; i < lines.length; i++) {
			if (lines[i] != null) {
				cr.move_to(0, i*line_height + ascent);
				Pango.cairo_show_layout_line(cr, lines[i].get_line_readonly(0));
			}
		}
		// request the new lines
		if (lines_length > previous_lines_length) {
			core_connection.send_render_lines(tab, first_line+previous_lines_length, first_line+lines_length, (result) => {
				render_lines(first_line+previous_lines_length, result.get_array());
			});
		}
	}

	public override void get_preferred_height(out int minimum_height, out int natural_height) {
		minimum_height = 0;
		natural_height = 0;
	}

	private void render_lines(int first_line, Json.Array lines) {
		int start = int.max(this.first_line, first_line);
		int end = int.min(this.first_line + this.lines.length, first_line + (int)lines.get_length());
		for (int i = start; i < end; i++) {
			var line = lines.get_array_element(i-first_line);
			var text = line.get_string_element(0);
			var layout = Pango.cairo_create_layout(cr);
			layout.set_text(text, -1);
			layout.set_font_description(font_description);
			for (int j = 1; j < line.get_length(); j++) {
				var annotation = line.get_array_element(j);
				switch (annotation.get_string_element(0)) {
					case "fg":
						break;
				}
			}
			cr.set_source_rgb(1, 1, 1);
			cr.rectangle(0, (i-this.first_line)*line_height, surface.get_width(), line_height);
			cr.fill();
			cr.set_source_rgb(0, 0, 0);
			cr.move_to(0, (i-this.first_line)*line_height+ascent);
			Pango.cairo_show_layout_line(cr, layout.get_line_readonly(0));
			this.lines[i-this.first_line] = layout;
		}
		queue_draw();
	}

	public void update(int64 first_line, int64 height, Json.Array lines, int64 scrollto_line, int64 scrollto_column) {
		render_lines((int)first_line, lines);
	}
}

}
