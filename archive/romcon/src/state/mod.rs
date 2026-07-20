//! Serializable runtime state and persistence.

mod game_state;
mod persistence;

pub use game_state::{BachelorProgress, RunState};
pub use persistence::{load_from_slot, save_to_slot, SaveSlotId};
