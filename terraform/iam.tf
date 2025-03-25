resource "google_service_account" "bastion_service_account" {
  account_id   = "${local.prfx}bastion"
  display_name = "Bastion"
}
