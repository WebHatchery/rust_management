//! Mutable runtime state for a single playthrough.

use crate::data::GameData;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RunState {
    pub week: u32,
    pub event_order: Vec<String>,
    pub current_event_index: usize,
    pub current_node_id: String,
    pub spotlight: f32,
    pub composure: f32,
    pub sincerity: f32,
    pub pressure: f32,
    pub bachelors: Vec<BachelorProgress>,
    pub completed_events: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BachelorProgress {
    pub id: String,
    pub chemistry: f32,
    pub trust: f32,
    pub fit: f32,
}

impl RunState {
    pub fn new(data: &GameData) -> Self {
        let current_event_id = data
            .constants
            .week_one_event_ids
            .first()
            .cloned()
            .unwrap_or_default();
        let current_node_id = data
            .event_lookup
            .get(&current_event_id)
            .map(|event| event.start_node.clone())
            .unwrap_or_default();

        Self {
            week: 1,
            event_order: data.constants.week_one_event_ids.clone(),
            current_event_index: 0,
            current_node_id,
            spotlight: 50.0,
            composure: 80.0,
            sincerity: 50.0,
            pressure: 10.0,
            bachelors: data
                .cast
                .bachelors
                .iter()
                .map(|bachelor| BachelorProgress {
                    id: bachelor.id.clone(),
                    chemistry: 10.0,
                    trust: 5.0,
                    fit: 5.0,
                })
                .collect(),
            completed_events: Vec::new(),
        }
    }

    pub fn current_event_id(&self) -> &str {
        &self.event_order[self.current_event_index]
    }

    pub fn current_event_id_opt(&self) -> Option<&String> {
        self.event_order.get(self.current_event_index)
    }

    pub fn bachelor_mut(&mut self, bachelor_id: &str) -> Option<&mut BachelorProgress> {
        self.bachelors
            .iter_mut()
            .find(|progress| progress.id == bachelor_id)
    }

    #[cfg(test)]
    pub fn debug_sample() -> Self {
        Self {
            week: 1,
            event_order: vec!["event_1".to_string(), "event_2".to_string()],
            current_event_index: 0,
            current_node_id: "node_1".to_string(),
            spotlight: 50.0,
            composure: 80.0,
            sincerity: 50.0,
            pressure: 10.0,
            bachelors: vec![
                BachelorProgress {
                    id: "theo".to_string(),
                    chemistry: 10.0,
                    trust: 5.0,
                    fit: 5.0,
                },
                BachelorProgress {
                    id: "julian".to_string(),
                    chemistry: 10.0,
                    trust: 5.0,
                    fit: 5.0,
                },
            ],
            completed_events: Vec::new(),
        }
    }
}
