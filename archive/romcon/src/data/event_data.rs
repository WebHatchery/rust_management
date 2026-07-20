//! Event metadata for the authored weekly sequence.

use serde::Deserialize;

#[derive(Clone, Debug, Deserialize)]
pub struct EventData {
    pub id: String,
    pub week: u32,
    pub title: String,
    pub subtitle: String,
    pub scene_type: String,
    pub start_node: String,
}
