provider "aci" {
  # Set via environment: ACI_URL, ACI_USERNAME, ACI_PASSWORD
  # (or ACI_PRIVATE_KEY + ACI_CERT_NAME for certificate auth).
  insecure = true
}

module "aci" {
  # Vendored copy of netascode/nac-aci/aci v2.1.0 (registry is unreachable
  # when airgapped). To upgrade, see README.md.
  source = "./vendor/nac-aci"

  yaml_directories = ["data"]

  # Only tenants are on. Every other section also pushes fabric-wide defaults
  # (AAA/password profile, banners, ISIS, MCP, err-disable recovery, QoS,
  # endpoint controls ...) even when the YAML doesn't mention them. Review a
  # plan before turning one on against a live fabric.
  manage_tenants            = true
  manage_access_policies    = false
  manage_fabric_policies    = false
  manage_pod_policies       = false
  manage_node_policies      = false
  manage_interface_policies = false
}
