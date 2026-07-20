//! Screen-specific UI and input handling.

mod gameplay;
mod menu;
mod results;

pub use gameplay::{GameplayAction, GameplayScreen};
pub use menu::{MenuAction, MenuScreen};
pub use results::{ResultsAction, ResultsScreen};
