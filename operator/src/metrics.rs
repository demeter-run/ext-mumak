use chrono::Utc;
use http_body_util::{combinators::BoxBody, BodyExt, Full};
use hyper::{body::Bytes, server::conn::http1, service::service_fn, Response};
use hyper_util::rt::TokioIo;
use kube::{api::ListParams, Api, Client, Resource, ResourceExt};
use prometheus::{opts, Encoder, IntCounterVec, Registry, TextEncoder};
use serde::{Deserialize, Deserializer};
use std::{net::SocketAddr, str::FromStr, sync::Arc};
use tokio::net::TcpListener;
use tracing::{error, info, instrument, warn};

use crate::{get_config, Config, Error, MumakPort, State};

#[derive(Clone)]
pub struct Metrics {
    pub users_created: IntCounterVec,
    pub users_dropped: IntCounterVec,
    pub reconcile_failures: IntCounterVec,
    pub metrics_failures: IntCounterVec,
    pub dcu: IntCounterVec,
}

impl Default for Metrics {
    fn default() -> Self {
        let users_created = IntCounterVec::new(
            opts!(
                "mumak_operator_users_created_total",
                "total of users created in mumak",
            ),
            &["project", "network"],
        )
        .unwrap();

        let users_dropped = IntCounterVec::new(
            opts!(
                "mumak_operator_users_dropped_total",
                "total of users dropped in mumak",
            ),
            &["project", "network"],
        )
        .unwrap();

        let reconcile_failures = IntCounterVec::new(
            opts!(
                "mumak_operator_reconciliation_errors_total",
                "reconciliation errors",
            ),
            &["instance", "error"],
        )
        .unwrap();

        let metrics_failures = IntCounterVec::new(
            opts!(
                "mumak_operator_metrics_errors_total",
                "errors to calculation metrics",
            ),
            &["error"],
        )
        .unwrap();

        let dcu = IntCounterVec::new(
            opts!("dmtr_consumed_dcus", "quantity of dcu consumed",),
            &["project", "service", "service_type", "tenancy"],
        )
        .unwrap();

        Metrics {
            users_created,
            users_dropped,
            reconcile_failures,
            metrics_failures,
            dcu,
        }
    }
}

impl Metrics {
    pub fn register(self, registry: &Registry) -> Result<Self, prometheus::Error> {
        registry.register(Box::new(self.reconcile_failures.clone()))?;
        registry.register(Box::new(self.users_created.clone()))?;
        registry.register(Box::new(self.users_dropped.clone()))?;
        registry.register(Box::new(self.dcu.clone()))?;

        Ok(self)
    }

    pub fn reconcile_failure(&self, crd: &MumakPort, e: &Error) {
        self.reconcile_failures
            .with_label_values(&[crd.name_any().as_ref(), e.metric_label().as_ref()])
            .inc()
    }

    pub fn metrics_failure(&self, e: &Error) {
        self.metrics_failures
            .with_label_values(&[e.metric_label().as_ref()])
            .inc()
    }

    pub fn count_user_created(&self, namespace: &str, network: &str) {
        let project = get_project_id(namespace);
        self.users_created
            .with_label_values(&[&project, network])
            .inc();
    }

    pub fn count_user_dropped(&self, namespace: &str, network: &str) {
        let project = get_project_id(namespace);
        self.users_dropped
            .with_label_values(&[&project, network])
            .inc();
    }

    pub fn count_dcu_consumed(&self, namespace: &str, network: &str, dcu: f64) {
        let project = get_project_id(namespace);
        let service = format!("{}-{}", MumakPort::kind(&()), network);
        let service_type = format!("{}.{}", MumakPort::plural(&()), MumakPort::group(&()));
        let tenancy = "proxy";

        let dcu: u64 = dcu.ceil() as u64;

        self.dcu
            .with_label_values(&[&project, &service, &service_type, tenancy])
            .inc_by(dcu);
    }
}

fn get_project_id(namespace: &str) -> String {
    namespace.split_once("prj-").unwrap().1.into()
}

