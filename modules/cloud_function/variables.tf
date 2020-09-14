variable "source_dir" {
  type        = string
  description = "Path to the directory containing the source code."
}

variable "source_zip_dir" {
  type        = string
  description = "Path to the directory containing the zipped source code."

}

variable "func_description" {
  type        = string
  description = "The description of the function."
}

variable "func_region" {
  type    = string
  default = "europe-west3"
}

variable "func_available_memory_mb" {
  type    = number
  default = 128
}

variable "func_timeout" {
  type    = number
  default = 60
}

variable "func_entry_point" {
  type    = string
  default = "main"
}

variable "func_environment_variables" {
  type    = map(string)
  default = {}
}

variable "topic_name" {
  type = string
}

variable "project_name" {
  type = string
}

variable "location" {
  type    = string
  default = "EU"
}

variable "bucket_name" {
  type = string
}
