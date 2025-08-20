import os
import json
import requests
from kubernetes import client, config

# Load credentials from environment variables
auth_url = os.environ["OS_AUTH_URL"]
credential_id = os.environ["OS_APPLICATION_CREDENTIAL_ID"]
credential_secret = os.environ["OS_APPLICATION_CREDENTIAL_SECRET"]

# Authenticate with Keystone
resp = requests.post(
    f"{auth_url}auth/tokens",
    headers={"Content-Type": "application/json"},
    json={
	"auth": {
		"identity": {
			"methods": ["application_credential"],
			"application_credential": {
				"id": credential_id,
				"secret": credential_secret
			}
		}
	}
}
)

resp.raise_for_status()
token = resp.headers["X-Subject-Token"]

# Load in-cluster config
config.load_incluster_config()
v1 = client.CoreV1Api()

try:
    # Check if secret exists first
    v1.patch_namespaced_secret(
        name="keystone-token",
        namespace="external-secrets",
        body={
            "metadata": {
                "annotations": {
                    "external-secrets.io/type": "webhook"
                }
            },
            "stringData": {"token": token}
        }
    )
except client.exceptions.ApiException as e:
    if e.status == 404:
        # Secret doesn't exist, create it
        secret = client.V1Secret(
            metadata=client.V1ObjectMeta(
                name="keystone-token",
                annotations={"external-secrets.io/type": "webhook"}
            ),
            type="Opaque",
            string_data={"token": token}
        )
        v1.create_namespaced_secret("external-secrets", secret)
    else:
        raise
