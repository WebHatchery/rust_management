//! Reusable panels and stat widgets.

use macroquad::prelude::*;
use macroquad_toolkit::prelude::*;
use macroquad_toolkit::ui::draw_ui_text;

pub fn draw_choice_button(x: f32, y: f32, width: f32, height: f32, label: &str) -> bool {
    let style = ButtonStyle {
        normal: Color::from_rgba(28, 33, 47, 228),
        hovered: Color::from_rgba(45, 56, 78, 240),
        pressed: Color::from_rgba(59, 70, 96, 245),
        border: Color::from_rgba(204, 183, 141, 220),
        text_color: dark::TEXT_BRIGHT,
        disabled: Color::from_rgba(18, 22, 31, 180),
    };
    button_styled(x, y, width, height, label, &style)
}

pub fn draw_hint_meter(
    label: &str,
    hint: &str,
    value: f32,
    max: f32,
    x: f32,
    y: f32,
    color: Color,
) {
    draw_ui_text(label, x, y, 18.0, dark::TEXT_BRIGHT);
    draw_ui_text(hint, x, y + 22.0, 16.0, dark::TEXT_DIM);
    progress_bar(x, y + 34.0, 218.0, 10.0, value, max, color);
}
