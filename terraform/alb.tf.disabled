module "gce-lb-http" {
  source  = "terraform-google-modules/lb-http/google"
  version = "~> 12.0"
  name    = "${local.prfx}lb-http"
  project = local.gcp_project_id
  target_tags = [
    # "${var.network_prefix}-group1",
    module.cloud-nat-group1.router_name,
  ]
  firewall_networks = [module.vpc.network_self_link]

  backends = {
    default = {

      protocol    = "HTTP"
      port        = 80
      port_name   = "http"
      timeout_sec = 10
      enable_cdn  = false

      health_check = {
        request_path = "/"
        port         = 80
      }

      log_config = {
        enable      = false
        # sample_rate = 1.0
      }

      groups = [
        {
          group = module.mig1.instance_group
        }
      ]

      iap_config = {
        enable = false
      }
    }
  }
}
