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

class Blinker {
	private uint interval;
	private TimeoutSource source;
	private uint counter;

	public signal void redraw();

	public Blinker(uint interval) {
		this.interval = interval;
	}

	private bool blink() {
		counter++;
		redraw();
		return counter < 18;
	}

	public void stop() {
		if (source != null) {
			source.destroy();
		}
		counter = 0;
	}

	public void restart() {
		stop();
		source = new TimeoutSource(interval);
		source.set_callback(blink);
		source.attach(null);
	}

	public bool draw_cursor() {
		return counter % 2 == 0;
	}
}

}
