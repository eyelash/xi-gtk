// Copyright 2017-2018 Elias Aebi
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

class Line {
	struct Background {
		double x;
		double width;
		Gdk.RGBA color;
	}
	private Pango.Layout layout;
	private Pango.Layout number;
	private double[] cursors;
	private GenericArray<Background?> backgrounds;

	public Line(Pango.Context context, Pango.FontDescription font_description, string text) {
		layout = new Pango.Layout(context);
		layout.set_text(text, -1);
		layout.set_font_description(font_description);
		this.number = new Pango.Layout(context);
		this.number.set_font_description(font_description);
	}

	public void set_number(int64 number) {
		this.number.set_text(number == 0 ? "•" : number.to_string(), -1);
	}

	public bool is_wrapped() {
		return number.get_text() == "•";
	}

	public void set_cursors(Json.Array json_cursors) {
		cursors.resize((int)json_cursors.get_length());
		for (uint i = 0; i < json_cursors.get_length(); i++) {
			cursors[i] = index_to_x((int)json_cursors.get_int_element(i));
		}
	}

	private static void set_foreground(Pango.AttrList attributes, uint start_index, uint end_index, Gdk.RGBA color) {
		var attribute = Pango.attr_foreground_new((uint16)(color.red*uint16.MAX), (uint16)(color.green*uint16.MAX), (uint16)(color.blue*uint16.MAX));
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.insert((owned)attribute);
		attribute = Pango.attr_foreground_alpha_new((uint16)(color.alpha*uint16.MAX));
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.insert((owned)attribute);
	}

	private static void set_weight(Pango.AttrList attributes, uint start_index, uint end_index, Pango.Weight weight) {
		var attribute = Pango.attr_weight_new(weight);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.insert((owned)attribute);
	}

	private static void set_underline(Pango.AttrList attributes, uint start_index, uint end_index) {
		var attribute = Pango.attr_underline_new(Pango.Underline.SINGLE);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.insert((owned)attribute);
	}

	private static void set_italic(Pango.AttrList attributes, uint start_index, uint end_index) {
		var attribute = Pango.attr_style_new(Pango.Style.ITALIC);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.insert((owned)attribute);
	}

	public void set_styles(Json.Array styles) {
		backgrounds = new GenericArray<Background?>();
		var attributes = new Pango.AttrList();
		uint offset = 0;
		for (int i = 0; i < styles.get_length(); i += 3) {
			uint start = offset + (uint)styles.get_int_element(i);
			uint end = start + (uint)styles.get_int_element(i + 1);
			int style_id = (int)styles.get_int_element(i + 2);
			Style style = StyleMap.get_instance().get_style(style_id);
			if (style.foreground != null) {
				set_foreground(attributes, start, end, style.foreground);
			}
			if (style.background != null) {
				double x = index_to_x((int)start);
				double width = index_to_x((int)end) - x;
				backgrounds.add(Background() {
					x = x,
					width = width,
					color = style.background
				});
			}
			if (style.weight != null) {
				set_weight(attributes, start, end, style.weight);
			}
			if (style.underline) {
				set_underline(attributes, start, end);
			}
			if (style.italic) {
				set_italic(attributes, start, end);
			}
			offset = end;
		}
		layout.set_attributes(attributes);
	}

	public void draw_background(Cairo.Context cr, double x, double y, double width, double line_height) {
		if (cursors.length > 0) {
			Gdk.cairo_set_source_rgba(cr, Theme.get_instance().line_highlight);
			cr.rectangle(0, y, width, line_height);
			cr.fill();
		}
		for (int i = 0; i < backgrounds.length; i++) {
			Gdk.cairo_set_source_rgba(cr, backgrounds[i].color);
			cr.rectangle(x + backgrounds[i].x, y, backgrounds[i].width, line_height);
			cr.fill();
		}
	}

	public void draw(Cairo.Context cr, double x, double y, double ascent) {
		Gdk.cairo_set_source_rgba(cr, Theme.get_instance().foreground);
		cr.move_to(x, y + ascent);
		Pango.cairo_show_layout_line(cr, layout.get_line_readonly(0));
	}

	public void draw_cursors(Cairo.Context cr, double x, double y, double line_height) {
		Gdk.cairo_set_source_rgba(cr, Theme.get_instance().caret);
		foreach (double cursor in cursors) {
			cr.rectangle(x + cursor, y, 1, line_height);
			cr.fill();
		}
	}

	public void draw_gutter(Cairo.Context cr, double x, double y, double ascent) {
		Gdk.cairo_set_source_rgba(cr, Theme.get_instance().gutter_foreground);
		Pango.Rectangle extents;
		number.get_line_readonly(0).get_pixel_extents(null, out extents);
		cr.move_to(x - extents.width, y + ascent);
		Pango.cairo_show_layout_line(cr, number.get_line_readonly(0));
	}

	public double index_to_x(int index) {
		int x_pos;
		layout.get_line_readonly(0).index_to_x(index, false, out x_pos);
		return Pango.units_to_double(x_pos);
	}

	public int x_to_index(double x) {
		int index, trailing;
		layout.get_line_readonly(0).x_to_index(Pango.units_from_double(x), out index, out trailing);
		for (; trailing > 0; trailing--) {
			layout.get_text().get_next_char(ref index, null);
		}
		return index;
	}
}

}
