//! Cast definitions for bachelors, rivals, and utility speakers.

use serde::Deserialize;

#[derive(Clone, Debug, Deserialize)]
pub struct BachelorSet {
    pub bachelors: Vec<BachelorData>,
    pub rivals: Vec<RivalData>,
    pub speakers: Vec<SpeakerData>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct BachelorData {
    pub id: String,
    pub name: String,
    pub archetype: String,
    pub public_mask: String,
    pub private_need: String,
}

#[derive(Clone, Debug, Deserialize)]
pub struct RivalData {
    pub id: String,
    pub name: String,
    pub strategy: String,
}

#[derive(Clone, Debug, Deserialize)]
pub struct SpeakerData {
    pub id: String,
    pub display_name: String,
}
