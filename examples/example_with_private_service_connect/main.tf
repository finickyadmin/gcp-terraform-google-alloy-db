/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module "alloydb_central" {
  source  = "GoogleCloudPlatform/alloy-db/google"
  version = "~> 3.0"

  cluster_id       = "cluster-${var.region_central}-psc"
  cluster_location = var.region_central
  project_id       = var.project_id

  psc_enabled                   = true
  psc_allowed_consumer_projects = [var.attachment_project_number]

  cluster_encryption_key_name = google_kms_crypto_key.key_region_central.id

  automated_backup_policy = {
    location      = var.region_central
    backup_window = "1800s"
    enabled       = true
    weekly_schedule = {
      days_of_week = ["FRIDAY"],
      start_times  = ["2:00:00:00", ]
    }
    quantity_based_retention_count = 1
    time_based_retention_count     = null
    labels = {
      test = "alloydb-cluster-with-prim"
    }
    backup_encryption_key_name = google_kms_crypto_key.key_region_central.id
  }

  continuous_backup_recovery_window_days = 10
  continuous_backup_encryption_key_name  = google_kms_crypto_key.key_region_central.id

  primary_instance = {
    instance_id        = "cluster-${var.region_central}-instance1-psc",
    require_connectors = false
    ssl_mode           = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
  }

  read_pool_instance = [
    {
      instance_id        = "cluster-${var.region_central}-r1-psc"
      display_name       = "cluster-${var.region_central}-r1-psc"
      require_connectors = false
      ssl_mode           = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    }
  ]

  depends_on = [
    google_kms_crypto_key_iam_member.alloydb_sa_iam,
    google_kms_crypto_key.key_region_central,
  ]
}

# Create psc endpoing using alloydb psc attachment

resource "google_compute_address" "psc_consumer_address" {
  name    = "psc-consumer-address"
  project = var.attachment_project_id
  region  = var.region_central

  subnetwork   = google_compute_subnetwork.psc_subnet.name
  address_type = "INTERNAL"
  address      = "10.2.0.10"
}

resource "google_compute_forwarding_rule" "psc_fwd_rule_consumer" {
  name    = "psc-fwd-rule-consumer-endpoint"
  region  = var.region_central
  project = var.attachment_project_id

  target                  = module.alloydb_central.primary_instance.psc_instance_config[0].service_attachment_link
  load_balancing_scheme   = "" # need to override EXTERNAL default when target is a service attachment
  network                 = google_compute_network.psc_vpc.name
  ip_address              = google_compute_address.psc_consumer_address.id
  allow_psc_global_access = true
}
