use json_patch::{AddOperation, Patch, PatchOperation, ReplaceOperation};
use k8s_openapi::api::core::v1::{Node, Pod};
use kube::api::Api;
use kube::core::{
    admission::{AdmissionRequest, AdmissionResponse, AdmissionReview},
    ResourceExt,
};
use std::convert::Infallible;
use std::convert::TryInto;
use tracing::*;
use warp::{reply, Filter, Rejection, Reply};

const TOPOLOGY_REGION_LABEL: &'static str = "topology.kubernetes.io/region";
const TOPOLOGY_ZONE_LABEL: &'static str = "topology.kubernetes.io/zone";
const TOPOLOGY_SUBZONE_LABEL: &'static str = "topology.kubernetes.io/subzone";

pub fn register_hook(
    client: kube::Client,
) -> impl Filter<Extract = (impl Reply,), Error = Rejection> + Clone {
    let node_api_filter = warp::any().map(move || Api::<Node>::all(client.clone()));

    return warp::post()
        .and(warp::path("mutate_locality_pod"))
        .and(warp::body::json())
        .and(node_api_filter)
        .and_then(mutate_handler);
}

async fn mutate_handler(
    body: AdmissionReview<Pod>,
    node_api: Api<Node>,
) -> Result<impl warp::Reply, Infallible> {
    let req: AdmissionRequest<Pod> = match body.try_into() {
        Ok(req) => req,
        Err(err) => {
            return Ok(reply::json(
                &AdmissionResponse::invalid(err.to_string()).into_review(),
            ));
        }
    };

    info!("Mutating virtualservice");

    // Then construct a AdmissionResponse
    let mut res = AdmissionResponse::from(&req);

    if let Some(pod) = req.object {
        if let Some(spec) = pod.spec.as_ref() {
            if let Some(node_name) = spec.node_name.as_ref() {
                if let Ok(node) = node_api.get(&node_name).await {
                    res = match mutate(res.clone(), &pod, &node) {
                        Ok(resp) => resp,
                        Err(err) => res.deny(err.to_string()),
                    }
                }
            }
        }
    }

    // Wrap the AdmissionResponse wrapped in an AdmissionReview
    Ok(reply::json(&res.into_review()))
}

fn mutate(
    res: AdmissionResponse,
    pod: &Pod,
    node: &Node,
) -> Result<AdmissionResponse, Box<dyn std::error::Error>> {
    let mut patches: Vec<PatchOperation> = vec![];
    if let Some(region) = node.labels().get(TOPOLOGY_REGION_LABEL) {
        if let Some(patch) = add_or_update_label(&pod, "region", region) {
            patches.push(patch)
        }
    }
    if let Some(zone) = node.labels().get(TOPOLOGY_ZONE_LABEL) {
        if let Some(patch) = add_or_update_label(&pod, "zone", zone) {
            patches.push(patch)
        }
    }
    if let Some(subzone) = node.labels().get(TOPOLOGY_SUBZONE_LABEL) {
        if let Some(patch) = add_or_update_label(&pod, "subzone", subzone) {
            patches.push(patch)
        }
    }

    Ok(res.with_patch(Patch(patches))?)
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
