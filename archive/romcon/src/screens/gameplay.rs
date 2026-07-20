//! Gameplay screen for the authored week-one sequence.

use crate::data::GameData;
use crate::engine::advance_with_choice;
use crate::state::{RunState, SaveSlotId};
use crate::ui::{draw_background, draw_choice_button, draw_hint_meter, draw_notice, title_text};
use macroquad::prelude::*;
use macroquad_toolkit::assets::AssetManager;
use macroquad_toolkit::prelude::*;
use macroquad_toolkit::ui::draw_ui_text;

pub struct GameplayScreen {
    run_state: RunState,
}

pub enum GameplayAction {
    None,
    Save(SaveSlotId, RunState),
    ReturnToMenu,
    FinishWeek(RunState),
}

impl GameplayScreen {
    pub fn new(run_state: RunState) -> Self {
        Self { run_state }
    }

    pub fn update(&mut self, data: &GameData) -> GameplayAction {
        let current_event_id = self.run_state.current_event_id().to_string();
        let Some(_event) = data.event_lookup.get(&current_event_id) else {
            return GameplayAction::FinishWeek(self.run_state.clone());
        };

        let Some(node) = data.dialogue_lookup.get(&self.run_state.current_node_id) else {
            return GameplayAction::FinishWeek(self.run_state.clone());
        };

        if was_clicked(screen_width() - 220.0, screen_height() - 70.0, 180.0, 40.0) {
            return GameplayAction::ReturnToMenu;
        }
        if was_clicked(screen_width() - 220.0, screen_height() - 120.0, 180.0, 40.0) {
            return GameplayAction::Save(SaveSlotId::Slot1, self.run_state.clone());
        }
        if was_clicked(screen_width() - 220.0, screen_height() - 170.0, 180.0, 40.0) {
            return GameplayAction::Save(SaveSlotId::Slot2, self.run_state.clone());
        }
        if was_clicked(screen_width() - 220.0, screen_height() - 220.0, 180.0, 40.0) {
            return GameplayAction::Save(SaveSlotId::Slot3, self.run_state.clone());
        }

        let mut choice_y = 488.0;
        for choice in &node.choices {
            if was_clicked(76.0, choice_y, 792.0, 58.0) {
                let result = advance_with_choice(&mut self.run_state, data, choice);
                if result.week_finished {
                    return GameplayAction::FinishWeek(self.run_state.clone());
                }
            }
            choice_y += 70.0;
        }

        if node.choices.is_empty() && was_clicked(76.0, 568.0, 250.0, 50.0) {
            return GameplayAction::FinishWeek(self.run_state.clone());
        }

        GameplayAction::None
    }

