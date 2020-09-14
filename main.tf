locals {
  source_zip_dir = "./.source_zip"
}

provider "google" {
  project = var.project
  region  = "europe-west3"
}

# APIs

resource "google_project_service" "cloudfunctions" {
  project = var.project
  service = "cloudfunctions.googleapis.com"

  disable_dependent_services = true
}


resource "google_project_service" "cloudbuild" {
  project = var.project
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "clouderrorreporting" {
  project = var.project
  service = "clouderrorreporting.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "cloudscheduler" {
  project = var.project
  service = "cloudscheduler.googleapis.com"

  disable_dependent_services = true
}

# Buckets

resource "google_storage_bucket" "tokens" {
  name          = "${var.project}-meetup-analytics-token"
  location      = "EU"
  force_destroy = true

  lifecycle_rule {
    condition {
      num_newer_versions = "3"
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "functions" {
  name     = "${var.project}-meetup-analytics-functions"
  location = "EU"
}

resource "google_bigquery_dataset" "meetup" {
  dataset_id    = "meetup"
  friendly_name = "meetup"
  description   = "Meetup analytics data"
  location      = "EU"
}

resource "google_bigquery_table" "members" {
  dataset_id  = google_bigquery_dataset.meetup.dataset_id
  table_id    = "members"
  description = "Members of a meetup group"

  schema = file("./bigquery/tables/members.json")

}

resource "google_bigquery_table" "events" {
  dataset_id  = google_bigquery_dataset.meetup.dataset_id
  table_id    = "events"
  description = "Events of a meetup group"

  schema = file("./bigquery/tables/events.json")

}


resource "google_bigquery_table" "rsvps" {
  dataset_id  = google_bigquery_dataset.meetup.dataset_id
  table_id    = "rsvps"
  description = "RSVPs of a meetup event"

  schema = file("./bigquery/tables/rsvps.json")

}

resource "google_pubsub_topic" "meetup-request" {
  name = "meetup-request"
}

# Cloud functions

module "cloud_function_meetup_api_to_bigquery" {
  source = "./modules/cloud_function"

  source_dir       = "./cloud_functions/meetup-api-to-bigquery"
  source_zip_dir   = local.source_zip_dir
  func_description = "Requests data from Meetup API and inserts it into Google BigQuery"
  topic_name       = google_pubsub_topic.meetup-request.name
  project_name     = var.project
  bucket_name      = google_storage_bucket.functions.name
  func_environment_variables = {
    CLIENT_ID     = var.meetup_client_id
    CLIENT_SECRET = var.meetup_client_secret
    BUCKET_NAME   = google_storage_bucket.tokens.name
    BLOB_NAME     = var.meetup_blob_name
    PROJECT_ID    = var.project
    FORCE_RSVPS   = var.meetup_force_rsvps ? 1 : 0
  }
}

# App engine

resource "google_app_engine_application" "app" {
  project     = var.project
  location_id = "europe-west3"
}

# Cloud scheduler

resource "google_cloud_scheduler_job" "meetup-request" {
  name      = "meetup-request"
  schedule  = var.schedule
  time_zone = "Europe/Berlin"

  pubsub_target {
    topic_name = google_pubsub_topic.meetup-request.id
    data       = base64encode("{\"group_id\": \"${var.meetup_group_id}\"}")
  }

  depends_on = [
    google_app_engine_application.app
  ]
}
