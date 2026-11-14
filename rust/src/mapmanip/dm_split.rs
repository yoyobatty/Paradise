//! Splits a map's tile definitions the way the DM map loader does (code/modules/awaymissions/maploader/reader.dm),
//! so it doesn't have to do it in DM, which is slow.
//!
//! This copies the DM code step by step, quirks included, working on the same text DM would see: the definition
//! as `save_tgm()` writes it. That way DM gets exactly the strings it would have cut out itself, and still turns
//! paths and values into the real thing with its own code.

use dmmtools::dmm::Prefab;

/// Where a piece of the tile definition's text is, as DM `copytext()` positions: 1-based, end not included
pub(crate) type TextRange = (usize, usize);

/// One atom in a tile definition: where its path is, and its vars if it has a `{...}` block.
pub(crate) struct SplitMember {
    pub path: TextRange,
    pub vars: Option<Vec<SplitVar>>,
}

/// One entry of a `{...}` block: `name = value`, or just `value`.
pub(crate) struct SplitVar {
    pub name: Option<TextRange>,
    pub value: TextRange,
}

/// Where `part`, a slice of `whole`, is in it
fn range_in(whole: &[u8], part: &[u8]) -> TextRange {
    let start = part.as_ptr() as usize - whole.as_ptr() as usize + 1;
    (start, start + part.len())
}

/// The text the DM loader reads for a tile definition, between `"key" = (` and the closing `)`, as `save_tgm()` writes it.
pub(crate) fn model_text(prefabs: &[Prefab]) -> String {
    let mut text = String::from("\n");
    for (i, fab) in prefabs.iter().enumerate() {
        text.push_str(&fab.path);
        if !fab.vars.is_empty() {
            text.push('{');
            for (j, (var, value)) in fab.vars.iter().enumerate() {
                text.push_str(&format!("\n\t{} = {}", var, value));
                if j + 1 != fab.vars.len() {
                    text.push(';');
                }
            }
            text.push_str("\n\t}");
        }
        if i + 1 != prefabs.len() {
            text.push_str(",\n");
        }
    }
    text
}

/// What `/datum/dmm_suite/proc/parse_grid()` makes of a tile definition, before turning the text into paths and values.
pub(crate) fn split_model(model: &str) -> Vec<SplitMember> {
    let model = model.as_bytes();
    let whole = model;
    let mut members = vec![];
    let mut old_position = 1;
    loop {
        let dpos = find_next_delimiter_position(model, old_position, b',', b'{', b'}');
        let full_def = trim_text(copytext(model, old_position, dpos), false);
        let variables_start = findtext(full_def, b'{', 1, 0);
        let atom_text = trim_text(copytext(full_def, 1, variables_start), false);
        old_position = dpos + 1;

        let vars = if variables_start != 0 {
            // Removes the last character, the closing brace
            let var_text = copytext(full_def, variables_start + 1, full_def.len());
            Some(readlist(whole, var_text, b';'))
        } else {
            None
        };
        members.push(SplitMember {
            path: range_in(whole, atom_text),
            vars,
        });

        if dpos == 0 {
            break;
        }
    }
    members
}

/// `/datum/dmm_suite/proc/readlist()`, up to where it parses each value
fn readlist(whole: &[u8], text: &[u8], delimiter: u8) -> Vec<SplitVar> {
    let mut entries = vec![];
    let mut old_position = 1;
    loop {
        let delimiter_position =
            find_next_delimiter_position(text, old_position, delimiter, b'"', b'"');
        let equal_position = findtext(text, b'=', old_position, delimiter_position);
        let left_end = if equal_position != 0 {
            equal_position
        } else {
            delimiter_position
        };
        let left_value = copytext(text, old_position, left_end);
        old_position = delimiter_position + 1;

        if equal_position != 0 {
            entries.push(SplitVar {
                name: Some(range_in(whole, trim_text(left_value, true))),
                value: range_in(
                    whole,
                    trim_text(
                        copytext(text, equal_position + 1, delimiter_position),
                        false,
                    ),
                ),
            });
        } else {
            entries.push(SplitVar {
                name: None,
                value: range_in(whole, trim_text(left_value, false)),
            });
        }

        if delimiter_position == 0 {
            break;
        }
    }
    entries
}

/// `/datum/dmm_suite/proc/find_next_delimiter_position()`. Positions are 1-based like DM's, 0 is not found.
fn find_next_delimiter_position(
    text: &[u8],
    initial_position: usize,
    delimiter: u8,
    opening_escape: u8,
    closing_escape: u8,
) -> usize {
    let mut position = initial_position;
    let mut next_delimiter = findtext(text, delimiter, position, 0);
    let mut next_opening = findtext(text, opening_escape, position, 0);
    // DM loops forever on an escape that's never closed. Maps that load don't have one, but don't hang if one shows up.
    let mut guard = text.len() + 2;
    while next_opening != 0 && next_opening < next_delimiter && guard > 0 {
        guard -= 1;
        position = findtext(text, closing_escape, next_opening + 1, 0) + 1;
        next_delimiter = findtext(text, delimiter, position, 0);
        next_opening = findtext(text, opening_escape, position, 0);
    }
    next_delimiter
}

