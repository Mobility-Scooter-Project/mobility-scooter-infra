import os
import json
import requests
from kubernetes import client, config

# Load credentials from environment variables
auth_url = os.environ["OS_AUTH_URL"]
credential_id = os.environ["OS_APPLICATION_CREDENTIAL_ID"]
secret = os.environ["OS_APPLICATION_CREDENTIAL_SECRET"]

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
				"secret": secret
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

secret = client.V1Secret(
    metadata=client.V1ObjectMeta(name="keystone-token"),
    type="Opaque",
    string_data={"token": token}
)

try:
    v1.read_namespaced_secret("keystone-token", "external-secrets")
    v1.replace_namespaced_secret("keystone-token", "external-secrets", secret)
except client.exceptions.ApiException as e:
    if e.status == 404:
        v1.create_namespaced_secret("external-secrets", secret)
    else:
        raise
