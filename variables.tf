variable "vcd_user" {
  type = string
}

variable "vcd_password" {
  type      = string
  sensitive = true
}
