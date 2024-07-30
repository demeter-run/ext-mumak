use notify::{Event, PollWatcher, RecursiveMode, Watcher};
use serde::Deserialize;
use serde_json::Value;
use std::{error::Error, fs, sync::Arc};
use tracing::{error, info, instrument, warn};

use crate::config::Config;
use crate::watch::update_configs;
use crate::State;

#[derive(Debug, Clone, Deserialize)]
pub struct Tier {
    pub name: String,
    pub max_connections: usize,
}
async fn update_tiers(state: Arc<State>, config: Arc<Config>) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(&config.tiers_path)?;

    let value: Value = toml::from_str(&contents)?;
    let tiers_value: Option<&Value> = value.get("tiers");
    if tiers_value.is_none() {
        warn!("tiers not configured on toml");
        return Ok(());
    }

    let tiers = serde_json::from_value::<Vec<Tier>>(tiers_value.unwrap().to_owned())?;

    *state.tiers.write().await = tiers
        .into_iter()
        .map(|tier| (tier.name.clone(), tier))
        .collect();

    Ok(())
}

#[instrument("tier watcher", skip_all)]
pub async fn run(state: Arc<State>, config: Arc<Config>) {
    if let Err(err) = update_tiers(state.clone(), config.clone()).await {
        error!(error = err.to_string(), "error to update tiers");
        return;
    }

    let (tx, mut rx) = tokio::sync::mpsc::channel::<Event>(1);

    let watcher_config = notify::Config::default()
        .with_compare_contents(true)
        .with_poll_interval(config.tiers_poll_interval);

    let mut watcher = match PollWatcher::new(
        move |res| match res {
            Ok(event) => futures::executor::block_on(async {
                tx.send(event).await.unwrap();
            }),
            Err(_) => {
                error!("Tier file watcher failed to send event");
            }
        },
        watcher_config,
    ) {
        Ok(watcher) => watcher,
        Err(err) => {
            error!(error = err.to_string(), "error to watcher tier");
            return;
        }
    };

    if let Err(err) = watcher.watch(&config.tiers_path, RecursiveMode::Recursive) {
        error!(error = err.to_string(), "error to watcher tier");
        return;
    }

    loop {
        let result = rx.recv().await;
        if result.is_some() {
            if let Err(err) = update_tiers(state.clone(), config.clone()).await {
                error!(error = err.to_string(), "error to update tiers");
                continue;
            }
            info!("tiers modified, updating configs");
            update_configs(state.clone(), config.clone(), None).await;
        }
    }
}
