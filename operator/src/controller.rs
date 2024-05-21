use futures::StreamExt;
use kube::{
    runtime::{controller::Action, watcher::Config as WatcherConfig, Controller},
    Api, Client, CustomResource, CustomResourceExt, ResourceExt,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::{sync::Arc, time::Duration};
use tracing::{error, info, instrument};

use crate::{patch_resource_status, Error, Metrics, Result, State};

pub static MUMAK_PORT_FINALIZER: &str = "mumakports.demeter.run";

struct Context {
    pub client: Client,
    pub metrics: Metrics,
}
impl Context {
    pub fn new(client: Client, metrics: Metrics) -> Self {
        Self { client, metrics }
    }
}

#[derive(CustomResource, Deserialize, Serialize, Clone, Debug, JsonSchema)]
#[kube(
    kind = "MumakPort",
    group = "demeter.run",
    version = "v1alpha1",
    shortname = "mumak",
    category = "demeter-port",
    namespaced
)]
#[kube(status = "MumakPortStatus")]
#[kube(printcolumn = r#"
        {"name": "Network", "jsonPath": ".spec.network", "type": "string"},
        {"name": "Throughput Tier", "jsonPath":".spec.throughputTier", "type": "string"}, 
        {"name": "Username", "jsonPath": ".status.username",  "type": "string"},
        {"name": "Password", "jsonPath": ".status.password", "type": "string"}
    "#)]
#[serde(rename_all = "camelCase")]
pub struct MumakPortSpec {
    pub network: String,
    pub throughput_tier: Option<String>,
}

#[derive(Deserialize, Serialize, Clone, Default, Debug, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct MumakPortStatus {
    pub username: String,
    pub password: String,
}

async fn reconcile(crd: Arc<MumakPort>, ctx: Arc<Context>) -> Result<Action> {
    let status = MumakPortStatus {
        username: Default::default(),
        password: Default::default(),
    };

    let namespace = crd.namespace().unwrap();
    let mumak_port = MumakPort::api_resource();

    patch_resource_status(
        ctx.client.clone(),
        &namespace,
        mumak_port,
        &crd.name_any(),
        serde_json::to_value(status)?,
    )
    .await?;

    info!(resource = crd.name_any(), "Reconcile completed");

    Ok(Action::await_change())
}

fn error_policy(crd: Arc<MumakPort>, err: &Error, ctx: Arc<Context>) -> Action {
    error!(error = err.to_string(), "reconcile failed");
    ctx.metrics.reconcile_failure(&crd, err);
    Action::requeue(Duration::from_secs(5))
}

#[instrument("controller run", skip_all)]
pub async fn run(state: Arc<State>) {
    info!("listening crds running");

    let client = Client::try_default()
        .await
        .expect("failed to create kube client");

    let crds = Api::<MumakPort>::all(client.clone());

    let ctx = Context::new(client, state.metrics.clone());

    Controller::new(crds, WatcherConfig::default().any_semantic())
        .shutdown_on_signal()
        .run(reconcile, error_policy, Arc::new(ctx))
        .filter_map(|x| async move { std::result::Result::ok(x) })
        .for_each(|_| futures::future::ready(()))
        .await;
}
