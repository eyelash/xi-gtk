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

class Utilities {
	public static Gdk.RGBA convert_color(uint32 color) {
		return Gdk.RGBA() {
			red = ((color >> 16) & 0xFF) / 255.0,
			green = ((color >> 8) & 0xFF) / 255.0,
			blue = (color & 0xFF) / 255.0,
			alpha = ((color >> 24) & 0xFF) / 255.0
		};
	}
}

}
