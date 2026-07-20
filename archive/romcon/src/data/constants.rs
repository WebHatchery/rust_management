//! Balance and routing constants loaded from JSON.

use serde::Deserialize;

#[derive(Clone, Debug, Deserialize)]
pub struct GameConstants {
    pub game_title: String,
    pub weeks_total: u32,
    pub relationship_cap: f32,
    pub player_stat_cap: f32,
    pub week_one_event_ids: Vec<String>,
    pub score_weights: ScoreWeights,
    pub thresholds: ScoreThresholds,
}

#[derive(Clone, Debug, Deserialize)]
pub struct ScoreWeights {
    pub chemistry: f32,
    pub trust: f32,
    pub fit: f32,
    pub sincerity_bonus: f32,
    pub composure_bonus: f32,
    pub pressure_penalty: f32,
}

#[derive(Clone, Debug, Deserialize)]
pub struct ScoreThresholds {
    pub romance_route_min: f32,
    pub self_choice_sincerity_min: f32,
}