/// DM's `findtext()` for a single character: 1-based, `end` is exclusive and 0 means the end of the text, 0 is not found.
fn findtext(text: &[u8], needle: u8, start: usize, end: usize) -> usize {
    let start = start.max(1);
    let end = if end == 0 || end > text.len() + 1 {
        text.len() + 1
    } else {
        end
    };
    if start >= end {
        return 0;
    }
    text[start - 1..end - 1]
        .iter()
        .position(|&c| c == needle)
        .map_or(0, |i| start + i)
}

/// DM's `copytext()`: 1-based, `end` is exclusive and 0 means the end of the text.
fn copytext(text: &[u8], start: usize, end: usize) -> &[u8] {
    let start = start.max(1);
    let end = if end == 0 || end > text.len() + 1 {
        text.len() + 1
    } else {
        end
    };
    if start >= end {
        // Still a slice of the text, so its position means something
        let at = (start - 1).min(text.len());
        return &text[at..at];
    }
    &text[start - 1..end - 1]
}

/// What BYOND's regex `\s` matches
fn is_space(c: u8) -> bool {
    matches!(c, b' ' | b'\t' | b'\n' | b'\r' | 0x0b | 0x0c)
}

/// `/datum/dmm_suite/proc/trim_text()`. Without quotes that's `^[\s\n]+|[\s\n]+$`, with them `^[\s\n]+"?|"?[\s\n]+$|^"|"$`.
fn trim_text(text: &[u8], trim_quotes: bool) -> &[u8] {
    let mut start = 0;
    let mut end = text.len();
    while start < end && is_space(text[start]) {
        start += 1;
    }
    let leading_space = start > 0;
    if trim_quotes {
        if leading_space {
            // ^[\s\n]+"?
            if start < end && text[start] == b'"' {
                start += 1;
            }
        } else if start < end && text[start] == b'"' {
            // ^"
            start += 1;
        }
    }
    let space_end = end;
    while end > start && is_space(text[end - 1]) {
        end -= 1;
    }
    if trim_quotes {
        if end < space_end {
            // "?[\s\n]+$
            if end > start && text[end - 1] == b'"' {
                end -= 1;
            }
        } else if end > start && text[end - 1] == b'"' {
            // "$
            end -= 1;
        }
    }
    &text[start..end]
}

#[cfg(test)]
mod tests {
    use super::*;

    fn split(model: &str) -> Vec<(String, Option<Vec<(Option<String>, String)>>)> {
        let text = |r: TextRange| model[r.0 - 1..r.1 - 1].to_string();
        split_model(model)
            .into_iter()
            .map(|m| {
                (
                    text(m.path),
                    m.vars.map(|v| {
                        v.into_iter()
                            .map(|e| (e.name.map(text), text(e.value)))
                            .collect()
                    }),
                )
            })
            .collect()
    }

    #[test]
    fn plain_members() {
        assert_eq!(
            split("\n/turf/simulated/floor,\n/area/station/hallway"),
            vec![
                ("/turf/simulated/floor".into(), None),
                ("/area/station/hallway".into(), None)
            ]
        );
    }

    #[test]
    fn members_with_vars() {
        assert_eq!(
            split("\n/obj/item{\n\tname = \"a, b; c = d\";\n\tdir = 4\n\t},\n/turf/space,\n/area/space"),
            vec![
                (
                    "/obj/item".into(),
                    Some(vec![(Some("name".into()), "\"a, b; c = d\"".into()), (Some("dir".into()), "4".into())])
                ),
                ("/turf/space".into(), None),
                ("/area/space".into(), None),
            ]
        );
    }

    #[test]
    fn lists_and_quoted_names() {
        assert_eq!(
            split("\n/obj/x{\n\tlist_var = list(\"a\" = 1, \"b\" = 2)\n\t}"),
            vec![(
                "/obj/x".into(),
                Some(vec![(
                    Some("list_var".into()),
                    "list(\"a\" = 1, \"b\" = 2)".into()
                )])
            )]
        );
        assert_eq!(trim_text(b"  \"name\"  ", true), b"name");
        assert_eq!(trim_text(b"\"name\"", true), b"name");
        assert_eq!(trim_text(b"name\"", true), b"name");
        assert_eq!(trim_text(b"   ", true), b"");
    }
}
