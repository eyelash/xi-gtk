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
	private Pango.AttrList text_attributes;
	private uint[] selection_ranges;

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

	private void apply_style_to_range(Pango.AttrList attributes, Style style, uint start, uint end) {
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
	}

	public void set_styles(Json.Array styles) {
		StyleMap style_map = StyleMap.get_instance();
		selection_ranges = {};
		text_attributes = new Pango.AttrList();
		uint offset = 0;
		for (int i = 0; i < styles.get_length(); i += 3) {
			uint start = offset + (uint)styles.get_int_element(i);
			uint end = start + (uint)styles.get_int_element(i+1);
			offset = end;

			int style_id = (int)styles.get_int_element(i+2);

			// add selections to selection array to defer conversion to Pango.AttrList until draw-time
			if (style_id == 0) {
				selection_ranges += start;
				selection_ranges += end;
				continue;
			}

			Style style = style_map.get_style(style_id);
			apply_style_to_range(text_attributes, style, start, end);
		}
	}

	public void draw(Cairo.Context cr, Gtk.StyleContext style_ctx, double x, double y, double width, double ascent, double line_height, bool draw_cursors) {
		var widget_state = style_ctx.get_state();
		var selected_state = widget_state | Gtk.StateFlags.SELECTED;
		// highlight line if it contains any cursors
		if (cursors.length > 0) {
			var color = style_ctx.get_background_color(selected_state);
			color.alpha /= 2;
			Gdk.cairo_set_source_rgba(cr, color);
			cr.rectangle(0, y, width, line_height);
			cr.fill();
		}
		cr.move_to(x, y + ascent);

		// create a style for the selection
		Style selected_style = Style() {
			background = style_ctx.get_background_color(selected_state),
			foreground = style_ctx.get_color(selected_state)
		};
		// merge selection with existing text attributes
		var new_attributes = text_attributes.copy();
		for (var i = 0; i < selection_ranges.length; i+=2) {
			var start = selection_ranges[i];
			var end = selection_ranges[i+1];
			apply_style_to_range(new_attributes, selected_style, start, end);
		}
		// draw text
		Gdk.cairo_set_source_rgba(cr, style_ctx.get_color(widget_state));
		layout.set_attributes(new_attributes);
		Pango.cairo_show_layout_line(cr, layout.get_line_readonly(0));

		// draw cursors themselves
		if (draw_cursors) {
			foreach (double cursor in cursors) {
				cr.rectangle(x + cursor, y, 1, line_height);
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