#[instrument("metrics collector run", skip_all)]
pub fn run_metrics_collector(state: Arc<State>) {
    tokio::spawn(async move {
        info!("collecting metrics running");

        let client = Client::try_default()
            .await
            .expect("failed to create kube client");

        let crds_api = Api::<MumakPort>::all(client.clone());

        let config = get_config();
        let mut last_execution = Utc::now();

        let current = client.default_namespace();
        dbg!(current);

        loop {
            tokio::time::sleep(config.metrics_delay).await;

            let crds_result = crds_api.list(&ListParams::default()).await;
            if let Err(error) = crds_result {
                error!(error = error.to_string(), "error to get k8s resources");
                state.metrics.metrics_failure(&error.into());
                continue;
            }
            let crds = crds_result.unwrap();

            let end = Utc::now();
            let interval = (end - last_execution).num_seconds();

            last_execution = end;

            let query = format!(
                "sum by (user) (avg_over_time(pgbouncer_pools_client_active_connections{{user=~\"dmtr_.*\"}}[{interval}s] @ {})) > 0",
                end.timestamp_millis() / 1000
            );

            let response = collect_prometheus_metrics(config, query).await;
            if let Err(err) = response {
                error!(error = err.to_string(), "error to make prometheus request");
                state.metrics.metrics_failure(&err);
                continue;
            }
            let response = response.unwrap();

            for result in response.data.result {
                let crd = crds
                    .iter()
                    .filter(|c| c.status.is_some())
                    .find(|c| c.status.as_ref().unwrap().username.eq(&result.metric.user));

                if crd.is_none() {
                    warn!(user = result.metric.user, "username doesnt have a crd");
                    continue;
                }

                let crd = crd.unwrap();

                let dcu_per_second = config.dcu_per_second.get(&crd.spec.network);
                if dcu_per_second.is_none() {
                    let error = Error::ConfigError(format!(
                        "dcu_per_second not configured to {} network",
                        &crd.spec.network
                    ));
                    error!(error = error.to_string());
                    state.metrics.metrics_failure(&error);
                    continue;
                }

                let dcu_per_second = dcu_per_second.unwrap();
                let total_exec_time = result.value * (interval as f64);

                let dcu = total_exec_time * dcu_per_second;
                state
                    .metrics
                    .count_dcu_consumed(&crd.namespace().unwrap(), &crd.spec.network, dcu);
            }
        }
    });
}

async fn collect_prometheus_metrics(
    config: &Config,
    query: String,
) -> Result<PrometheusResponse, Error> {
    let client = reqwest::Client::builder().build().unwrap();

    let response = client
        .get(format!("{}/query?query={query}", config.prometheus_url))
        .send()
        .await?;

    let status = response.status();
    if status.is_client_error() || status.is_server_error() {
        error!(status = status.to_string(), "request status code fail");
        return Err(Error::HttpError(format!(
            "Prometheus request error. Status: {} Query: {}",
            status, query
        )));
    }

    Ok(response.json().await.unwrap())
}

pub fn run_metrics_server(state: Arc<State>) {
    tokio::spawn(async move {
        let addr = std::env::var("ADDR").unwrap_or("0.0.0.0:8080".into());
        let addr_result = SocketAddr::from_str(&addr);
        if let Err(err) = addr_result {
            error!(error = err.to_string(), "invalid prometheus addr");
            std::process::exit(1);
        }
        let addr = addr_result.unwrap();

        let listener_result = TcpListener::bind(addr).await;
        if let Err(err) = listener_result {
            error!(
                error = err.to_string(),
                "fail to bind tcp prometheus server listener"
            );
            std::process::exit(1);
        }
        let listener = listener_result.unwrap();

        info!(addr = addr.to_string(), "metrics listening");

        loop {
            let state = state.clone();

            let accept_result = listener.accept().await;
            if let Err(err) = accept_result {
                error!(error = err.to_string(), "accept client prometheus server");
                continue;
            }
            let (stream, _) = accept_result.unwrap();

            let io = TokioIo::new(stream);

            tokio::task::spawn(async move {
                let service = service_fn(move |_| api_get_metrics(state.clone()));

                if let Err(err) = http1::Builder::new().serve_connection(io, service).await {
                    error!(error = err.to_string(), "failed metrics server connection");
                }
            });
        }
    });
}

async fn api_get_metrics(
    state: Arc<State>,
) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
    let metrics = state.metrics_collected();

    let encoder = TextEncoder::new();
    let mut buffer = vec![];
    encoder.encode(&metrics, &mut buffer).unwrap();

    let res = Response::builder()
        .body(
            Full::new(buffer.into())
                .map_err(|never| match never {})
                .boxed(),
        )
        .unwrap();
    Ok(res)
}

#[derive(Debug, Deserialize)]
struct PrometheusDataResultMetric {
    user: String,
}

#[derive(Debug, Deserialize)]
struct PrometheusDataResult {
    metric: PrometheusDataResultMetric,
    #[serde(deserialize_with = "deserialize_value")]
    value: f64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PrometheusData {
    result: Vec<PrometheusDataResult>,
}

#[derive(Debug, Deserialize)]
struct PrometheusResponse {
    data: PrometheusData,
}

fn deserialize_value<'de, D>(deserializer: D) -> Result<f64, D::Error>
where
    D: Deserializer<'de>,
{
    let value: Vec<serde_json::Value> = Deserialize::deserialize(deserializer)?;
    Ok(value.into_iter().as_slice()[1]
        .as_str()
        .unwrap()
        .parse::<f64>()
        .unwrap())
}
