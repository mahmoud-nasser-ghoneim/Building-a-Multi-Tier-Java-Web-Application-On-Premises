terraform {

  required_providers {

    vcd = {

      source  = "vmware/vcd"

      version = ">= 3.10"

    }

  }

}



provider "vcd" {

  user                 = var.vcd_user

  password             = var.vcd_password

  org                  = "COT-1"

  vdc                  = "COT-1"

  url                  = "https://vdc.rayacloud.com/api"

  allow_unverified_ssl = true

}

