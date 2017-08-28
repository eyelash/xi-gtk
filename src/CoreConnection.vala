// Copyright 2016-2017 Elias Aebi
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

class CoreConnection {
	private Pid pid;
	private UnixOutputStream core_stdin;
	private DataInputStream core_stdout;
	private int id;
	public class ResponseHandler {
		public delegate void Delegate(Json.Node result);
		private Delegate d;
		public ResponseHandler(owned Delegate d) {
			this.d = (owned)d;
		}
		public void invoke(Json.Node result) {
			d(result);
		}
	}
	private HashTable<int, ResponseHandler> response_handlers;

	[Signal(detailed=true)]
	public signal void update_received(Json.Object update);
	[Signal(detailed=true)]
	public signal void scroll_to_received(int line, int col);
	public signal void def_style_received(Json.Object params);
	public signal void theme_changed_received(string name, Json.Object theme);

	private bool receive() {
		try {
			do {
				string line = core_stdout.read_line_utf8(null);
				//stdout.printf("core to front-end: %s\n", line);
				var parser = new Json.Parser();
				parser.load_from_data(line);
				var root = parser.get_root().get_object();
				if (root.has_member("id")) {
					// response
					int id = (int)root.get_int_member("id");
					var handler = response_handlers[id];
					if (handler != null) {
						var result = root.get_member("result");
						handler.invoke(result);
						response_handlers.remove(id);
					}
				} else {
					var method = root.get_string_member("method");
					var params = root.get_object_member("params");
					switch (method) {
						case "update":
							var view_id = params.get_string_member("view_id");
							var update = params.get_object_member("update");
							update_received[view_id](update);
							break;
						case "scroll_to":
							var view_id = params.get_string_member("view_id");
							var scroll_to_line = (int)params.get_int_member("line");
							var scroll_to_col = (int)params.get_int_member("col");
							scroll_to_received[view_id](scroll_to_line, scroll_to_col);
							break;
						case "def_style":
							def_style_received(params);
							break;
						case "theme_changed":
							var name = params.get_string_member("name");
							var theme = params.get_object_member("theme");
							theme_changed_received(name, theme);
							break;
						case "available_themes":
							// TODO: implement
							break;
					}
				}
			} while (core_stdout.get_available() > 0);
		} catch (Error error) {
			stderr.printf("error: %s\n", error.message);
		}
		return true;
	}

	private void send(Json.Object root) {
		var root_node = new Json.Node(Json.NodeType.OBJECT);
		root_node.set_object(root);
		var generator = new Json.Generator();
		generator.set_root(root_node);
		try {
			generator.to_stream(core_stdin);
			core_stdin.write("\n".data);
			core_stdin.flush();
			//stdout.printf("front-end to core: %s\n", generator.to_data(null));
		} catch (Error error) {
			critical(error.message);
		}
	}

	private void send_notification(string method, Json.Object params) {
		var root = new Json.Object();
		root.set_string_member("method", method);
		root.set_object_member("params", params);
		send(root);
	}

	private void send_request(string method, Json.Object params, ResponseHandler response_handler) {
		response_handlers[id] = response_handler;
		var root = new Json.Object();
		root.set_int_member("id", id++);
		root.set_string_member("method", method);
		root.set_object_member("params", params);
		send(root);
	}

	public void send_edit(string view_id, string method, Json.Object edit_params = new Json.Object()) {
		var params = new Json.Object();
		params.set_string_member("method", method);
		params.set_string_member("view_id", view_id);
		params.set_object_member("params", edit_params);
		send_notification("edit", params);
	}

	private void send_edit_array(string view_id, string method, Json.Array edit_params) {
		var params = new Json.Object();
		params.set_string_member("method", method);
		params.set_string_member("view_id", view_id);
		params.set_array_member("params", edit_params);
		send_notification("edit", params);
	}

