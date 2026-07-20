//! Results screen for the vertical slice ending.

use crate::engine::EndingOutcome;
use crate::state::RunState;
use crate::ui::title_text;
use macroquad::prelude::*;
use macroquad_toolkit::prelude::*;
use macroquad_toolkit::ui::draw_ui_text;

pub struct ResultsScreen {
    run_state: RunState,
    ending: EndingOutcome,
}

pub enum ResultsAction {
    None,
    ToMenu,
    Restart(RunState),
}

impl ResultsScreen {
    pub fn new(run_state: RunState, ending: EndingOutcome) -> Self {
        Self { run_state, ending }
    }

    pub fn update(&mut self) -> ResultsAction {
        if was_clicked(94.0, 590.0, 240.0, 48.0) {
            return ResultsAction::ToMenu;
        }
        if was_clicked(360.0, 590.0, 240.0, 48.0) {
            return ResultsAction::Restart(self.run_state.clone());
        }
        ResultsAction::None
    }

    pub fn draw(&self) {
        clear_background(dark::BACKGROUND);
        draw_rectangle(
            0.0,
            0.0,
            screen_width(),
            screen_height(),
            Color::from_rgba(21, 13, 29, 255),
        );
        draw_rectangle(
            0.0,
            screen_height() * 0.4,
            screen_width(),
            screen_height() * 0.6,
            Color::from_rgba(84, 39, 66, 255),
        );

        panel(70.0, 62.0, 1140.0, 492.0, Some("Week One Outcome"));
        title_text(&self.ending.title, 96.0, 132.0, 48, WHITE);
        draw_ui_text(
            &format!("Leading route: {}", self.ending.winner_name),
            98.0,
            168.0,
            24.0,
            dark::ACCENT,
        );
        draw_multiline_text(&self.ending.summary, 98.0, 220.0, 28.0, Some(1.3), WHITE);

        draw_ui_text(
            "What the week leaves behind",
            98.0,
            350.0,
            26.0,
            dark::TEXT_BRIGHT,
        );
        draw_ui_text(summary_read(&self.run_state), 98.0, 386.0, 22.0, dark::TEXT);

        let mut y = 440.0;
        for bachelor in &self.run_state.bachelors {
            draw_ui_text(
                &format!("{}: {}", bachelor.id, ending_read(bachelor)),
                98.0,
                y,
                21.0,
                dark::TEXT_BRIGHT,
            );
            y += 34.0;
        }

        let _ = button(94.0, 590.0, 240.0, 48.0, "Return To Menu");
        let _ = button(360.0, 590.0, 240.0, 48.0, "Show Ending Again");
    }
}

fn summary_read(run_state: &RunState) -> &'static str {
    if run_state.sincerity >= 70.0 && run_state.composure >= 60.0 {
        "You leave week one looking unusually sincere for someone under this much scrutiny."
    } else if run_state.composure < 35.0 {
        "The week landed hard. Whatever connection you built came at a visible emotional cost."
    } else {
        "You are still balancing image, nerves, and real feeling. The room can sense all three."
    }
}

fn ending_read(progress: &crate::state::BachelorProgress) -> &'static str {
    let total = progress.chemistry + progress.trust + progress.fit;
    if total < 55.0 {
        "interesting, but not settled"
    } else if total < 95.0 {
        "clearly building"
    } else {
        "the strongest emotional thread so far"
    }
}
