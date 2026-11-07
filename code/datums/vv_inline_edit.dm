// View Variables can edit a var in the page, next to E, C and M. Click a number, text, path, flags or null value and an
// editor opens in its row with a field that fits it: a text box, the flags as checkboxes, or the eight directions for dir.
// Enter sets it and Esc closes it. "as" picks what it's set to: a number, text, a type path, null, the default, or the marked
// datum, and "Other..." opens the usual C prompts. "all <type>" sets it on everything of exactly that type.
// Also here: the page's handlers for undo, default and set, which all edit a var from a link in the page.

/// What kind of value a var holds, for the page's editor. Only null, num, bitfield, text, message and path can be edited there
/proc/vv_value_kind(var_name, value)
	if(isnull(value))
		return "null"
	if(isnum(value))
		return (var_name in GLOB.bitfields) ? "bitfield" : "num"
	if(istext(value))
		return findtext(value, "\n") ? "message" : "text"
	if(ispath(value))
		return "path"
	return "other"

/// The attributes the page's editor reads from a var's row
/proc/vv_editor_attrs(var_name, value)
	var/kind = vv_value_kind(var_name, value)
	. = " data-var='[var_name]' data-kind='[kind]'"
	switch(kind)
		if("num", "path")
			. += " data-raw=\"[value]\""
		if("bitfield")
			. += " data-raw=\"[value]\" data-bits=\"[html_encode(json_encode(GLOB.bitfields[var_name]))]\""
		if("text", "message")
			. += " data-raw=\"[html_encode(value)]\""

