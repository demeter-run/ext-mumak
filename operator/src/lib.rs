use std::{
    collections::HashMap,
    io::{self, ErrorKind},
};

use postgres::Postgres;
use prometheus::Registry;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("Kube Error: {0}")]
    KubeError(#[source] kube::Error),

    #[error("Finalizer Error: {0}")]
    FinalizerError(#[source] Box<kube::runtime::finalizer::Error<Error>>),

    #[error("Deserialize Error: {0}")]
    DeserializeError(#[source] serde_json::Error),

    #[error("Parse Network error: {0}")]
    ParseNetworkError(String),

    #[error("Http Request error: {0}")]
    HttpError(String),

    #[error("Config Error: {0}")]
    ConfigError(String),

    #[error("Sha256 Error: {0}")]
    Sha256Error(String),

    #[error("Bech32 Encode Error: {0}")]
    Bech32EncodeError(#[source] bech32::EncodeError),

    #[error("Hrp Parse Error: {0}")]
    HrpBech32Error(#[source] bech32::primitives::hrp::Error),

    #[error("Argon Error: {0}")]
    ArgonError(String),

    #[error("Postgres Error: {0}")]
    PgError(String),
}

impl Error {
    pub fn metric_label(&self) -> String {
        format!("{self:?}").to_lowercase()
    }
}
impl From<serde_json::Error> for Error {
    fn from(value: serde_json::Error) -> Self {
        Error::DeserializeError(value)
    }
}
impl From<kube::Error> for Error {
    fn from(value: kube::Error) -> Self {
        Error::KubeError(value)
    }
}
impl From<reqwest::Error> for Error {
    fn from(value: reqwest::Error) -> Self {
        Error::HttpError(value.to_string())
    }
}
impl From<bech32::EncodeError> for Error {
    fn from(value: bech32::EncodeError) -> Self {
        Error::Bech32EncodeError(value)
    }
}
impl From<bech32::primitives::hrp::Error> for Error {
    fn from(value: bech32::primitives::hrp::Error) -> Self {
        Error::HrpBech32Error(value)
    }
}
impl From<tokio_postgres::Error> for Error {
    fn from(value: tokio_postgres::Error) -> Self {
        Error::PgError(value.to_string())
    }
}
impl From<deadpool_postgres::BuildError> for Error {
    fn from(value: deadpool_postgres::BuildError) -> Self {
        Error::PgError(value.to_string())
    }
}
impl From<deadpool_postgres::PoolError> for Error {
    fn from(value: deadpool_postgres::PoolError) -> Self {
        Error::PgError(value.to_string())
    }
}
impl From<Error> for io::Error {
    fn from(value: Error) -> Self {
        Self::new(ErrorKind::Other, value)
    }
}
impl From<argon2::Error> for Error {
    fn from(value: argon2::Error) -> Self {
        Error::ArgonError(value.to_string())
    }
}

#[derive(Clone)]
pub struct State {
    registry: Registry,
    pub metrics: Metrics,
    pub pg_connections: HashMap<String, Vec<Postgres>>,
}
impl State {
    pub async fn try_new() -> Result<Self, Error> {
        let config = get_config();

        let registry = Registry::default();
        let metrics = Metrics::default().register(&registry).unwrap();

        let mut pg_connections: HashMap<String, Vec<Postgres>> = HashMap::new();
        for (network, db_name) in config.db_names.iter() {
            let mut connections: Vec<Postgres> = Vec::new();
            for url in config.db_urls.iter() {
                let connection =
                    Postgres::try_new(&format!("{}/{}", url, db_name), &config.db_max_connections)
                        .await?;
                connections.push(connection);
            }

            pg_connections.insert(network.clone(), connections);
        }

        Ok(Self {
            registry,
            metrics,
            pg_connections,
        })
    }

    pub fn metrics_collected(&self) -> Vec<prometheus::proto::MetricFamily> {
        self.registry.gather()
    }

    pub fn get_pg_by_network(&self, network: &str) -> Result<&Vec<Postgres>, Error> {
        if let Some(connections) = self.pg_connections.get(network) {
            return Ok(connections);
        }

        Err(Error::ConfigError(format!(
            "postgres not configured to {network}"
        )))
    }
}

pub use k8s_openapi;
pub use kube;

pub type Result<T, E = Error> = std::result::Result<T, E>;

pub mod controller;
pub use crate::controller::*;

pub mod metrics;
pub use metrics::*;

mod config;
pub use config::*;

mod utils;
pub use utils::*;

pub mod postgres;
