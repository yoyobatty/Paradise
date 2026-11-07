//! What a light can see, worked out the way BYOND's view() does it, from the turfs the engine knows block light.
//!
//! update_corners() only uses the turfs that don't block light, and it lights its own turf up enough that view() sees the
//! whole square lit. So of the steps in BYOND's view() (Lummox JR's description: https://www.byond.com/forum/post/2130277)
//! only the line of sight matters here: the diagonal and straight shadow loops and the eye. view() lists turfs in rings
//! going out from the light, each ring from west to east, each column of it from south to north, and so does this.
//!
//! view() counts a turf as blocking light if anything on it is opaque, but the engine only skips turfs that block light
//! from every direction. When a turf in the square blocks light from only some directions, or has something on it that
//! blocks sight without the turf counting it (multi-tile doors), DM looks with view() instead.

use super::engine::{OPAQUE, PARTLY_OPAQUE, VIEW_ONLY};

#[derive(Default)]
pub struct View {
    width: i32,
    present: Vec<bool>,
    opaque: Vec<bool>,
    vis: Vec<i32>,
    vis2: Vec<i32>,
}

impl View {
    #[inline]
    fn at(&self, x: i32, y: i32) -> usize {
        (y * self.width + x) as usize
    }

    /// Whether a neighbour of (x, y) on the map has `values` == d
    fn neighbour_is(&self, values: &[i32], x: i32, y: i32, d: i32) -> bool {
        let w = self.width;
        for ny in (y - 1).max(0)..(y + 2).min(w) {
            for nx in (x - 1).max(0)..(x + 2).min(w) {
                if nx == x && ny == y {
                    continue;
                }
                let i = self.at(nx, ny);
                if self.present[i] && values[i] == d {
                    return true;
                }
            }
        }
        false
    }

    /// The turfs that don't block light which a light on (tx, ty) sees within `range`, in view()'s order, numbered as the
    /// engine numbers turfs on a z-level. False, with nothing in `out`, if a turf in the square blocks light from only some
    /// directions or is marked VIEW_ONLY. `flags` are the z-level's turf flags.
    pub fn look(&mut self, flags: &[u8], maxx: i32, maxy: i32, tx: i32, ty: i32, range: i32, out: &mut Vec<u32>) -> bool {
        out.clear();
        let r = range.max(0);
        let w = 2 * r + 1;
        let n = (w * w) as usize;
        self.width = w;
        self.present.clear();
        self.present.resize(n, false);
        self.opaque.clear();
        self.opaque.resize(n, false);
        self.vis.clear();
        self.vis.resize(n, 0);
        self.vis2.clear();
        self.vis2.resize(n, 0);

        // The square around the light, as far as it's on the map
        let (x0, y0) = (tx - r, ty - r);
        for j in 0..w {
            let y = y0 + j;
            if y < 1 || y > maxy {
                continue;
            }
            for i in 0..w {
                let x = x0 + i;
                if x < 1 || x > maxx {
                    continue;
                }
                let f = flags[((y - 1) * maxx + (x - 1)) as usize];
                if f & (PARTLY_OPAQUE | VIEW_ONLY) != 0 {
                    return false;
                }
                let k = self.at(i, j);
                self.present[k] = true;
                self.opaque[k] = f & OPAQUE != 0;
            }
        }
        let (ex, ey) = (r, r);

        // Diagonal shadows: ring by ring outward, a turf is in sight if a neighbour on the ring before it is
        for d in 0..(w - ex) {
            let lower_x = ex - d - 1;
            let upper_x = ex + d + 1;
            for x in lower_x.max(0)..=upper_x.min(w - 1) {
                let mut y = ey - d - 1;
                let upper_y = ey + d + 1;
                // Only the ring's two end columns are whole, the rest is a turf at the top and one at the bottom
                let skip_middle = x != lower_x && x != upper_x;
                if y < 0 {
                    y = if skip_middle { upper_y } else { 0 };
                }
                while y <= upper_y && y < w {
                    let k = self.at(x, y);
                    if self.present[k] && self.neighbour_is(&self.vis2, x, y, d) {
                        self.vis2[k] = if self.opaque[k] { -1 } else { d + 1 };
                    }
                    if skip_middle && y != upper_y {
                        y = upper_y;
                    } else {
                        y += 1;
                    }
                }
            }
        }

        // Straight shadows: diamond by diamond outward, a turf is in sight if a neighbour on the diamond before it is and
        // the diagonal shadows didn't hide it
        for d in 0..(2 * (w - ex)) {
            for x in (ex - d - 1).max(0)..=(ex + d + 1).min(w - 1) {
                let offset = (d + 1) - (ex - x).abs();
                self.straight(x, ey - offset, d);
                if offset != 0 {
                    self.straight(x, ey + offset, d);
                }
            }
        }

        // The light's own turf
        let eye = self.at(ex, ey);
        if self.present[eye] {
            self.vis[eye] = 1;
        }

        for d in 0..=r {
            for dx in -d..=d {
                if dx == -d || dx == d {
                    for dy in -d..=d {
                        self.emit(r + dx, r + dy, x0, y0, maxx, out);
                    }
                } else {
                    self.emit(r + dx, r - d, x0, y0, maxx, out);
                    if d != 0 {
                        self.emit(r + dx, r + d, x0, y0, maxx, out);
                    }
                }
            }
        }
        true
    }

