use config::Config;
use dotenv::dotenv;
use std::collections::HashMap;
use std::{io, sync::Arc};
use tokio::sync::RwLock;
use tracing::Level;

mod config;
mod tiers;
mod watch;

use tiers::Tier;

#[derive(Default)]
pub struct State {
    pub tiers: RwLock<HashMap<String, Tier>>,
}

#[tokio::main]
async fn main() -> io::Result<()> {
    dotenv().ok();

    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    let state = Arc::new(State::default());
    let config = Arc::new(Config::default());

    tokio::join!(
        watch::run(state.clone(), config.clone()),
        tiers::run(state.clone(), config.clone())
    );

    Ok(())
}
