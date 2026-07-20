//! Shared visual helpers.

use macroquad::prelude::*;
use macroquad_toolkit::ui::{draw_ui_text, measure_ui_text};

pub fn draw_background(scene_type: &str) {
    let (top, bottom) = match scene_type {
        "garden" => (
            Color::from_rgba(38, 68, 54, 255),
            Color::from_rgba(114, 160, 122, 255),
        ),
        "ceremony" => (
            Color::from_rgba(52, 25, 58, 255),
            Color::from_rgba(130, 73, 124, 255),
        ),
        _ => (
            Color::from_rgba(24, 27, 44, 255),
            Color::from_rgba(66, 74, 108, 255),
        ),
    };

    draw_rectangle(0.0, 0.0, screen_width(), screen_height(), top);
    draw_rectangle(
        0.0,
        screen_height() * 0.4,
        screen_width(),
        screen_height() * 0.6,
        bottom,
    );
    draw_circle(
        screen_width() - 180.0,
        110.0,
        70.0,
        Color::new(1.0, 0.95, 0.8, 0.08),
    );
    draw_circle(170.0, 600.0, 180.0, Color::new(1.0, 1.0, 1.0, 0.03));
}

pub fn draw_notice(message: &str) {
    let width = measure_ui_text(message, None, 20, 1.0).width + 36.0;
    let x = screen_width() - width - 24.0;
    let y = 18.0;

    let surface = macroquad_toolkit::ui::SurfaceStyle::new(Color::from_rgba(14, 17, 28, 220))
        .with_border(1.0, Color::from_rgba(170, 190, 255, 160));
    macroquad_toolkit::ui::draw_surface(Rect::new(x, y, width, 34.0), &surface);
    draw_ui_text(message, x + 18.0, y + 23.0, 20.0, WHITE);
}

pub fn title_text(text: &str, x: f32, y: f32, size: u16, color: Color) {
    let shadow = Color::new(0.0, 0.0, 0.0, 0.25);
    draw_ui_text(text, x + 2.0, y + 2.0, size as f32, shadow);
    draw_ui_text(text, x, y, size as f32, color);
}
