data "vcd_catalog" "cat" {
  org  = "COT-1"
  name = "Eslam"
}

data "vcd_catalog_vapp_template" "ubuntu" {
  org        = "COT-1"
  catalog_id = data.vcd_catalog.cat.id
  name       = "Ubuntu-25-10-live-server"
}

resource "vcd_vapp" "vpro" {
  name        = "nasser-terraform-multi-tier-project"
  description = "vprofile multi-tier project"
}

resource "vcd_vapp_org_network" "net" {
  vapp_name        = vcd_vapp.vpro.name
  org_network_name = "Nasser-test"
}

resource "vcd_vapp_vm" "db01" {
  vapp_name        = vcd_vapp.vpro.name
  name             = "db01"
  computer_name    = "db01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  memory           = 2048
  cpus             = 2
  cpu_cores        = 1

  network {
    type               = "org"
    name               = vcd_vapp_org_network.net.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = "30.0.0.10"
    is_primary         = true
  }

  customization {
    enabled = true
    force   = false
  }
}

resource "vcd_vapp_vm" "mc01" {
  vapp_name        = vcd_vapp.vpro.name
  name             = "mc01"
  computer_name    = "mc01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  memory           = 1024
  cpus             = 2
  cpu_cores        = 1

  network {
    type               = "org"
    name               = vcd_vapp_org_network.net.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = "30.0.0.20"
    is_primary         = true
  }

  customization {
    enabled = true
    force   = false
  }
}

resource "vcd_vapp_vm" "rmq01" {
  vapp_name        = vcd_vapp.vpro.name
  name             = "rmq01"
  computer_name    = "rmq01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  memory           = 2048
  cpus             = 2
  cpu_cores        = 1

  network {
    type               = "org"
    name               = vcd_vapp_org_network.net.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = "30.0.0.30"
    is_primary         = true
  }

  customization {
    enabled = true
    force   = false
  }
}

resource "vcd_vapp_vm" "app01" {
  vapp_name        = vcd_vapp.vpro.name
  name             = "app01"
  computer_name    = "app01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  memory           = 4096
  cpus             = 2
  cpu_cores        = 1

  network {
    type               = "org"
    name               = vcd_vapp_org_network.net.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = "30.0.0.40"
    is_primary         = true
  }

  customization {
    enabled = true
    force   = false
  }
}

resource "vcd_vapp_vm" "web01" {
  vapp_name        = vcd_vapp.vpro.name
  name             = "web01"
  computer_name    = "web01"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  memory           = 1024
  cpus             = 2
  cpu_cores        = 1

  network {
    type               = "org"
    name               = vcd_vapp_org_network.net.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = "30.0.0.50"
    is_primary         = true
  }

  customization {
    enabled = true
    force   = false
  }
}