	private void send_edit_request(string view_id, string method, Json.Object edit_params, ResponseHandler response_handler) {
		var params = new Json.Object();
		params.set_string_member("method", method);
		params.set_string_member("view_id", view_id);
		params.set_object_member("params", edit_params);
		send_request("edit", params, response_handler);
	}

	public void send_client_started() {
		send_notification("client_started", new Json.Object());
	}

	public void send_new_view(string? file_path, owned ResponseHandler.Delegate response_handler) {
		var params = new Json.Object();
		if (file_path != null) {
			params.set_string_member("file_path", file_path);
		}
		send_request("new_view", params, new ResponseHandler((owned)response_handler));
	}

	public void send_close_view(string view_id) {
		var params = new Json.Object();
		params.set_string_member("view_id", view_id);
		send_notification("close_view", params);
	}

	public void send_insert(string view_id, string chars) {
		var params = new Json.Object();
		params.set_string_member("chars", chars);
		send_edit(view_id, "insert", params);
	}

	public void send_copy(string view_id, owned ResponseHandler.Delegate response_handler) {
		send_edit_request(view_id, "copy", new Json.Object(), new ResponseHandler((owned)response_handler));
	}

	public void send_cut(string view_id, owned ResponseHandler.Delegate response_handler) {
		send_edit_request(view_id, "cut", new Json.Object(), new ResponseHandler((owned)response_handler));
	}

	public void send_save(string view_id, string file_path) {
		var params = new Json.Object();
		params.set_string_member("view_id", view_id);
		params.set_string_member("file_path", file_path);
		send_notification("save", params);
	}

	public void send_set_theme(string theme_name) {
		var params = new Json.Object();
		params.set_string_member("theme_name", theme_name);
		send_notification("set_theme", params);
	}

	public void send_scroll(string view_id, int64 first_line, int64 last_line) {
		var params = new Json.Array();
		params.add_int_element(first_line);
		params.add_int_element(last_line);
		send_edit_array(view_id, "scroll", params);
	}

	public void send_click(string view_id, int64 line, int64 column, int64 modifiers, int64 click_count) {
		var params = new Json.Array();
		params.add_int_element(line);
		params.add_int_element(column);
		params.add_int_element(modifiers);
		params.add_int_element(click_count);
		send_edit_array(view_id, "click", params);
	}

	public void send_drag(string view_id, int64 line, int64 column, int64 modifiers) {
		var params = new Json.Array();
		params.add_int_element(line);
		params.add_int_element(column);
		params.add_int_element(modifiers);
		send_edit_array(view_id, "drag", params);
	}

	/*public void send_request_lines(string tab, int64 first_line, int64 last_line) {
		var params = new Json.Array();
		params.add_int_element(first_line);
		params.add_int_element(last_line);
		send_edit_array(tab, "request_lines", params);
	}*/

	public void send_gesture(string view_id, int64 line, int64 col, string ty) {
		var params = new Json.Object();
		params.set_int_member("line", line);
		params.set_int_member("col", col);
		params.set_string_member("ty", ty);
		send_edit(view_id, "gesture", params);
	}

	private static DataInputStream create_input_stream(int fd, owned PollableSourceFunc func) {
		var stream = new UnixInputStream(fd, true);
		var source = stream.create_source();
		source.set_callback((owned)func);
		source.attach(null);
		return new DataInputStream(stream);
	}

	public CoreConnection(string[] command) {
		response_handlers = new HashTable<int, ResponseHandler>(direct_hash, direct_equal);
		try {
			int core_stdin_fd, core_stdout_fd;
			Process.spawn_async_with_pipes(null, command, null, SpawnFlags.SEARCH_PATH, null, out pid, out core_stdin_fd, out core_stdout_fd, null);
			core_stdin = new UnixOutputStream(core_stdin_fd, true);
			core_stdout = create_input_stream(core_stdout_fd, receive);
		} catch (SpawnError error) {
			stderr.printf("spawn error: %s\n", error.message);
		}
	}
}

}
