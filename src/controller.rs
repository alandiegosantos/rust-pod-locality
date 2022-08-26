use std::collections::{HashMap, HashSet};
use std::future::Future;
use std::pin::Pin;
use std::rc::Rc;

pub mod pod;

pub type ControllerFn = Rc<dyn Fn(kube::Client) -> Pin<Box<dyn Future<Output = ()>>>>;

fn all_controllers() -> HashMap<&'static str, ControllerFn> {
    let mut controllers: HashMap<&str, ControllerFn> = Default::default();
    controllers.insert("podLocality", Rc::new(|client| Box::pin(pod::run(client))));

    return controllers;
}

pub fn enabled_controllers(
    enabled_controllers_name: &Vec<String>,
) -> Result<Vec<ControllerFn>, std::io::Error> {
    let all_controllers = all_controllers();

    let enabled_controllers_ids: HashSet<String> =
        enabled_controllers_name.iter().map(|x| x.clone()).collect();

    let enabled_controllers: Vec<ControllerFn> = all_controllers
        .iter()
        .filter(|(name, _)| {
            (enabled_controllers_ids.contains(&String::from("*"))
                || enabled_controllers_ids.contains(&name.to_string()))
                && !enabled_controllers_ids.contains(&format!("-{}", name))
        })
        .map(|(_, controller_fn)| Rc::clone(&controller_fn))
        .collect();

    Ok(enabled_controllers)
}
