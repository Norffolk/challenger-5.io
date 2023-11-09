# variables.tf

# below we define with the variable instance_count how many servers we want to create
variable "instance_count" {
  default = "3"
}

# below we define the default server names
variable "instance_tags" {
  type    = list(string)
  default = ["server01", "server02", "server03",]
}

# we use Ubuntu as the OS
variable "ami" {
  type    = string
  default = "ami-0fc5d935ebf8bc3bc"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}


# output.tf

output "server-data" {
  value = [for vm in aws_instance.server[*] : {
    ip_address = vm.public_ip
    public_dns = vm.public_dns
  }]
  description = "The public IP and DNS of the servers"
}
