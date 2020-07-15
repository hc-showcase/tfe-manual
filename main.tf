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

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_instance" "tfe" {
  name         = "tfe"
  machine_type = "n1-standard-8"
  zone         = "europe-west3-a"
  hostname     = "tfe.msk.pub"

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

data "google_dns_managed_zone" "dns_zone" {
  name = "msk-pub"
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
