terraform {
  required_version = ">= 1.0.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.88.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

provider "yandex" {}

provider "time" {}