    pub fn draw(&self, data: &GameData, assets: &AssetManager, notice: Option<&str>) {
        let current_event = self
            .run_state
            .current_event_id_opt()
            .and_then(|event_id| data.event_lookup.get(event_id));
        let scene_type = current_event
            .map(|event| event.scene_type.as_str())
            .unwrap_or("villa");

        draw_scene_background(scene_type, assets);

        if let Some(message) = notice {
            draw_notice(message);
        }

        panel(42.0, 28.0, 852.0, 150.0, Some("Week One"));
        title_text(
            current_event
                .map(|event| event.title.as_str())
                .unwrap_or("Finale"),
            70.0,
            88.0,
            40,
            WHITE,
        );
        draw_ui_text(
            current_event
                .map(|event| event.subtitle.as_str())
                .unwrap_or("The cameras are still rolling."),
            70.0,
            126.0,
            24.0,
            dark::TEXT_BRIGHT,
        );
        draw_ui_text(
            &format!(
                "{} | Week {} event {}/{}",
                data.constants.game_title,
                self.run_state.week,
                self.run_state.current_event_index + 1,
                self.run_state.event_order.len()
            ),
            70.0,
            154.0,
            20.0,
            dark::TEXT,
        );

        panel(42.0, 192.0, 852.0, 244.0, Some("Scene"));
        if let Some(node) = data.dialogue_lookup.get(&self.run_state.current_node_id) {
            let speaker = resolve_speaker_name(data, &node.speaker_id);
            draw_speaker_portrait(&node.speaker_id, assets, 632.0, 208.0, 244.0, 214.0);
            draw_ui_text(&speaker, 70.0, 240.0, 30.0, dark::ACCENT);
            draw_multiline_text(&node.text, 70.0, 282.0, 25.0, Some(1.22), WHITE);

            panel(42.0, 452.0, 852.0, 230.0, Some("Choose Your Read"));
            draw_ui_text(
                "The game tracks the consequences behind the scenes. Follow the emotional read, not the math.",
                70.0,
                484.0,
                18.0,
                dark::TEXT_DIM,
            );

            let mut choice_y = 488.0;
            for choice in &node.choices {
                let _ = draw_choice_button(76.0, choice_y, 792.0, 58.0, &choice.label);
                choice_y += 70.0;
            }

            if node.choices.is_empty() {
                let _ = button(76.0, 568.0, 250.0, 50.0, "Close Week");
            }
        }

        panel(914.0, 28.0, 318.0, 654.0, Some("Social Read"));
        draw_hint_meter(
            "House Mood",
            describe_spotlight(self.run_state.spotlight),
            self.run_state.spotlight,
            data.constants.player_stat_cap,
            940.0,
            88.0,
            dark::POSITIVE,
        );
        draw_hint_meter(
            "Composure",
            describe_composure(self.run_state.composure),
            self.run_state.composure,
            data.constants.player_stat_cap,
            940.0,
            152.0,
            dark::WARNING,
        );
        draw_hint_meter(
            "Sincerity",
            describe_sincerity(self.run_state.sincerity),
            self.run_state.sincerity,
            data.constants.player_stat_cap,
            940.0,
            216.0,
            dark::ACCENT,
        );
        draw_hint_meter(
            "Rival Pressure",
            describe_pressure(self.run_state.pressure),
            self.run_state.pressure,
            data.constants.player_stat_cap,
            940.0,
            280.0,
            dark::NEGATIVE,
        );

        draw_ui_text("Romantic reads", 940.0, 366.0, 22.0, dark::TEXT_BRIGHT);
        let mut rel_y = 398.0;
        for bachelor in &self.run_state.bachelors {
            let bachelor_data = data
                .cast
                .bachelors
                .iter()
                .find(|entry| entry.id == bachelor.id);
            let name = bachelor_data
                .map(|entry| entry.name.as_str())
                .unwrap_or(bachelor.id.as_str());
            draw_ui_text(name, 940.0, rel_y, 22.0, dark::TEXT_BRIGHT);
            draw_ui_text(
                relationship_read(bachelor),
                940.0,
                rel_y + 22.0,
                18.0,
                dark::ACCENT,
            );
            draw_ui_text(trust_read(bachelor), 940.0, rel_y + 42.0, 18.0, dark::TEXT);
            if let Some(info) = bachelor_data {
                draw_ui_text(&info.archetype, 940.0, rel_y + 62.0, 16.0, dark::TEXT_DIM);
                draw_ui_text(&info.public_mask, 940.0, rel_y + 80.0, 15.0, dark::TEXT_DIM);
                draw_ui_text(
                    &info.private_need,
                    940.0,
                    rel_y + 98.0,
                    15.0,
                    dark::TEXT_DIM,
                );
            }
            rel_y += 124.0;
        }

        if let Some(rival) = data.cast.rivals.first() {
            draw_ui_text("Rival read", 940.0, 642.0, 22.0, dark::NEGATIVE);
            draw_ui_text(&rival.name, 940.0, 666.0, 18.0, dark::TEXT_BRIGHT);
            draw_ui_text(&rival.strategy, 940.0, 686.0, 15.0, dark::TEXT_DIM);
        }

        let _ = button(
            screen_width() - 220.0,
            screen_height() - 220.0,
            180.0,
            40.0,
            "Save Slot 3",
        );
        let _ = button(
            screen_width() - 220.0,
            screen_height() - 170.0,
            180.0,
            40.0,
            "Save Slot 2",
        );
        let _ = button(
            screen_width() - 220.0,
            screen_height() - 120.0,
            180.0,
            40.0,
            "Save Slot 1",
        );
        let _ = button(
            screen_width() - 220.0,
            screen_height() - 70.0,
            180.0,
            40.0,
            "Back To Menu",
        );
    }
}

