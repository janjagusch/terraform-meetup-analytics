variable "project_id" {
  type        = string
  description = "ID of the GCP project where to create the infrastructure."
}

variable "schedule" {
  type        = string
  description = "Crontab for requesting Meetup data"
  default     = "0 0 * * *"
}

variable "meetup_group_id" {
  type        = string
  description = "ID of the Meetup group to request data from"
}

variable "meetup_client_id" {
  type        = string
  description = "ID of the Meetup client"
}

variable "meetup_client_secret" {
  type        = string
  description = "Secret of the Meetup client"
}

variable "meetup_blob_name" {
  type        = string
  description = "Name of the GCS blob where the Meetup token is stored"
  default     = "token.json"
}

variable "meetup_force_rsvps" {
  type        = bool
  description = "Deprecated: Please use 'meetup_force_past_events' instead."
  default     = true
}

variable "meetup_force_past_events" {
  type        = bool
  description = "Whether to force requesting Meetup RSVPs and attendances even though the event is in the past"
  default     = true
}
