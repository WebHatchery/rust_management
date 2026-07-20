//! Static content definitions and asset loading.

mod character_data;
mod constants;
mod dialogue_data;
mod event_data;
mod loader;

pub use character_data::BachelorSet;
pub use constants::{GameConstants, ScoreThresholds, ScoreWeights};
pub use dialogue_data::{ChoiceData, DialogueDatabase, DialogueNode, EffectData};
pub use event_data::EventData;
pub use loader::{load_game_data, GameData};
