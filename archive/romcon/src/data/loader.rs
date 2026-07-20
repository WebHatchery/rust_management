//! Async content loading and validation.

use crate::data::{BachelorSet, DialogueDatabase, DialogueNode, EventData, GameConstants};
use macroquad::prelude::load_string;
use std::collections::{HashMap, HashSet};

#[derive(Clone)]
pub struct GameData {
    pub constants: GameConstants,
    pub cast: BachelorSet,
    pub event_lookup: HashMap<String, EventData>,
    pub dialogue_lookup: HashMap<String, DialogueNode>,
}

pub async fn load_game_data() -> Result<GameData, String> {
    let constants_json = load_string("assets/constants.json")
        .await
        .map_err(|error| format!("Failed to load assets/constants.json: {error}"))?;
    let characters_json = load_string("assets/characters.json")
        .await
        .map_err(|error| format!("Failed to load assets/characters.json: {error}"))?;
    let events_json = load_string("assets/events.json")
        .await
        .map_err(|error| format!("Failed to load assets/events.json: {error}"))?;
    let dialogue_json = load_string("assets/dialogue.json")
        .await
        .map_err(|error| format!("Failed to load assets/dialogue.json: {error}"))?;

    let constants: GameConstants = serde_json::from_str(&constants_json)
        .map_err(|error| format!("constants.json parse error: {error}"))?;
    let cast: BachelorSet = serde_json::from_str(&characters_json)
        .map_err(|error| format!("characters.json parse error: {error}"))?;
    let events: Vec<EventData> = serde_json::from_str(&events_json)
        .map_err(|error| format!("events.json parse error: {error}"))?;
    let dialogue: DialogueDatabase = serde_json::from_str(&dialogue_json)
        .map_err(|error| format!("dialogue.json parse error: {error}"))?;

    validate_ids(&constants, &cast, &events, &dialogue)?;

    let event_lookup = events
        .iter()
        .cloned()
        .map(|event| (event.id.clone(), event))
        .collect();
    let dialogue_lookup = dialogue
        .nodes
        .into_iter()
        .map(|node| (node.id.clone(), node))
        .collect();

    Ok(GameData {
        constants,
        cast,
        event_lookup,
        dialogue_lookup,
    })
}

fn validate_ids(
    constants: &GameConstants,
    cast: &BachelorSet,
    events: &[EventData],
    dialogue: &DialogueDatabase,
) -> Result<(), String> {
    if constants.weeks_total == 0 {
        return Err("weeks_total must be greater than zero".to_string());
    }

    let mut seen = HashSet::new();
    for bachelor in &cast.bachelors {
        if !seen.insert(bachelor.id.clone()) {
            return Err(format!("Duplicate bachelor id: {}", bachelor.id));
        }
    }

    for rival in &cast.rivals {
        if !seen.insert(rival.id.clone()) {
            return Err(format!("Duplicate rival id: {}", rival.id));
        }
    }

    let mut speakers: HashSet<String> = cast
        .speakers
        .iter()
        .map(|speaker| speaker.id.clone())
        .collect();
    speakers.extend(cast.bachelors.iter().map(|bachelor| bachelor.id.clone()));
    speakers.extend(cast.rivals.iter().map(|rival| rival.id.clone()));

    let mut event_ids = HashSet::new();
    for event in events {
        if !(1..=constants.weeks_total).contains(&event.week) {
            return Err(format!(
                "Event {} has invalid week {}",
                event.id, event.week
            ));
        }
        if !event_ids.insert(event.id.clone()) {
            return Err(format!("Duplicate event id: {}", event.id));
        }
    }

    for required_event in &constants.week_one_event_ids {
        if !event_ids.contains(required_event) {
            return Err(format!(
                "week_one_event_ids references unknown event {required_event}"
            ));
        }
    }

    let node_ids: HashSet<String> = dialogue.nodes.iter().map(|node| node.id.clone()).collect();
    for event in events {
        if !node_ids.contains(&event.start_node) {
            return Err(format!(
                "Event {} references missing node {}",
                event.id, event.start_node
            ));
        }
    }

    for node in &dialogue.nodes {
        if !speakers.contains(&node.speaker_id) {
            return Err(format!(
                "Dialogue node {} references unknown speaker {}",
                node.id, node.speaker_id
            ));
        }

        for choice in &node.choices {
            if let Some(next_node) = &choice.next_node {
                if !node_ids.contains(next_node) {
                    return Err(format!(
                        "Choice '{}' from node {} targets missing node {}",
                        choice.label, node.id, next_node
                    ));
                }
            }
        }
    }

    Ok(())
}
