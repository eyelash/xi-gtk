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

class Theme {
	private static Theme instance;
	public Gdk.RGBA foreground;
	public Gdk.RGBA background;
	public Gdk.RGBA caret;
	public Gdk.RGBA line_highlight;
	public Gdk.RGBA selection;
	public Gdk.RGBA gutter;
	public Gdk.RGBA gutter_foreground;
	public Gdk.RGBA find_highlight;
	public Gdk.RGBA find_highlight_foreground;

	public static Theme get_instance() {
		if (instance == null) {
			instance = new Theme();
		}
		return instance;
	}

	private static Gdk.RGBA decode_color(Json.Object theme, string color_name) {
		if (!theme.has_member(color_name)) {
			return Gdk.RGBA();
		}
		var color = theme.get_object_member(color_name);
		if (color == null) {
			return Gdk.RGBA();
		}
		int64 r = color.get_int_member("r");
		int64 g = color.get_int_member("g");
		int64 b = color.get_int_member("b");
		int64 a = color.get_int_member("a");
		return Gdk.RGBA() {
			red = r / 255.0,
			green = g / 255.0,
			blue = b / 255.0,
			alpha = a / 255.0
		};
	}

	public void set_from_json(Json.Object theme) {
		foreground = decode_color(theme, "foreground");
		background = decode_color(theme, "background");
		caret = decode_color(theme, "caret");
		line_highlight = decode_color(theme, "line_highlight");
		selection = decode_color(theme, "selection");
		gutter = decode_color(theme, "gutter");
		gutter_foreground = decode_color(theme, "gutter_foreground");
		find_highlight = decode_color(theme, "find_highlight");
		find_highlight_foreground = decode_color(theme, "find_highlight_foreground");
	}
}

}
