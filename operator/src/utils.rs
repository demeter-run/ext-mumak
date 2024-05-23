use argon2::Argon2;
use base64::prelude::*;
use bech32::{Bech32m, Hrp};
use kube::{
    api::{Patch, PatchParams},
    core::DynamicObject,
    discovery::ApiResource,
    Api, Client, ResourceExt,
};
use serde_json::json;

use crate::{get_config, Error, MumakPort};

pub async fn patch_resource_status(
    client: Client,
    namespace: &str,
    api_resource: ApiResource,
    name: &str,
    payload: serde_json::Value,
) -> Result<(), kube::Error> {
    let api: Api<DynamicObject> = Api::namespaced_with(client, namespace, &api_resource);

    let status = json!({ "status": payload });
    let patch_params = PatchParams::default();
    api.patch_status(name, &patch_params, &Patch::Merge(status))
        .await?;
    Ok(())
}

pub fn build_username(crd: &MumakPort) -> Result<String, Error> {
    let namespace = crd.namespace().unwrap();

    let name = format!("mumak-username-{}", &crd.name_any());

    let username = format!("{}{}", name, namespace).as_bytes().to_vec();

    let config = get_config();
    let salt = config.key_salt.as_bytes();

    let mut output = vec![0; 16];

    let argon2 = Argon2::default();
    if argon2
        .hash_password_into(username.as_slice(), salt, &mut output)
        .is_err()
    {
        return Err(Error::ArgonError("Error to hash a password".into()));
    }

    let hrp = Hrp::parse("dmtr_mumak")?;
    let bech = bech32::encode::<Bech32m>(hrp, &output)?;

    Ok(bech)
}

pub fn build_password(crd: &MumakPort) -> Result<String, Error> {
    let namespace = crd.namespace().unwrap();

    let name = format!("mumak-password-{}", &crd.name_any());

    let username = format!("{}{}", name, namespace).as_bytes().to_vec();

    let config = get_config();
    let salt = config.key_salt.as_bytes();

    let mut output = vec![0; 16];

    let argon2 = Argon2::default();
    if argon2
        .hash_password_into(username.as_slice(), salt, &mut output)
        .is_err()
    {
        return Err(Error::ArgonError("Error to hash a password".into()));
    }

    let password = BASE64_STANDARD.encode(output);

    Ok(password)
}
