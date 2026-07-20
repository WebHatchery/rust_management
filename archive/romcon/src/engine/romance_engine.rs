//! Choice consequence application for player and relationship stats.

use crate::data::EffectData;
use crate::state::RunState;

pub fn apply_effects(
    run_state: &mut RunState,
    effects: &[EffectData],
    relationship_cap: f32,
    player_stat_cap: f32,
) {
    for effect in effects {
        match effect {
            EffectData::PlayerStat { stat, amount } => {
                let target = match stat.as_str() {
                    "spotlight" => &mut run_state.spotlight,
                    "composure" => &mut run_state.composure,
                    "sincerity" => &mut run_state.sincerity,
                    _ => continue,
                };
                *target = (*target + amount).clamp(0.0, player_stat_cap);
            }
            EffectData::BachelorStat {
                bachelor_id,
                stat,
                amount,
            } => {
                let Some(bachelor) = run_state.bachelor_mut(bachelor_id) else {
                    continue;
                };

                let target = match stat.as_str() {
                    "chemistry" => &mut bachelor.chemistry,
                    "trust" => &mut bachelor.trust,
                    "fit" => &mut bachelor.fit,
                    _ => continue,
                };
                *target = (*target + amount).clamp(0.0, relationship_cap);
            }
            EffectData::RivalPressure { amount } => {
                run_state.pressure = (run_state.pressure + amount).clamp(0.0, player_stat_cap);
            }
        }
    }
}
