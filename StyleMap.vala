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

}
