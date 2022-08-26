use anyhow::Result;
use futures::StreamExt;
use json_patch::{AddOperation, PatchOperation, ReplaceOperation};
use k8s_openapi::api::core::v1::{Node, Pod};
use kube::api::{Api, ListParams, Patch, PatchParams};
use kube::runtime::controller::{Action, Controller};
use kube::ResourceExt;
use std::sync::Arc;
use thiserror::Error;
use tokio::time::Duration;
use tracing::*;

const TOPOLOGY_REGION_LABEL: &'static str = "topology.kubernetes.io/region";
const TOPOLOGY_ZONE_LABEL: &'static str = "topology.kubernetes.io/zone";
const TOPOLOGY_SUBZONE_LABEL: &'static str = "topology.kubernetes.io/subzone";

#[derive(Debug, Error)]
enum ControllerError {
    #[error("Failed to label pod: {0}")]
    PodLabelFailed(#[source] kube::Error),
    #[error("MissingObjectKey: {0}")]
    MissingObjectKey(&'static str),
}

pub async fn run(client: kube::Client) {
    let pods = Api::<Pod>::all(client.clone());

    let controller = Controller::new(pods, ListParams::default())
        .run(
            reconcile,
            error_policy,
            Arc::new(PodLocalityContext { client }),
        )
        .for_each(|res| async move {
            match res {
                Ok(o) => info!("reconciled {:?}", o),
                Err(e) => warn!("reconcile failed: {}", e),
            }
        });

    controller.await;
}

struct PodLocalityContext {
    client: kube::Client,
}

async fn reconcile(
    generator: Arc<Pod>,
    ctx: Arc<PodLocalityContext>,
) -> Result<Action, ControllerError> {
    let client = &ctx.client;

    let pod = generator.as_ref();

    let pod_api = Api::<Pod>::namespaced(
        client.clone(),
        generator
            .metadata
            .namespace
            .as_ref()
            .ok_or(ControllerError::MissingObjectKey(".metadata.namespace"))?,
    );

    if let Some(spec) = pod.spec.as_ref() {
        if let Some(node_name) = spec.node_name.as_ref() {
            let node_api = Api::<Node>::all(client.clone());

            let node = node_api
                .get(&node_name)
                .await
                .map_err(ControllerError::PodLabelFailed)?;

            let mut patches: Vec<PatchOperation> = vec![];

            if let Some(region) = node.labels().get(TOPOLOGY_REGION_LABEL) {
                if let Some(patch) = add_or_update_label(pod, "region", region) {
                    patches.push(patch)
                }
            }
            if let Some(zone) = node.labels().get(TOPOLOGY_ZONE_LABEL) {
                if let Some(patch) = add_or_update_label(pod, "zone", zone) {
                    patches.push(patch)
                }
            }
            if let Some(subzone) = node.labels().get(TOPOLOGY_SUBZONE_LABEL) {
                if let Some(patch) = add_or_update_label(pod, "subzone", subzone) {
                    patches.push(patch)
                }
            }

            if patches.len() > 0 {
                pod_api
                    .patch(
                        generator
                            .metadata
                            .name
                            .as_ref()
                            .ok_or(ControllerError::MissingObjectKey(".metadata.name"))?,
                        &PatchParams::default(),
                        &Patch::Json::<()>(json_patch::Patch(patches)),
                    )
                    .await
                    .map_err(ControllerError::PodLabelFailed)?;
            }
        }
    }

    Ok(Action::await_change())
}

/// The controller triggers this on reconcile errors
fn error_policy(_error: &ControllerError, _ctx: Arc<PodLocalityContext>) -> Action {
    Action::requeue(Duration::from_secs(1))
}

fn add_or_update_label(pod: &Pod, label: &str, value: &String) -> Option<PatchOperation> {
    if let Some(pod_label) = pod.labels().get(label) {
        if pod_label.eq(value) {
            return None;
        }

        return Some(PatchOperation::Replace(ReplaceOperation {
            path: "/metadata/labels/".to_string() + label,
            value: serde_json::Value::String(value.clone()),
        }));
    }
    return Some(PatchOperation::Add(AddOperation {
        path: "/metadata/labels/".to_string() + label,
        value: serde_json::Value::String(value.clone()),
    }));
}
