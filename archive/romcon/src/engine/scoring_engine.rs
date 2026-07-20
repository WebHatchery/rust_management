//! Provisional ending selection for the week-one vertical slice.

use crate::data::{GameData, ScoreWeights};
use crate::state::{BachelorProgress, RunState};

#[derive(Clone)]
pub struct EndingOutcome {
    pub title: String,
    pub summary: String,
    pub winner_name: String,
}

pub fn determine_ending(run_state: &RunState, data: &GameData) -> EndingOutcome {
    let thresholds: &crate::data::ScoreThresholds = &data.constants.thresholds;
    let top_candidate =
        run_state.bachelors.iter().max_by(|left, right| {
            bachelor_score(left, run_state, &data.constants.score_weights).total_cmp(
                &bachelor_score(right, run_state, &data.constants.score_weights),
            )
        });

    if let Some(candidate) = top_candidate {
        let score = bachelor_score(candidate, run_state, &data.constants.score_weights);
        let bachelor_name = data
            .cast
            .bachelors
            .iter()
            .find(|bachelor| bachelor.id == candidate.id)
            .map(|bachelor| bachelor.name.clone())
            .unwrap_or_else(|| candidate.id.clone());

        if score >= thresholds.romance_route_min {
            return EndingOutcome {
                title: format!("A Rose For {}", bachelor_name),
                summary: format!(
                    "You close week one leaning toward {}. The spark is real, but the show has only just begun to test whether it can survive public scrutiny.",
                    bachelor_name
                ),
                winner_name: bachelor_name,
            };
        }
    }

    if run_state.sincerity >= thresholds.self_choice_sincerity_min {
        EndingOutcome {
            title: "You Choose Yourself".to_string(),
            summary: "The cameras want a clean romance arc. Your clearest instinct is not to fake one. That honesty becomes the strongest choice you make all week.".to_string(),
            winner_name: "Yourself".to_string(),
        }
    } else {
        EndingOutcome {
            title: "A Beautifully Awkward Holding Pattern".to_string(),
            summary: "You survive the first ceremony, but nobody quite knows where your heart is landing yet. The uncertainty is now part of the story.".to_string(),
            winner_name: "Nobody yet".to_string(),
        }
    }
}

fn bachelor_score(
    progress: &BachelorProgress,
    run_state: &RunState,
    weights: &ScoreWeights,
) -> f32 {
    progress.chemistry * weights.chemistry
        + progress.trust * weights.trust
        + progress.fit * weights.fit
        + run_state.sincerity * weights.sincerity_bonus
        + run_state.composure * weights.composure_bonus
        - run_state.pressure * weights.pressure_penalty
}

#[cfg(test)]
mod tests {
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
}
