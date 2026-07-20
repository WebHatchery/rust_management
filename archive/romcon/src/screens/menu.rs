//! Main menu screen.

use crate::state::SaveSlotId;
use crate::ui::title_text;
use macroquad::prelude::*;
use macroquad_toolkit::prelude::*;
use macroquad_toolkit::ui::draw_ui_text;

#[derive(Default)]
pub struct MenuScreen {
    notice: Option<String>,
    boot_error: Option<String>,
}

pub enum MenuAction {
    None,
    StartNewRun,
    Load(SaveSlotId),
}

impl MenuScreen {
    pub fn update(&mut self, notice: Option<String>, boot_error: Option<String>) -> MenuAction {
        self.notice = notice;
        self.boot_error = boot_error;

        if self.boot_error.is_some() {
            return MenuAction::None;
        }

        let center_x = screen_width() * 0.5 - 140.0;
        let start_y = 300.0;
        if was_clicked(center_x, start_y, 280.0, 48.0) {
            return MenuAction::StartNewRun;
        }
        if was_clicked(center_x, start_y + 62.0, 280.0, 48.0) {
            return MenuAction::Load(SaveSlotId::Slot1);
        }
        if was_clicked(center_x, start_y + 124.0, 280.0, 48.0) {
            return MenuAction::Load(SaveSlotId::Slot2);
        }
        if was_clicked(center_x, start_y + 186.0, 280.0, 48.0) {
            return MenuAction::Load(SaveSlotId::Slot3);
        }
        MenuAction::None
    }

    pub fn draw(&self, notice: Option<&str>, boot_error: Option<&str>) {
        clear_background(dark::BACKGROUND);
        draw_rectangle(
            0.0,
            0.0,
            screen_width(),
            screen_height(),
            Color::from_rgba(24, 20, 36, 255),
        );
        draw_rectangle(
            0.0,
            screen_height() * 0.45,
            screen_width(),
            screen_height() * 0.55,
            Color::from_rgba(82, 40, 72, 255),
        );

        title_text("Love Season", 90.0, 130.0, 64, WHITE);
        draw_ui_text(
            "A one-week vertical slice of public pressure, private chemistry, and strategic honesty.",
            92.0,
            175.0,
            24.0,
            dark::TEXT,
        );

        panel(70.0, 240.0, 1140.0, 360.0, Some("Vertical Slice"));
        draw_ui_text("Playable now:", 100.0, 290.0, 26.0, dark::ACCENT);
        draw_ui_text(
            "Week 1 includes an arrival mixer, a private invitation, a rose ceremony, save/load, and provisional endings for Theo, Julian, or self-choice.",
            100.0,
            325.0,
            24.0,
            dark::TEXT_BRIGHT,
        );

        draw_ui_text("Featured cast", 100.0, 388.0, 26.0, dark::ACCENT);
        draw_ui_text(
            "Theo Vale: warm, impulsive, and impossible to stage-manage.",
            100.0,
            420.0,
            22.0,
            dark::TEXT,
        );
        draw_ui_text(
            "Julian Cross: polished, observant, and suspiciously good at reading silences.",
            100.0,
            450.0,
            22.0,
            dark::TEXT,
        );
        draw_ui_text(
            "Seraphina Rowe: rival contestant who knows exactly how to weaponize poise.",
            100.0,
            480.0,
            22.0,
            dark::TEXT,
        );

        let center_x = screen_width() * 0.5 - 140.0;
        let start_y = 300.0;
        let _ = button(center_x, start_y, 280.0, 48.0, "Start Week One");
        let _ = button(center_x, start_y + 62.0, 280.0, 48.0, "Load Slot 1");
        let _ = button(center_x, start_y + 124.0, 280.0, 48.0, "Load Slot 2");
        let _ = button(center_x, start_y + 186.0, 280.0, 48.0, "Load Slot 3");

        if let Some(message) = notice.or(self.notice.as_deref()) {
            draw_ui_text(message, 100.0, 548.0, 22.0, dark::POSITIVE);
        }

        if let Some(error) = boot_error.or(self.boot_error.as_deref()) {
            draw_ui_text(
                "Content loading failed.",
                100.0,
                548.0,
                24.0,
                dark::NEGATIVE,
            );
            draw_ui_text(error, 100.0, 580.0, 20.0, dark::TEXT_BRIGHT);
        }
    }
}
