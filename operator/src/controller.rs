use futures::{future, StreamExt};
use kube::{
    runtime::{
        controller::Action,
        finalizer::{finalizer, Event},
        watcher::Config as WatcherConfig,
        Controller,
    },
    Api, Client, CustomResource, CustomResourceExt, ResourceExt,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::{sync::Arc, time::Duration};
use tracing::{error, info, instrument};

use crate::{
    build_password, build_username, patch_resource_status, postgres::Postgres, Error, Result, State,
};

pub static MUMAK_PORT_FINALIZER: &str = "mumakports.demeter.run";

struct Context {
    pub client: Client,
    pub state: Arc<State>,
}
impl Context {
    pub fn new(client: Client, state: Arc<State>) -> Self {
        Self { client, state }
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
    pub username: Option<String>,
    pub password: Option<String>,
}
impl MumakPort {
    async fn reconcile(
        &self,
        ctx: Arc<Context>,
        pg_connections: &[Postgres],
    ) -> Result<Action, Error> {
        let ns = self.namespace().unwrap();
        let name = self.name_any();

        let mumak_port = MumakPort::api_resource();

        let status = MumakPortStatus {
            username: match &self.spec.username {
                Some(username) => username.clone(),
                None => build_username(self)?,
            },
            password: match &self.spec.password {
                Some(password) => password.clone(),
                None => build_password(self)?,
            },
        };

        if self.status.is_none() {
            patch_resource_status(
                ctx.client.clone(),
                &ns,
                mumak_port,
                &name,
                serde_json::to_value(status.clone())?,
            )
            .await?;

            info!({ status.username }, "user created");
            ctx.state
                .metrics
                .count_user_created(&ns, &self.spec.network);
        }

        let tasks = future::join_all(
            pg_connections
                .iter()
                .map(|pg| pg.create_user(&status.username, &status.password)),
        )
        .await;

        if tasks.iter().any(Result::is_err) {
            return Err(Error::PgError("fail to create user".into()));
        }

        info!(resource = name, "Reconcile completed");
        Ok(Action::await_change())
    }

    async fn cleanup(
        &self,
        ctx: Arc<Context>,
        pg_connections: &[Postgres],
    ) -> Result<Action, Error> {
        if self.status.is_some() {
            let ns = self.namespace().unwrap();
            let username = self.status.as_ref().unwrap().username.clone();

            let tasks =
                future::join_all(pg_connections.iter().map(|pg| pg.drop_user(&username))).await;
            if tasks.iter().any(Result::is_err) {
                return Err(Error::PgError("fail to drop user".into()));
            }

            info!({ username }, "user dropped");
            ctx.state
                .metrics
                .count_user_dropped(&ns, &self.spec.network);
        }

        Ok(Action::await_change())
    }
}

#[derive(Deserialize, Serialize, Clone, Debug, JsonSchema)]
#[serde(rename_all = "camelCase")]
pub struct MumakPortStatus {
    pub username: String,
    pub password: String,
}

async fn reconcile(crd: Arc<MumakPort>, ctx: Arc<Context>) -> Result<Action> {
    let ns = crd.namespace().unwrap();
    let crds: Api<MumakPort> = Api::namespaced(ctx.client.clone(), &ns);

    let pg_connections = ctx.state.get_pg_by_network(&crd.spec.network)?;

    finalizer(&crds, MUMAK_PORT_FINALIZER, crd, |event| async {
        match event {
            Event::Apply(crd) => crd.reconcile(ctx.clone(), pg_connections).await,
            Event::Cleanup(crd) => crd.cleanup(ctx.clone(), pg_connections).await,
        }
    })
    .await
    .map_err(|e| Error::FinalizerError(Box::new(e)))
}

fn error_policy(crd: Arc<MumakPort>, err: &Error, ctx: Arc<Context>) -> Action {
    error!(error = err.to_string(), "reconcile failed");
    ctx.state.metrics.reconcile_failure(&crd, err);
    Action::requeue(Duration::from_secs(5))
}

#[instrument("controller run", skip_all)]
pub async fn run(state: Arc<State>) {
    info!("listening crds running");

    let client = Client::try_default()
        .await
        .expect("failed to create kube client");

    let crds = Api::<MumakPort>::all(client.clone());

    let ctx = Context::new(client, state.clone());

    Controller::new(crds, WatcherConfig::default().any_semantic())
        .shutdown_on_signal()
        .run(reconcile, error_policy, Arc::new(ctx))
        .filter_map(|x| async move { std::result::Result::ok(x) })
        .for_each(|_| futures::future::ready(()))
        .await;
}
