use config::Config;
use dotenv::dotenv;
use std::collections::HashMap;
use std::{io, sync::Arc};
use tokio::sync::RwLock;
use tracing::{error, Level};

mod config;
mod tiers;
mod watch;

use tiers::Tier;

pub struct State {
    pub tiers: RwLock<HashMap<String, Tier>>,
    pub client: tokio_postgres::Client,
}

impl State {
    pub fn new(client: tokio_postgres::Client) -> State {
        State {
            client,
            tiers: RwLock::new(HashMap::new()),
        }
    }
}

#[tokio::main]
async fn main() -> io::Result<()> {
    dotenv().ok();

    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    let config = Arc::new(Config::default());
    let (client, connection) =
        tokio_postgres::connect(&config.connection_options, tokio_postgres::NoTls)
            .await
            .expect("Unable to connect to PgBouncer instance, panicking");

    let state = Arc::new(State::new(client));

    tokio::join!(
        watch::run(state.clone(), config.clone()),
        tiers::run(state.clone(), config.clone()),
        async move {
            if let Err(e) = connection.await {
                error!("connection error: {}", e);
            }
        }
    );

    Ok(())
}
