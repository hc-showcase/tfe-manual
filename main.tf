variable "project" {
  default = "mkaesz" 
}

provider "google" {
  credentials = file("~/.config/gcloud/application_default_credentials.json")
  project     = var.project
}

resource "google_compute_firewall" "default" {
  name    = "tfe-firewall"
  network = data.google_compute_network.default.name

  allow {
    protocol = "tcp"
    ports    = ["80", "8800", "443"]
  }

  target_tags = ["tfe"]
}

resource "google_sql_database_instance" "tfe" {
  name             = "tfe"
  database_version = "POSTGRES_11"
  region           = "europe-west3"

  settings {
    tier = "db-g1-small"
  }
}

resource "google_sql_database" "database" {
  name     = "tfe"
  instance = google_sql_database_instance.tfe.name
}

resource "google_sql_user" "users" {
  name     = "tfe"
  instance = google_sql_database_instance.tfe.name
  password = "tfe"
}

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_instance" "tfe" {
  name         = "tfe"
  machine_type = "n1-standard-8"
  zone         = "europe-west3-a"
  hostname     = "tfe.gcp.msk.pub"

  tags = ["tfe", "manual"]

  boot_disk {
    initialize_params {
      image = "centos-7-v20200618"
      size  = 100
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}

resource "google_storage_bucket" "tfe" {
  name          = "mkaesz-tfe"
  location      = "EU"
  force_destroy = true
}

resource "google_service_account" "bucket" {
  account_id   = "mkaesz-tfe-bucket"
  display_name = "Used by Terraform Enterprise to authenticate with GCS Bucket."
  description  = "TFE to GCS Bucket auth."
}

resource "google_service_account_key" "bucket" {
  service_account_id = google_service_account.bucket.name
}

resource "google_storage_bucket_iam_member" "member-object" {
  bucket = google_storage_bucket.tfe.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.bucket.email}"
}

resource "google_storage_bucket_iam_member" "member-bucket" {
  bucket = google_storage_bucket.tfe.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.bucket.email}"
}

data "google_dns_managed_zone" "dns_zone" {
  name = "gcp-msk-pub-zone"
}

resource "google_dns_record_set" "dns" {
  name = "tfe.${data.google_dns_managed_zone.dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.dns_zone.name

  rrdatas = [google_compute_instance.tfe.network_interface[0].access_config[0].nat_ip]
}

output "tfe" {
  value = google_compute_instance.tfe
}
