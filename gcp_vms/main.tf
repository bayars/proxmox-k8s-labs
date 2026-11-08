terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
  }
}

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for the network and instance names"
  type        = string
  default     = "k8s-lab"
}

provider "google" {
  project = var.gcp_project_id
  region  = "us-central1" # Change to your preferred region
}

resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-net"
  auto_create_subnetworks = true
}

resource "google_compute_instance" "instances" {
  count        = 6
  name         = "${var.name_prefix}-${count.index}"
  machine_type = "e2-standard-4"
  zone         = "us-central1-a" # Change as needed

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = google_compute_network.lab.self_link
    access_config {} # Assigns a public IP
  }
}

