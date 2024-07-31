use std::{io::Write, sync::Arc};

use futures_util::TryStreamExt;
use operator::{
    kube::{
        api::{Api, ListParams},
        runtime::watcher::{self, Config as ConfigWatcher, Event},
        Client, ResourceExt,
    },
    MumakPort,
};
use tokio::pin;
use tracing::{error, info, instrument};

use crate::{Config, State};

#[instrument("crd watcher", skip_all)]
pub async fn run(state: Arc<State>, config: Arc<Config>) {
    let client = Client::try_default()
        .await
        .expect("failed to create kube client");

    let api = Api::<MumakPort>::all(client.clone());
    let stream = watcher::watcher(api.clone(), ConfigWatcher::default());
    pin!(stream);

    loop {
        match stream.try_next().await {
            // Stream restart, also run on startup.
            Ok(Some(Event::Restarted(_))) => {
                info!("Watcher restarted, reseting config.");
                update_configs(state.clone(), config.clone(), Some(client.clone())).await;
            }
            // New port created or updated.
            Ok(Some(Event::Applied(crd))) => match crd.status {
                Some(_) => {
                    info!(
                        "New port created or updated, updating configs: {}.",
                        crd.name_any()
                    );
                    update_configs(state.clone(), config.clone(), Some(client.clone())).await;
                }
                None => {
                    // New ports are created without status. When the status is added, a new
                    // Applied event is triggered.
                    info!("auth: New port created: {}", crd.name_any());
                }
            },
            // Port deleted.
            Ok(Some(Event::Deleted(crd))) => {
                info!("Port deleted, removing from configs: {}", crd.name_any());
                update_configs(state.clone(), config.clone(), Some(client.clone())).await;
            }
            // Empty response from stream. Should never happen.
            Ok(None) => {
                error!("Empty response from watcher.");
                continue;
            }
            // Unexpected error when streaming CRDs.
            Err(err) => {
                error!(error = err.to_string(), "auth: Failed to update crds.");
                continue;
            }
        }
    }
}

pub async fn update_configs(state: Arc<State>, config: Arc<Config>, client: Option<Client>) {
    let client = match client {
        Some(client) => client,
        None => Client::try_default()
            .await
            .expect("failed to create kube client"),
    };

    let api = Api::<MumakPort>::all(client.clone());
    match api.list(&ListParams::default()).await {
        Ok(object_list) => {
            info!("Updating users configuration.");
            let crds = object_list.items;
            let users_ini = create_users_ini(state.clone(), config.clone(), &crds).await;
            let userlist = create_userlist(config.clone(), &crds).await;

            // Update users.ini
            let mut users_ini_file = match std::fs::File::create(&config.users_ini_filepath) {
                Ok(file) => file,
                Err(err) => {
                    panic!("Failed to write to users ini file: {}", err);
                }
            };
            users_ini_file
                .write_all(&users_ini.into_bytes())
                .expect("Failed to write to users ini file.");
            users_ini_file
                .flush()
                .expect("Failed to flush into users ini file.");
            info!("Succesfully wrote users ini file.");

            // Update userlist.txt
            let mut userlist_file = match std::fs::File::create(&config.userlist_filepath) {
                Ok(file) => file,
                Err(err) => {
                    panic!("Failed to write to userlist file: {}", err);
                }
            };
            userlist_file
                .write_all(&userlist.into_bytes())
                .expect("Failed to write to userlist file.");
            userlist_file
                .flush()
                .expect("Failed to flush into userlist file.");
            info!("Succesfully wrote userlist file.");

            // Send RELOAD to PgBouncer
            reload(state).await;
        }
        Err(err) => {
            error!(
                error = err.to_string(),
                "error to get crds while updating config"
            );
        }
    };
}
pub async fn create_users_ini(
    state: Arc<State>,
    config: Arc<Config>,
    crds: &Vec<MumakPort>,
) -> String {
    let tiers = state.tiers.read().await.clone();

    let mut accummulator: Vec<String> = vec![];

    for crd in crds {
        if let Some(tier) = &crd.spec.throughput_tier {
            if tier != &config.default_tier {
                if let Some(status) = &crd.status {
                    let max_connections = match tiers.get(tier) {
                        Some(tier) => tier.max_connections,
                        None => {
                            error!("Invalid throughput tier for crd: {:?}", crd);
                            break;
                        }
                    };
                    accummulator.push(format!(
                        "{} = max_user_connections={}",
                        status.username, max_connections
                    ))
                }
            }
        }
    }

    accummulator.join("\n")
}

pub async fn create_userlist(config: Arc<Config>, crds: &Vec<MumakPort>) -> String {
    let mut accummulator: Vec<String> = vec![
        format!("\"postgres\" \"{}\"", config.postgres_password),
        format!("\"pgbouncer\" \"{}\"", config.pgbouncer_password),
    ];

    for crd in crds {
        if let Some(tier) = &crd.spec.throughput_tier {
            if tier != &config.default_tier {
                if let Some(status) = &crd.status {
                    accummulator.push(format!("\"{}\" \"{}\"", status.username, status.password))
                }
            }
        }
    }

    accummulator.join("\n")
}

pub async fn reload(state: Arc<State>) {
    match state.client.simple_query("RELOAD").await {
        Ok(_) => info!("Succesfully executed RELOAD on PgBouncer"),
        Err(err) => {
            panic!("Failed to execute RELOAD on PgBouncer: {}", err)
        }
    }
}