/// The page's editor: its styles, and the script that opens it in a row and sends the new value
/proc/vv_editor_head(datum/D, client/C)
	var/datum/marked = C?.holder?.marked_datum
	return {"
		<style>
			li\[data-kind=null\] > .value, li\[data-kind=num\] > .value, li\[data-kind=bitfield\] > .value,
			li\[data-kind=text\] > .value, li\[data-kind=message\] > .value, li\[data-kind=path\] > .value { cursor: pointer; }
			li\[data-kind=null\] > .value:hover, li\[data-kind=num\] > .value:hover, li\[data-kind=bitfield\] > .value:hover,
			li\[data-kind=text\] > .value:hover, li\[data-kind=message\] > .value:hover, li\[data-kind=path\] > .value:hover { background-color: #ffffcc; }
			li .vva { visibility: hidden; font-size: 7pt; margin-left: 6px; }
			li:hover > .vva { visibility: visible; }
			.vve { margin: 3px 0 5px 12px; padding: 4px 6px; border: 1px solid #cccccc; background-color: #f6f6f6; font-size: 8pt; }
			.vve input\[type=text\], .vve textarea { width: 70%; font-family: "Courier New", monospace; font-size: 8pt; }
			.vve .vvc td { padding: 0; }
			.vve .vvc button { width: 30px; font-size: 7pt; }
			.vve .vvc button.on { font-weight: bold; background-color: #ffe08a; }
			.vve label { margin-right: 8px; white-space: nowrap; }
		</style>
		<script type='text/javascript'>
			var vv_target = '[D.UID()]';
			var vv_type = '[D.type]';
			var vv_marked = [json_encode(marked ? "[marked]" : "")];
			var vv_dirs = \[\['NW', 9\], \['N', 1\], \['NE', 5\], \['W', 8\], \['', 0\], \['E', 4\], \['SW', 10\], \['S', 2\], \['SE', 6\]\];
			var vv_editable = { 'null': 1, 'num': 1, 'bitfield': 1, 'text': 1, 'message': 1, 'path': 1 };

			function vv_send(name, value_class, value, mass) {
				location.href = vv_link('byond://?_src_=vars;vvset=' + vv_target + ';varname=' + encodeURIComponent(name)
					+ ';vvclass=' + value_class + ';vvvalue=' + encodeURIComponent(value) + (mass ? ';vvmass=1' : ''), false);
			}
			function vv_close_editors() {
				var open = document.querySelectorAll('.vve');
				for (var i = 0; i < open.length; i++) open\[i\].parentNode.removeChild(open\[i\]);
			}
			function vv_open(li) {
				if (li.querySelector('.vve')) return;
				vv_close_editors();
				var name = li.getAttribute('data-var');
				var kind = li.getAttribute('data-kind');
				var raw = li.getAttribute('data-raw');
				var editor = document.createElement('div');
				editor.className = 'vve';
				var field = null;
				var get = null;
				var mass = document.createElement('input');
				mass.type = 'checkbox';
				var value_class = { num: 'num', bitfield: 'num', text: 'text', message: 'text', path: 'path' }\[kind\] || 'text';
				if (kind == 'bitfield') {
					var bits = JSON.parse(li.getAttribute('data-bits'));
					var number = parseInt(raw, 10) || 0;
					field = document.createElement('div');
					for (var flag in bits) {
						var label = document.createElement('label');
						var box = document.createElement('input');
						box.type = 'checkbox';
						box.value = bits\[flag\];
						box.checked = (number & bits\[flag\]) != 0;
						label.appendChild(box);
						label.appendChild(document.createTextNode(flag));
						field.appendChild(label);
					}
					get = function () { var n = 0; var boxes = field.querySelectorAll('input'); for (var j = 0; j < boxes.length; j++) if (boxes\[j\].checked) n |= parseInt(boxes\[j\].value, 10); return String(n); };
				} else if (name == 'dir' && kind == 'num') {
					var current = parseInt(raw, 10);
					field = document.createElement('table');
					field.className = 'vvc';
					for (var r = 0; r < 3; r++) {
						var tr = field.insertRow(-1);
						for (var c = 0; c < 3; c++) {
							var dir = vv_dirs\[r * 3 + c\];
							var td = tr.insertCell(-1);
							if (!dir\[1\]) continue;
							var button = document.createElement('button');
							button.textContent = dir\[0\];
							button.setAttribute('data-dir', dir\[1\]);
							if (dir\[1\] == current) button.className = 'on';
							button.onclick = function () { vv_send(name, 'num', this.getAttribute('data-dir'), mass.checked); return false; };
							td.appendChild(button);
						}
					}
					get = function () { return String(current); };
				} else {
					field = document.createElement(kind == 'message' ? 'textarea' : 'input');
					if (kind != 'message') field.type = 'text';
					field.value = (raw === null) ? '' : raw;
					get = function () { return field.value; };
				}
				editor.appendChild(field);
				var row = document.createElement('div');
				var type = document.createElement('select');
				var kinds = \[\['num', 'Number'\], \['text', 'Text'\], \['path', 'Type path'\], \['null', 'null'\], \['default', 'Default'\]\];
				if (vv_marked) kinds.push(\['marked', 'Marked: ' + vv_marked\]);
				kinds.push(\['other', 'Other...'\]);
				for (var k = 0; k < kinds.length; k++) {
					var option = document.createElement('option');
					option.value = kinds\[k\]\[0\];
					option.textContent = kinds\[k\]\[1\];
					if (kinds\[k\]\[0\] == value_class) option.selected = true;
					type.appendChild(option);
				}
				row.appendChild(document.createTextNode('as '));
				row.appendChild(type);
				var mass_label = document.createElement('label');
				mass_label.appendChild(mass);
				mass_label.appendChild(document.createTextNode(' all ' + vv_type));
				row.appendChild(document.createTextNode(' '));
				row.appendChild(mass_label);
				var apply = document.createElement('button');
				apply.textContent = 'Set';
				var cancel = document.createElement('button');
				cancel.textContent = 'Cancel';
				row.appendChild(apply);
				row.appendChild(cancel);
				editor.appendChild(row);
				function go() {
					var picked = type.value;
					if (picked == 'other') {
						location.href = vv_link('byond://?_src_=vars;datumchange=' + vv_target + ';varnamechange=' + encodeURIComponent(name), false);
						return;
					}
					vv_send(name, picked, (picked == 'null' || picked == 'default' || picked == 'marked') ? '' : get(), mass.checked);
				}
				apply.onclick = function () { go(); return false; };
				cancel.onclick = function () { vv_close_editors(); return false; };
				editor.onkeydown = function (e) {
					if (e.keyCode == 27) { vv_close_editors(); return false; }
					if (e.keyCode == 13 && !(kind == 'message' && e.shiftKey)) { go(); return false; }
					e.stopPropagation();
					return true;
				};
				editor.onkeyup = function (e) { e.stopPropagation(); };
				li.appendChild(editor);
				if (editor.scrollIntoView) editor.scrollIntoView({ block: 'nearest' });
				if (field.focus) { field.focus(); if (field.select) field.select(); }
			}
			// A click on a plain value opens the editor in its row
			document.addEventListener('click', function (e) {
				var value = e.target;
				while (value && value.nodeType == 1 && !(value.className == 'value' && value.parentNode && value.parentNode.getAttribute && value.parentNode.getAttribute('data-var'))) value = value.parentNode;
				if (!value || value.nodeType != 1) return;
				var li = value.parentNode;
				if (!vv_editable\[li.getAttribute('data-kind')\]) return;
				e.preventDefault();
				vv_open(li);
			}, false);
		</script>
	"}

/// Sets a var from the page's editor: what was typed, as the picked type, on this thing or on everything of exactly its type
/client/proc/vv_inline_set(datum/D, var_name, value_class, text, mass)
	if(!istype(D) || !(var_name in D.vars) || !D.can_vv_get(var_name) || !vv_varname_lockcheck(var_name))
		return FALSE
	var/value
	switch(value_class)
		if("num")
			value = text2num(text)
			if(isnull(value))
				to_chat(src, SPAN_WARNING("\"[html_encode(text)]\" isn't a number."))
				return FALSE
		if("text")
			value = text
		if("path")
			value = text2path(trim(text))
			if(!value)
				to_chat(src, SPAN_WARNING("There's no type [html_encode(text)]."))
				return FALSE
		if("null")
			value = null
		if("default")
			value = initial(D.vars[var_name])
		if("marked")
			value = holder?.marked_datum
			if(!value)
				to_chat(src, SPAN_WARNING("Nothing is marked."))
				return FALSE
		else
			return FALSE
	if(mass)
		return vv_inline_mass(D, var_name, value)
	var/old_value = D.vars[var_name]
	if(!D.vv_edit_var(var_name, value))
		to_chat(src, SPAN_WARNING("The object refused the edit."))
		return FALSE
	vv_note_edit(D, var_name, old_value, src)
	vv_log_change(D, var_name, old_value, value, "modified")
	return TRUE

/// Sets a var on everything of exactly D's type
/client/proc/vv_inline_mass(datum/D, var_name, value)
	var/accepted = 0
	var/rejected = 0
	for(var/datum/thing as anything in get_all_of_type(D.type, FALSE))
		if(QDELETED(thing) || !(var_name in thing.vars))
			continue
		var/old_value = thing.vars[var_name]
		if(thing.vv_edit_var(var_name, value))
			accepted++
			if(thing == D)
				vv_note_edit(D, var_name, old_value, src)
		else
			rejected++
		CHECK_TICK
	log_world("### MassVarEdit by [src]: [D.type] (exact type) [var_name]=[html_encode("[value]")] ([accepted] changed, [rejected] refused)")
	log_admin("[key_name(src)] mass modified every [D.type]'s [var_name] to [value] ([accepted] objects modified)")
	message_admins("[key_name_admin(src)] mass modified every [D.type]'s [var_name] to [html_encode("[value]")] ([accepted] objects modified)")
	to_chat(src, SPAN_NOTICE("[accepted] [D.type] changed[rejected ? ", [rejected] refused the edit" : ""]."))
	return accepted > 0

/// The page's own edit links: undo, put back the default, and set from the editor. Then the row shows the new value
/client/proc/vv_page_edit(list/href_list)
	var/uid = href_list["vvundo"] || href_list["vvdefault"] || href_list["vvset"]
	var/datum/D = locateUID(uid)
	var/var_name = href_list["varname"]
	if(!isdatum(D) || !var_name || !check_rights(R_VAREDIT))
		return
	if(href_list["vvundo"])
		vv_undo_var(D, var_name)
	else if(href_list["vvdefault"])
		vv_restore_default(D, var_name)
	else
		vv_inline_set(D, var_name, href_list["vvclass"], href_list["vvvalue"], href_list["vvmass"])
	vv_refresh_var(D, var_name)
