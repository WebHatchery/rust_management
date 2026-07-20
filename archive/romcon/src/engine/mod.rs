//! Stateless gameplay engines.

mod event_engine;
mod romance_engine;
mod scoring_engine;

pub use event_engine::advance_with_choice;
pub use romance_engine::apply_effects;
pub use scoring_engine::{determine_ending, EndingOutcome};
