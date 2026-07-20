//! Dialogue tree definitions and effect payloads.

use serde::Deserialize;

#[derive(Clone, Debug, Deserialize)]
pub struct DialogueDatabase {
    pub nodes: Vec<DialogueNode>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct DialogueNode {
    pub id: String,
    pub speaker_id: String,
    pub text: String,
    #[serde(default)]
    pub choices: Vec<ChoiceData>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct ChoiceData {
    pub label: String,
    pub next_node: Option<String>,
    #[serde(default)]
    pub finish_event: bool,
    #[serde(default)]
    pub effects: Vec<EffectData>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum EffectData {
    PlayerStat {
        stat: String,
        amount: f32,
    },
    BachelorStat {
        bachelor_id: String,
        stat: String,
        amount: f32,
    },
    RivalPressure {
        amount: f32,
    },
}
