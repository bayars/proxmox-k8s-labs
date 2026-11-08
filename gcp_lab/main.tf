terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.14"
    }
  }
}

# Main Terraform file to deploy VM instances in Google Cloud Platform

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

provider "google" {
  project = var.gcp_project_id
  region  = "us-central1"   # Replace with your desired region
  zone    = "us-central1-a" # Replace with your desired zone
}

# Create the dtmgmt network and subnet
/* resource "google_compute_network" "dtmgmt" { */
/*   name                    = "dtmgmt" */
/*   auto_create_subnetworks = false */
/*   mtu                     = 1460 */
/*   routing_mode            = "REGIONAL" */
/* } */

/* resource "google_compute_subnetwork" "dtmgmt" { */
/*   name          = "dtmgmt" */
/*   ip_cidr_range = "10.2.1.0/24" */
/*   network       = google_compute_network.dtmgmt.id */
/*   region        = "us-central1" */
/* } */

/* # Firewall rules for dtmgmt */
/* resource "google_compute_firewall" "dtmgmt_allow_custom" { */
/*   name    = "dtmgmt-allow-custom" */
/*   network = google_compute_network.dtmgmt.id */

/*   allow { */
/*     protocol = "all" */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */

/* resource "google_compute_firewall" "dtmgmt_allow_icmp" { */
/*   name    = "dtmgmt-allow-icmp" */
/*   network = google_compute_network.dtmgmt.id */

/*   allow { */
/*     protocol = "icmp" */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */

/* resource "google_compute_firewall" "dtmgmt_allow_rdp" { */
/*   name    = "dtmgmt-allow-rdp" */
/*   network = google_compute_network.dtmgmt.id */

/*   allow { */
/*     protocol = "tcp" */
/*     ports    = ["3389"] */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */

/* resource "google_compute_firewall" "dtmgmt_allow_vxlan" { */
/*   name    = "dtmgmt-allow-vxlan" */
/*   network = google_compute_network.dtmgmt.id */

/*   allow { */
/*     protocol = "udp" */
/*     ports    = ["4789"] */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */

/* resource "google_compute_firewall" "dtmgmt_allow_ssh" { */
/*   name    = "dtmgmt-allow-ssh" */
/*   network = google_compute_network.dtmgmt.id */

/*   allow { */
/*     protocol = "tcp" */
/*     ports    = ["22"] */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */

# Create the clabmgmt network and subnet
/* resource "google_compute_network" "clabmgmt" { */
/*   name                    = "clabmgmt" */
/*   auto_create_subnetworks = false */
/*   mtu                     = 1460 */
/*   routing_mode            = "REGIONAL" */
/* } */

/* resource "google_compute_subnetwork" "clabmgmt" { */
/*   name          = "clabmgmt" */
/*   ip_cidr_range = "10.10.10.0/24" */
/*   network       = google_compute_network.clabmgmt.id */
/*   region        = "us-central1" */
/* } */

/* # Firewall rules for clabmgmt */
/* resource "google_compute_firewall" "clabmgmt_allow_custom" { */
/*   name    = "clabmgmt-allow-custom" */
/*   network = google_compute_network.clabmgmt.id */

/*   allow { */
/*     protocol = "all" */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */

/* resource "google_compute_firewall" "clabmgmt_allow_icmp" { */
/*   name    = "clabmgmt-allow-icmp" */
/*   network = google_compute_network.clabmgmt.id */

/*   allow { */
/*     protocol = "icmp" */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */

/* resource "google_compute_firewall" "clabmgmt_allow_rdp" { */
/*   name    = "clabmgmt-allow-rdp" */
/*   network = google_compute_network.clabmgmt.id */

/*   allow { */
/*     protocol = "tcp" */
/*     ports    = ["3389"] */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */

/* resource "google_compute_firewall" "clabmgmt_allow_vxlan" { */
/*   name    = "clabmgmt-allow-vxlan" */
/*   network = google_compute_network.clabmgmt.id */

/*   allow { */
/*     protocol = "udp" */
/*     ports    = ["4789"] */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */

/* resource "google_compute_firewall" "clabmgmt_allow_ssh" { */
/*   name    = "clabmgmt-allow-ssh" */
/*   network = google_compute_network.clabmgmt.id */

/*   allow { */
/*     protocol = "tcp" */
/*     ports    = ["22"] */
/*   } */

/*   source_ranges = ["0.0.0.0/0"] */
/*   direction     = "INGRESS" */
/*   priority      = 65534 */
/* } */


resource "google_compute_instance" "k8s_controller" {
  name           = "k8s-controller"
  machine_type   = "n1-standard-4" # Replace with your desired machine type
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  /* network_interface { */
  /*   network    = google_compute_network.dtmgmt.id */
  /*   subnetwork = google_compute_subnetwork.dtmgmt.id */
  /*   network_ip = "10.2.1.2" # Static IP */
  /* } */

  /* network_interface { */
  /*   network    = google_compute_network.clabmgmt.id */
  /*   subnetwork = google_compute_subnetwork.clabmgmt.id */
  /*   network_ip = "10.10.10.2" # Static IP */
  /* } */

  tags = ["k8s-controller"]
}

resource "google_compute_instance" "k8s_worker1" {
  name           = "k8s-worker1"
  machine_type   = "n1-standard-4"
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  /* network_interface { */
  /*   network    = google_compute_network.dtmgmt.id */
  /*   subnetwork = google_compute_subnetwork.dtmgmt.id */
  /*   network_ip = "10.2.1.3" # Static IP */
  /* } */

  /* network_interface { */
  /*   network    = google_compute_network.clabmgmt.id */
  /*   subnetwork = google_compute_subnetwork.clabmgmt.id */
  /*   network_ip = "10.10.10.3" # Static IP */
  /* } */

  tags = ["k8s-worker"]
}

resource "google_compute_instance" "k8s_worker2" {
  name           = "k8s-worker2"
  machine_type   = "n1-standard-4"
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  /* network_interface { */
  /*   network    = google_compute_network.dtmgmt.id */
  /*   subnetwork = google_compute_subnetwork.dtmgmt.id */
  /*   network_ip = "10.2.1.4" # Static IP */
  /* } */

  /* network_interface { */
  /*   network    = google_compute_network.clabmgmt.id */
  /*   subnetwork = google_compute_subnetwork.clabmgmt.id */
  /*   network_ip = "10.10.10.4" # Static IP */
  /* } */

  tags = ["k8s-worker"]
}

# Outputs for convenience
output "k8s_controller_ip" {
  value = google_compute_instance.k8s_controller.network_interface[0].access_config[0].nat_ip
}

output "k8s_worker1_ip" {
  value = google_compute_instance.k8s_worker1.network_interface[0].access_config[0].nat_ip
}

/* output "k8s_worker2_ip" { */
/*   value = google_compute_instance.k8s_worker2.network_interface[0].access_config[0].nat_ip */
/* } */

