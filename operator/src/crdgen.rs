use kube::CustomResourceExt;
use operator::controller;

fn main() {
    print!(
        "{}",
        serde_yaml::to_string(&controller::MumakPort::crd()).unwrap()
    )
}
