# Offline check that data/*.yaml renders: plans against a mocked ACI provider,
# so no APIC is needed.  terraform test
mock_provider "aci" {}

run "plan" {
  command = plan
}