fn describe_spotlight(value: f32) -> &'static str {
    if value < 35.0 {
        "The house is wary of you."
    } else if value < 65.0 {
        "People are intrigued, but unconvinced."
    } else {
        "The room is leaning in your favor."
    }
}

fn describe_composure(value: f32) -> &'static str {
    if value < 25.0 {
        "You are visibly frayed."
    } else if value < 60.0 {
        "Your mask slips in flashes."
    } else {
        "You look collected."
    }
}

fn describe_sincerity(value: f32) -> &'static str {
    if value < 35.0 {
        "You are still performing for safety."
    } else if value < 70.0 {
        "Some answers feel real, some curated."
    } else {
        "Your honesty is becoming obvious."
    }
}

fn describe_pressure(value: f32) -> &'static str {
    if value < 25.0 {
        "Seraphina has not found an opening yet."
    } else if value < 60.0 {
        "She is watching for weak moments."
    } else {
        "She thinks she can outmaneuver you."
    }
}

fn relationship_read(progress: &crate::state::BachelorProgress) -> &'static str {
    let warmth = progress.chemistry;
    if warmth < 30.0 {
        "The spark is still tentative."
    } else if warmth < 60.0 {
        "There is a clear pull between you."
    } else {
        "This route is starting to feel dangerous in a good way."
    }
}

fn trust_read(progress: &crate::state::BachelorProgress) -> &'static str {
    if progress.trust < 20.0 {
        "Trust is fragile."
    } else if progress.fit < 25.0 {
        "Chemistry is ahead of compatibility."
    } else {
        "The connection feels emotionally promising."
    }
}

fn resolve_speaker_name(data: &GameData, speaker_id: &str) -> String {
    if let Some(speaker) = data
        .cast
        .speakers
        .iter()
        .find(|speaker| speaker.id == speaker_id)
    {
        return speaker.display_name.clone();
    }
    if let Some(bachelor) = data
        .cast
        .bachelors
        .iter()
        .find(|bachelor| bachelor.id == speaker_id)
    {
        return bachelor.name.clone();
    }
    if let Some(rival) = data.cast.rivals.iter().find(|rival| rival.id == speaker_id) {
        return rival.name.clone();
    }
    speaker_id.to_string()
}

fn draw_scene_background(scene_type: &str, assets: &AssetManager) {
    let texture_key = match scene_type {
        "garden" => "bg_garden",
        "ceremony" => "bg_ceremony",
        _ => "bg_villa",
    };

    if let Some(texture) = assets.get_texture(texture_key) {
        draw_texture_ex(
            texture,
            0.0,
            0.0,
            WHITE,
            DrawTextureParams {
                dest_size: Some(vec2(screen_width(), screen_height())),
                ..Default::default()
            },
        );
        draw_rectangle(
            0.0,
            0.0,
            screen_width(),
            screen_height(),
            Color::new(0.05, 0.06, 0.1, 0.32),
        );
    } else {
        draw_background(scene_type);
    }
}

fn draw_speaker_portrait(
    speaker_id: &str,
    assets: &AssetManager,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
) {
    let texture_key = match speaker_id {
        "theo" => Some("portrait_theo"),
        "julian" => Some("portrait_julian"),
        "seraphina" => Some("portrait_seraphina"),
        _ => None,
    };

    panel(x, y, width, height, Some("Portrait"));
    if let Some(texture) = texture_key.and_then(|key| assets.get_texture(key)) {
        draw_texture_ex(
            texture,
            x + 8.0,
            y + 30.0,
            WHITE,
            DrawTextureParams {
                dest_size: Some(vec2(width - 16.0, height - 38.0)),
                ..Default::default()
            },
        );
        draw_rectangle_lines(
            x + 8.0,
            y + 30.0,
            width - 16.0,
            height - 38.0,
            1.0,
            dark::ACCENT,
        );
    } else {
        draw_rectangle(
            x + 8.0,
            y + 30.0,
            width - 16.0,
            height - 38.0,
            Color::from_rgba(28, 31, 44, 220),
        );
        draw_ui_text(
            "No portrait",
            x + 58.0,
            y + height * 0.55,
            24.0,
            dark::TEXT_DIM,
        );
    }
}
