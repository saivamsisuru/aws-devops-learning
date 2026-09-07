terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
  }

  required_version = ">= 1.0"
}

provider "local" {
}

resource "local_file" "hello" {
  filename = "hello.txt"
  content  = "Hello! I am learning Terraform."
}
