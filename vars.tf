variable "aws_region" {
    default = "us-east-1"
}

# variable "access_key_data" {  
#   type = map(string)
#     default ={
#       access_key = "<Acceee Key>"
#     }  
# }

# variable "secret_key_data" {  
#   type = map(string)
#     default ={
#       secret_key = "<Security Key"
#     }  
# }

variable "access_key" {
	default = "<Acceee Key>"
}
variable "secret_key" {
	default = "<Security Key>"
}


# variable "vpc_cidr_block" {
#   description = "VPC CIDR"
#   default = "10.0.1.0/24"
# }
