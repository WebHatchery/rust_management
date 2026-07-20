//! Top-level game coordinator and explicit screen transitions.

use crate::data::{load_game_data, GameData};
use crate::engine::determine_ending;
use crate::screens::{
    GameplayAction, GameplayScreen, MenuAction, MenuScreen, ResultsAction, ResultsScreen,
};
use crate::state::{load_from_slot, save_to_slot, RunState, SaveSlotId};
use macroquad::prelude::*;
use macroquad_toolkit::assets::AssetManager;

pub struct Game {
    data: Option<GameData>,
    assets: AssetManager,
    screen: Screen,
    notice: Option<String>,
    boot_error: Option<String>,
}

enum Screen {
    Menu(MenuScreen),
    Gameplay(GameplayScreen),
    Results(ResultsScreen),
}

impl Game {
    pub async fn new() -> Self {
        let mut assets = AssetManager::new();
        let asset_error = load_placeholder_assets(&mut assets).await.err();

        match load_game_data().await {
            Ok(data) => Self {
                data: Some(data),
                assets,
                screen: Screen::Menu(MenuScreen::default()),
                notice: asset_error,
                boot_error: None,
            },
            Err(error) => Self {
                data: None,
                assets,
                screen: Screen::Menu(MenuScreen::default()),
                notice: None,
                boot_error: Some(match asset_error {
                    Some(asset_error) => format!("{error} | {asset_error}"),
                    None => error,
                }),
            },
        }
    }

    pub fn update(&mut self) {
        let Some(data) = self.data.as_ref() else {
            return;
        };

        let transition: Transition = match &mut self.screen {
            Screen::Menu(screen) => screen
                .update(self.notice.take(), self.boot_error.take())
                .into(),
            Screen::Gameplay(screen) => screen.update(data).into(),
            Screen::Results(screen) => screen.update().into(),
        };

        match transition {
            Transition::None => {}
            Transition::StartNewRun => {
                self.notice = Some("Week one begins. Your first impression matters.".to_string());
                self.screen = Screen::Gameplay(GameplayScreen::new(RunState::new(data)));
            }
            Transition::Load(slot) => match load_from_slot(slot) {
                Ok(run_state) => {
                    self.notice = Some(format!("Loaded {}.", slot.label()));
                    self.screen = Screen::Gameplay(GameplayScreen::new(run_state));
                }
                Err(error) => {
                    self.notice = Some(error);
                    self.screen = Screen::Menu(MenuScreen::default());
                }
            },
            Transition::Save(slot, run_state) => {
                self.notice = Some(match save_to_slot(slot, &run_state) {
                    Ok(()) => format!("Saved to {}.", slot.label()),
                    Err(error) => error,
                });
            }
            Transition::ToMenu => {
                self.screen = Screen::Menu(MenuScreen::default());
            }
            Transition::ToResults(run_state) => {
                let ending = determine_ending(&run_state, data);
                self.screen = Screen::Results(ResultsScreen::new(run_state, ending));
            }
        }
    }

    pub fn draw(&self) {
        clear_background(Color::from_rgba(14, 18, 29, 255));

        match &self.screen {
            Screen::Menu(screen) => screen.draw(self.notice.as_deref(), self.boot_error.as_deref()),
            Screen::Gameplay(screen) => {
                if let Some(data) = self.data.as_ref() {
                    screen.draw(data, &self.assets, self.notice.as_deref());
                }
            }
            Screen::Results(screen) => screen.draw(),
        }
    }
}

enum Transition {
    None,
    StartNewRun,
    Load(SaveSlotId),
    Save(SaveSlotId, RunState),
    ToMenu,
    ToResults(RunState),
}

impl From<MenuAction> for Transition {
    fn from(value: MenuAction) -> Self {
        match value {
            MenuAction::None => Self::None,
            MenuAction::StartNewRun => Self::StartNewRun,
            MenuAction::Load(slot) => Self::Load(slot),
        }
    }
}

impl From<GameplayAction> for Transition {
    fn from(value: GameplayAction) -> Self {
        match value {
            GameplayAction::None => Self::None,
            GameplayAction::Save(slot, run_state) => Self::Save(slot, run_state),
            GameplayAction::ReturnToMenu => Self::ToMenu,
            GameplayAction::FinishWeek(run_state) => Self::ToResults(run_state),
        }
    }
}

impl From<ResultsAction> for Transition {
    fn from(value: ResultsAction) -> Self {
        match value {
            ResultsAction::None => Self::None,
            ResultsAction::ToMenu => Self::ToMenu,
            ResultsAction::Restart(run_state) => Self::ToResults(run_state),
        }
    }
}

async fn load_placeholder_assets(assets: &mut AssetManager) -> Result<(), String> {
    let placeholder_paths = [
        ("portrait_theo", "assets/images/theo_placeholder.png"),
        ("portrait_julian", "assets/images/julian_placeholder.png"),
        (
            "portrait_seraphina",
            "assets/images/seraphina_placeholder.png",
        ),
        ("bg_villa", "assets/images/villa_placeholder.png"),
        ("bg_garden", "assets/images/garden_placeholder.png"),
        ("bg_ceremony", "assets/images/ceremony_placeholder.png"),
    ];

    for (key, path) in placeholder_paths {
        assets.load_texture(key, path).await?;
    }

    Ok(())
}
