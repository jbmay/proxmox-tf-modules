# Copyright 2024 Defense Unicorns
# SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-Defense-Unicorns-Commercial

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.70.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.3"
    }
  }
  required_version = ">= 1.7.1"
}
