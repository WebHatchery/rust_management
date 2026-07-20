//! Deterministic dialogue and event progression.

use crate::data::{ChoiceData, GameData};
use crate::engine::apply_effects;
use crate::state::RunState;

pub struct AdvanceResult {
    pub week_finished: bool,
}

pub fn advance_with_choice(
    run_state: &mut RunState,
    data: &GameData,
    choice: &ChoiceData,
) -> AdvanceResult {
    apply_effects(
        run_state,
        &choice.effects,
        data.constants.relationship_cap,
        data.constants.player_stat_cap,
    );

    if let Some(next_node) = &choice.next_node {
        run_state.current_node_id = next_node.clone();
        return AdvanceResult {
            week_finished: false,
        };
    }

    if choice.finish_event {
        let current_event_id = run_state.current_event_id().to_string();
        if !run_state.completed_events.contains(&current_event_id) {
            run_state.completed_events.push(current_event_id);
        }

        run_state.current_event_index += 1;
        if let Some(next_event_id) = run_state.current_event_id_opt() {
            if let Some(event) = data.event_lookup.get(next_event_id) {
                run_state.current_node_id = event.start_node.clone();
                return AdvanceResult {
                    week_finished: false,
                };
            }
        }

        return AdvanceResult {
            week_finished: true,
        };
    }

    AdvanceResult {
        week_finished: false,
    }
}
