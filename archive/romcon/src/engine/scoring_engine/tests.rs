use crate::data::{BachelorSet, GameConstants, ScoreThresholds, ScoreWeights};
use crate::engine::determine_ending;
use crate::state::RunState;

#[test]
fn high_authenticity_can_trigger_self_choice() {
    let mut run_state = RunState::debug_sample();
    for bachelor in &mut run_state.bachelors {
        bachelor.chemistry = 0.0;
        bachelor.trust = 0.0;
        bachelor.fit = 0.0;
    }
    run_state.sincerity = 80.0;

    let data = crate::data::GameData {
        constants: GameConstants {
            game_title: "Test".to_string(),
            weeks_total: 1,
            relationship_cap: 100.0,
            player_stat_cap: 100.0,
            week_one_event_ids: vec!["week1_intro".to_string()],
            score_weights: ScoreWeights {
                chemistry: 1.0,
                trust: 1.0,
                fit: 1.0,
                sincerity_bonus: 0.0,
                composure_bonus: 0.0,
                pressure_penalty: 0.0,
            },
            thresholds: ScoreThresholds {
                romance_route_min: 40.0,
                self_choice_sincerity_min: 60.0,
            },
        },
        cast: BachelorSet {
            bachelors: vec![],
            rivals: vec![],
            speakers: vec![],
        },
        event_lookup: Default::default(),
        dialogue_lookup: Default::default(),
    };

    let ending = determine_ending(&run_state, &data);
    assert_eq!(ending.winner_name, "Yourself");
}