    fn straight(&mut self, x: i32, y: i32, d: i32) {
        if y < 0 || y >= self.width {
            return;
        }
        let k = self.at(x, y);
        if self.present[k] && self.neighbour_is(&self.vis, x, y, d) {
            if self.opaque[k] {
                self.vis[k] = -1;
            } else if self.vis2[k] != 0 {
                self.vis[k] = d + 1;
            }
        }
    }

    fn emit(&self, i: i32, j: i32, x0: i32, y0: i32, maxx: i32, out: &mut Vec<u32>) {
        let k = self.at(i, j);
        if self.present[k] && self.vis[k] != 0 && !self.opaque[k] {
            out.push(((y0 + j - 1) * maxx + (x0 + i - 1)) as u32);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Lists the turfs in sight as offsets from the light. The map's first line is its north edge, '#' blocks light,
    /// '+' blocks light from some directions.
    fn look(map: &[&str], tx: i32, ty: i32, range: i32) -> Option<Vec<(i32, i32)>> {
        let maxy = map.len() as i32;
        let maxx = map[0].len() as i32;
        let mut flags = vec![0u8; (maxx * maxy) as usize];
        for (row, line) in map.iter().enumerate() {
            let y = maxy - row as i32;
            for (col, c) in line.chars().enumerate() {
                let k = ((y - 1) * maxx + col as i32) as usize;
                match c {
                    '#' => flags[k] = OPAQUE,
                    '+' => flags[k] = PARTLY_OPAQUE,
                    '?' => flags[k] = VIEW_ONLY,
                    _ => {}
                }
            }
        }
        let mut view = View::default();
        let mut out = Vec::new();
        if !view.look(&flags, maxx, maxy, tx, ty, range, &mut out) {
            return None;
        }
        Some(out.iter().map(|&t| (t as i32 % maxx + 1 - tx, t as i32 / maxx + 1 - ty)).collect())
    }

    #[test]
    fn open_room_in_rings() {
        let seen = look(&[".....", ".....", ".....", ".....", "....."], 3, 3, 2).unwrap();
        assert_eq!(seen.len(), 25);
        // The light, then the first ring from west to east and south to north
        assert_eq!(&seen[..4], &[(0, 0), (-1, -1), (-1, 0), (-1, 1)]);
    }

    #[test]
    fn walls_hide_what_is_behind_them() {
        let seen = look(&[".....", "#####", ".....", ".....", "....."], 3, 3, 2).unwrap();
        assert!(!seen.contains(&(0, 1)), "walls aren't listed");
        assert!(!seen.contains(&(0, 2)), "what's behind the wall isn't seen");
        assert!(seen.contains(&(0, -2)));
    }

    #[test]
    fn partly_opaque_turfs_need_view() {
        assert!(look(&[".....", "..+..", ".....", ".....", "....."], 3, 3, 2).is_none());
        assert!(look(&["....?", ".....", ".....", ".....", "....."], 3, 3, 2).is_none());
    }
}
