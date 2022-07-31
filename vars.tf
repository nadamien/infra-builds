variable "aws_region" {
    default = "us-east-1"
}

# variable "access_key_data" {  
#   type = map(string)
#     default ={
#       access_key = "AKIA22YDYXR6LK5NTKWV"
#     }  
# }

# variable "secret_key_data" {  
#   type = map(string)
#     default ={
#       secret_key = "kBsx3ny3Hne9IO8HS1Mz8yaGqK00dr+1tDy3lCNk"
#     }  
# }

variable "access_key" {
	default = "AKIA22YDYXR6KRCVJVHJ"
}
variable "secret_key" {
	default = "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"
}


variable "vpc_cidr_block" {
  description = "VPC CIDR"
  default = "10.0.1.0/24"
}


