//! Spritesheets for UIs, built by iconforge (tgstation's icon library, the one rust-g uses).

use byondapi::value::ByondValue;
use eyre::eyre;
use iconforge::core::{image_cache, spritesheet, universal_icon::UniversalIcon};
use indexmap::IndexMap;

const NORTH: u8 = 1;
const SOUTH: u8 = 2;
const EAST: u8 = 4;
const WEST: u8 = 8;

/// Builds the PNGs for one spritesheet into `file_path` and returns iconforge's JSON: the sizes, where each sprite went, and any errors.
/// `sprites` is a JSON object of sprite name -> icon file, state, dir, frame and transforms.
#[byondapi::bind]
fn iconforge_generate(
    file_path: ByondValue,
    spritesheet_name: ByondValue,
    sprites: ByondValue,
) -> eyre::Result<ByondValue> {
    let file_path = file_path.get_string()?;
    let spritesheet_name = spritesheet_name.get_string()?;
    let sprites = sprites.get_string()?;
    // iconforge leaves rayon's threads running in the library
    crate::library::keep_loaded();
    let result = std::panic::catch_unwind(|| generate(&file_path, &spritesheet_name, &sprites))
        .unwrap_or_else(|_| Err(eyre!("iconforge panicked building {spritesheet_name}")));
    // iconforge keeps every file and image it loaded. Each sheet is only built once, so let them go.
    image_cache::icon_cache_clear();
    image_cache::image_cache_clear();
    Ok(ByondValue::new_str(result?)?)
}

fn generate(file_path: &str, spritesheet_name: &str, sprites: &str) -> eyre::Result<String> {
    let sprites: IndexMap<String, UniversalIcon> = serde_json::from_str(sprites)?;
    let sprites: IndexMap<String, UniversalIcon> = sprites
        .into_iter()
        .filter(|(_, icon)| in_its_file(icon))
        .collect();
    Ok(spritesheet::spritesheet_multisize_from_universal_icons_str(
        file_path,
        spritesheet_name,
        &serde_json::to_string(&sprites)?,
        "0",
        "0",
        "1",
    )?)
}

/// BYOND's icon() gives back nothing for a state, dir or frame the file doesn't have, and those sprites were left out.
/// iconforge calls them errors, so they're left out here first. A file that can't be read is left for iconforge to report.
fn in_its_file(icon: &UniversalIcon) -> bool {
    let Ok(dmi) = image_cache::filepath_to_dmi(&icon.icon_file) else {
        return true;
    };
    let Some(state) = dmi
        .states
        .iter()
        .find(|state| state.name == icon.icon_state)
    else {
        return false;
    };
    if icon.frame.is_some_and(|frame| frame > state.frames) {
        return false;
    }
    match icon.dir {
        None | Some(0) => true,
        Some(dir) => match state.dirs {
            1 => dir == SOUTH,
            4 => [NORTH, SOUTH, EAST, WEST].contains(&dir),
            _ => true,
        },
    }
}
