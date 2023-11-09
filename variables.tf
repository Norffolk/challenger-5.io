# variables.tf

# com a variável instance_count nós definimos quantas instâncias vão ser criadas
variable "instance_count" {
  default = "3"
}

# nessa variável definimos o nome das VMs
variable "instance_tags" {
  type    = list(string)
  default = ["server01", "server02", "server03",]
}

# Aqui definimos a imagem da AWS que vamos utilizar, nesse caso é a do ubuntu
variable "ami" {
  type    = string
  default = "ami-0fc5d935ebf8bc3bc"
}

# Aqui o tipo da instância, de acordo com a AWS; t2.micro significa que não haverá custos de criação para esse tipo de instância
variable "instance_type" {
  type    = string
  default = "t2.micro"
}

# output.tf vai nos retornar esses valores na tela após a criação
output "server-data" {
  value = [for vm in aws_instance.server[*] : {
    ip_address = vm.public_ip
    public_dns = vm.public_dns
  }]
  description = "The public IP and DNS of the servers"
}
