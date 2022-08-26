use anyhow::Result;
use clap::Parser;
use futures::{future::join_all, join};
use warp::Filter;

mod controller;
mod webhook;

#[derive(Parser, Debug)]
#[clap(author = "Alan Diego <alandiegosantos@gmail.com>", version = "0.0.1-alpha1", about, long_about = None)]
struct Parameters {
    #[clap(
        long,
        value_delimiter = ',',
        value_name = "controllers",
        default_value = "*"
    )]
    controllers: Vec<String>,
    #[clap(long, value_name = "cert-file", default_value = "")]
    cert_file: std::path::PathBuf,
    #[clap(long, value_name = "cert-key", default_value = "")]
    cert_key: std::path::PathBuf,
    #[clap(long, value_name = "http-addr", default_value = "0.0.0.0:8443")]
    http_addr: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let flags = Parameters::parse();

    tracing_subscriber::fmt::init();

    let controllers: Vec<controller::ControllerFn> =
        controller::enabled_controllers(&flags.controllers)?;

    let client = kube::Client::try_default().await?;

    let enabled_controllers = controllers
        .iter()
        .map(|controller| controller(client.clone()));

    let routes = warp::path("/")
        .and(webhook::pod::register_hook(client.clone()))
        .with(warp::trace::request());

    let webserver = warp::serve(routes)
        .tls()
        .cert_path(flags.cert_file)
        .key_path(flags.cert_key)
        .run(flags.http_addr.parse::<std::net::SocketAddr>().unwrap());

    join!(join_all(enabled_controllers), webserver);

    Ok(())
}
