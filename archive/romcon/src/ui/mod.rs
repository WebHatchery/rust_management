//! Shared rendering helpers and lightweight UI components.

mod components;
mod core;

pub use components::{draw_choice_button, draw_hint_meter};
pub use core::{draw_background, draw_notice, title_text};
