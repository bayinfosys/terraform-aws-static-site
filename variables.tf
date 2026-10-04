variable "bucket_name" {
  type = string
}

variable "aliases" {
  type = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate in us-east-1 covering the aliases"
  type        = string
}

variable "comment" {
  type    = string
  default = ""
}

variable "origin_id" {
  type    = string
  default = "s3-site"
}

variable "price_class" {
  type    = string
  default = "PriceClass_100"
}

variable "default_root_object" {
  type    = string
  default = "index.html"
}

variable "error_page" {
  type    = string
  default = "/404.html"
}

variable "minimum_protocol_version" {
  type    = string
  default = "TLSv1.2_2021"
}

variable "cache_policy_name" {
  type    = string
  default = "Managed-CachingOptimized"
}

variable "response_headers_policy_name" {
  type    = string
  default = "Managed-SecurityHeadersPolicy"
}

variable "manage_dns" {
  description = "Create A and AAAA alias records in zone_id"
  type        = bool
  default     = false
}

variable "zone_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
