// Copyright 2016-2018 Elias Aebi
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
	private Subprocess core_process;
	private int id;
	private class ResponseHandler {
		public SourceFunc callback;
		public Json.Node result;
	}
	private HashTable<int, ResponseHandler> response_handlers;

	[Signal(detailed = true)]
	public signal void update_received(Json.Object update);
	[Signal(detailed = true)]
	public signal void scroll_to_received(int64 line, int64 col);
	public signal void def_style_received(Json.Object params);
	public signal void theme_changed_received(string name, Json.Object theme);
	public signal void alert_received(string msg);

	private void send(Json.Object root) {
		var root_node = new Json.Node(Json.NodeType.OBJECT);
		root_node.set_object(root);
		var generator = new Json.Generator();
		generator.set_root(root_node);
		var core_stdin = core_process.get_stdin_pipe();
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

	private async Json.Node send_request(string method, Json.Object params) {
		var response_handler = new ResponseHandler();
		response_handler.callback = send_request.callback;
		response_handlers[id] = response_handler;
		var root = new Json.Object();
		root.set_int_member("id", id++);
		root.set_string_member("method", method);
		root.set_object_member("params", params);
		send(root);
		yield;
		return response_handler.result;
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

	private async Json.Node send_edit_request(string view_id, string method, Json.Object edit_params) {
		var params = new Json.Object();
		params.set_string_member("method", method);
		params.set_string_member("view_id", view_id);
		params.set_object_member("params", edit_params);
		return yield send_request("edit", params);
	}

	public void send_client_started(string config_dir, string client_extras_dir) {
		var params = new Json.Object();
		params.set_string_member("config_dir", config_dir);
		params.set_string_member("client_extras_dir", client_extras_dir);
		send_notification("client_started", params);
	}

	public async string send_new_view(string? file_path) {
		var params = new Json.Object();
		if (file_path != null) {
			params.set_string_member("file_path", file_path);
		}
		var result = yield send_request("new_view", params);
		return result.get_string();
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

	public void send_paste(string view_id, string chars) {
		var params = new Json.Object();
		params.set_string_member("chars", chars);
		send_edit(view_id, "paste", params);
	}

	public async string send_copy(string view_id) {
		var result = yield send_edit_request(view_id, "copy", new Json.Object());
		return result.get_string();
	}

	public async string send_cut(string view_id) {
		var result = yield send_edit_request(view_id, "cut", new Json.Object());
		return result.get_string();
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

	public void send_find(string view_id, string chars, bool case_sensitive, bool regex, bool whole_words) {
		var params = new Json.Object();
		params.set_string_member("chars", chars);
		params.set_boolean_member("case_sensitive", case_sensitive);
		params.set_boolean_member("regex", regex);
		params.set_boolean_member("whole_words", whole_words);
		send_edit(view_id, "find", params);
	}
	public void send_find_next(string view_id, bool wrap_around, bool allow_same, string modify_selection) {
		var params = new Json.Object();
		params.set_boolean_member("wrap_around", wrap_around);
		params.set_boolean_member("allow_same", allow_same);
		params.set_string_member("modify_selection", modify_selection);
		send_edit(view_id, "find_next", params);
	}
	public void send_find_previous(string view_id, bool wrap_around, bool allow_same, string modify_selection) {
		var params = new Json.Object();
		params.set_boolean_member("wrap_around", wrap_around);
		params.set_boolean_member("allow_same", allow_same);
		params.set_string_member("modify_selection", modify_selection);
		send_edit(view_id, "find_previous", params);
	}
	public void send_replace(string view_id, string chars) {
		var params = new Json.Object();
		params.set_string_member("chars", chars);
		send_edit(view_id, "replace", params);
	}
	public void send_highlight_find(string view_id, bool visible) {
		var params = new Json.Object();
		params.set_boolean_member("visible", visible);
		send_edit(view_id, "highlight_find", params);
	}
	public void send_selection_for_find(string view_id, bool case_sensitive) {
		var params = new Json.Object();
		params.set_boolean_member("case_sensitive", case_sensitive);
		send_edit(view_id, "selection_for_find", params);
	}

	private void receive_response(Json.Object root) {
		int id = (int)root.get_int_member("id");
		var handler = response_handlers[id];
		if (handler != null) {
			response_handlers.remove(id);
			handler.result = root.get_member("result");
			handler.callback();
		}
	}

	private void receive_notification(Json.Object root) {
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
				int64 scroll_to_line = params.get_int_member("line");
				int64 scroll_to_col = params.get_int_member("col");
				scroll_to_received[view_id](scroll_to_line, scroll_to_col);
				break;
			case "def_style":
				def_style_received(params);
				break;
			case "config_changed":
				// TODO: implement
				break;
			case "available_themes":
				// TODO: implement
				break;
			case "theme_changed":
				var name = params.get_string_member("name");
				var theme = params.get_object_member("theme");
				theme_changed_received(name, theme);
				break;
			case "alert":
				var msg = params.get_string_member("msg");
				alert_received(msg);
				break;
		}
	}

	private async void receive() {
		try {
			var core_stdout = new DataInputStream(core_process.get_stdout_pipe());
			string? line = yield core_stdout.read_line_utf8_async(Priority.DEFAULT, null, null);
			while (line != null) {
				//stdout.printf("core to front-end: %s\n", line);
				var parser = new Json.Parser();
				parser.load_from_data(line);
				var root = parser.get_root().get_object();
				if (root.has_member("id")) {
					receive_response(root);
				} else {
					receive_notification(root);
				}
				line = yield core_stdout.read_line_utf8_async(Priority.DEFAULT, null, null);
			}
		} catch (Error error) {
			critical(error.message);
		}
	}

	public CoreConnection(string[] command) {
		response_handlers = new HashTable<int, ResponseHandler>(direct_hash, direct_equal);
		try {
			core_process = new Subprocess.newv(command, SubprocessFlags.STDIN_PIPE | SubprocessFlags.STDOUT_PIPE);
			receive.begin();
		} catch (Error error) {
			critical(error.message);
		}
	}
}

}
