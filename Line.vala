// Copyright 2017 Elias Aebi
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
	private Pango.Layout layout;
	private double[] cursors;

	public Line(Pango.Context context, string text, Pango.FontDescription font_description) {
		layout = new Pango.Layout(context);
		layout.set_text(text, -1);
		layout.set_font_description(font_description);
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
		attributes.change((owned)attribute);
		attribute = Pango.attr_foreground_alpha_new((uint16)(color.alpha*uint16.MAX));
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
	}

	private static void set_background(Pango.AttrList attributes, uint start_index, uint end_index, Gdk.RGBA color) {
		var attribute = Pango.attr_background_new((uint16)(color.red*uint16.MAX), (uint16)(color.green*uint16.MAX), (uint16)(color.blue*uint16.MAX));
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
		attribute = Pango.attr_background_alpha_new((uint16)(color.alpha*uint16.MAX));
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
	}

	private static void set_weight(Pango.AttrList attributes, uint start_index, uint end_index, Pango.Weight weight) {
		var attribute = Pango.attr_weight_new(weight);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
	}

	/*private static void set_underline(Pango.AttrList attributes, uint start_index, uint end_index) {
		var attribute = Pango.attr_underline_new(Pango.Underline.SINGLE);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
	}*/

	private static void set_italic(Pango.AttrList attributes, uint start_index, uint end_index) {
		var attribute = Pango.attr_style_new(Pango.Style.ITALIC);
		attribute.start_index = start_index;
		attribute.end_index = end_index;
		attributes.change((owned)attribute);
	}

	public void set_styles(Json.Array styles) {
		var attributes = new Pango.AttrList();
		uint offset = 0;
		for (int i = 0; i < styles.get_length(); i += 3) {
			uint start = offset + (uint)styles.get_int_element(i);
			uint end = start + (uint)styles.get_int_element(i+1);
			int style_id = (int)styles.get_int_element(i+2);
			Style style = StyleMap.get_instance().get_style(style_id);
			if (style.foreground != null) {
				set_foreground(attributes, start, end, style.foreground);
			}
			if (style.background != null) {
				set_background(attributes, start, end, style.background);
			}
			if (style.weight != null) {
				set_weight(attributes, start, end, style.weight);
			}
			if (style.italic) {
				set_italic(attributes, start, end);
			}
			offset = end;
		}
		layout.set_attributes(attributes);
	}

	public void draw(Cairo.Context cr, double y, double width, double ascent, double line_height, bool draw_cursors) {
		if (cursors.length > 0) {
			Gdk.cairo_set_source_rgba(cr, Utilities.convert_color(0xfff5f5f5u));
			cr.rectangle(0, y, width, line_height);
			cr.fill();
		}
		Gdk.cairo_set_source_rgba(cr, Utilities.convert_color(0xff323232u));
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

}
