use std::{env, path::PathBuf, time::Duration};

#[derive(Debug, Clone)]
pub struct Config {
    pub default_tier: String,
    pub tiers_path: PathBuf,
    pub tiers_poll_interval: Duration,
    pub postgres_password: String,
    pub pgbouncer_password: String,
    pub users_ini_filepath: PathBuf,
    pub userlist_filepath: PathBuf,
    pub connection_options: String,
}
impl Config {
    pub fn new() -> Self {
        Self {
            default_tier: env::var("DEFAULT_TIER").unwrap_or("0".into()),
            tiers_path: env::var("TIERS_PATH")
                .map(|v| v.into())
                .expect("TIERS_PATH must be set"),
            tiers_poll_interval: env::var("TIERS_POLL_INTERVAL")
                .map(|v| {
                    Duration::from_secs(
                        v.parse::<u64>()
                            .expect("TIERS_POLL_INTERVAL must be a number in seconds. eg: 2"),
                    )
                })
                .unwrap_or(Duration::from_secs(2)),
            postgres_password: env::var("POSTGRES_PASSWORD").expect("POSTGRES_PASSWORD missing"),
            pgbouncer_password: env::var("PGBOUNCER_PASSWORD").expect("PGBOUNCER_PASSWORD missing"),
            users_ini_filepath: env::var("USERS_INI_FILEPATH")
                .map(|v| v.into())
                .expect("USERS_INI_FILEPATH must be set"),
            userlist_filepath: env::var("USERLIST_FILEPATH")
                .map(|v| v.into())
                .expect("USERLIST_FILEPATH must be set"),
            connection_options: env::var("CONNECTION_OPTIONS")
                .unwrap_or("host=localhost user=pgbouncer".into()),
        }
    }
}
impl Default for Config {
    fn default() -> Self {
        Self::new()
    }
}
