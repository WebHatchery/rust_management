//! Cross-platform save/load wrappers.

use crate::state::RunState;
use macroquad_toolkit::persistence::{
    load_from_slot as toolkit_load_from_slot, save_to_slot as toolkit_save_to_slot,
};
use serde::{Deserialize, Serialize};

const SAVE_NAMESPACE: &str = "romcon";
const SAVE_VERSION: u32 = 2;

#[derive(Clone, Copy, Debug)]
pub enum SaveSlotId {
    Slot1,
    Slot2,
    Slot3,
}

impl SaveSlotId {
    pub fn key(self) -> &'static str {
        match self {
            Self::Slot1 => "slot_1",
            Self::Slot2 => "slot_2",
            Self::Slot3 => "slot_3",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::Slot1 => "Slot 1",
            Self::Slot2 => "Slot 2",
            Self::Slot3 => "Slot 3",
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SaveData {
    pub version: u32,
    pub run_state: RunState,
}

pub fn save_to_slot(slot: SaveSlotId, run_state: &RunState) -> Result<(), String> {
    let save_data = SaveData {
        version: SAVE_VERSION,
        run_state: run_state.clone(),
    };
    toolkit_save_to_slot(SAVE_NAMESPACE, slot.key(), &save_data)
}

pub fn load_from_slot(slot: SaveSlotId) -> Result<RunState, String> {
    let save_data: SaveData = toolkit_load_from_slot(SAVE_NAMESPACE, slot.key())
        .map_err(|error| format!("Could not load {}: {error}", slot.label()))?;

    if save_data.version != SAVE_VERSION {
        return Err(format!(
            "{} uses unsupported save version {}.",
            slot.label(),
            save_data.version
        ));
    }

    Ok(save_data.run_state)
}
