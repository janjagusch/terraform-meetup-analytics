locals {
  source_zip_dir = "${path.module}/.source_zip"
}

provider "google" {
  project = var.project_id
  region  = "europe-west3"
}

# APIs

resource "google_project_service" "cloudfunctions" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"

  disable_dependent_services = true
}


resource "google_project_service" "cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "clouderrorreporting" {
  project = var.project_id
  service = "clouderrorreporting.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "cloudscheduler" {
  project = var.project_id
  service = "cloudscheduler.googleapis.com"

  disable_dependent_services = true
}

# Buckets

resource "google_storage_bucket" "tokens" {
  name          = "${var.project_id}-meetup-analytics-token"
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
  name     = "${var.project_id}-meetup-analytics-functions"
  location = "EU"
}

# BigQuery datasets

resource "google_bigquery_dataset" "meetup-raw" {
  dataset_id    = "meetup_raw"
  friendly_name = "meetup raw"
  description   = "Raw data from Meetup API"
  location      = "EU"
}

resource "google_bigquery_dataset" "meetup-analytics" {
  dataset_id    = "meetup_analytics"
  friendly_name = "meetup analytics"
  description   = "Meetup data suitable for analytics"
  location      = "EU"
}

# BigQuery tables

resource "google_bigquery_table" "members" {
  dataset_id  = google_bigquery_dataset.meetup-raw.dataset_id
  table_id    = "members"
  description = "Members of a meetup group"

  schema = file("${path.module}/bigquery/tables/members.json")

}

resource "google_bigquery_table" "events" {
  dataset_id  = google_bigquery_dataset.meetup-raw.dataset_id
  table_id    = "events"
  description = "Events of a meetup group"

  schema = file("${path.module}/bigquery/tables/events.json")

}


resource "google_bigquery_table" "rsvps" {
  dataset_id  = google_bigquery_dataset.meetup-raw.dataset_id
  table_id    = "rsvps"
  description = "RSVPs of a meetup event"

  schema = file("${path.module}/bigquery/tables/rsvps.json")

}

resource "google_pubsub_topic" "meetup-request" {
  name = "meetup-request"
}

# BigQuery views

resource "google_bigquery_table" "events-latest" {
  dataset_id  = google_bigquery_dataset.meetup-analytics.dataset_id
  table_id    = "events_latest"
  description = "The latest revision for events"
  view {
    query          = file("${path.module}/bigquery/views/events_latest.sql")
    use_legacy_sql = false
  }
}

resource "google_bigquery_table" "members-daily" {
  dataset_id  = google_bigquery_dataset.meetup-analytics.dataset_id
  table_id    = "members_daily"
  description = "Daily information about members"
  view {
    query          = file("${path.module}/bigquery/views/members_daily.sql")
    use_legacy_sql = false
  }
}

resource "google_bigquery_table" "rsvps-daily" {
  dataset_id  = google_bigquery_dataset.meetup-analytics.dataset_id
  table_id    = "rsvps_daily"
  description = "Daily information about RSVPs"
  view {
    query          = file("${path.module}/bigquery/views/rsvps_daily.sql")
    use_legacy_sql = false
  }
}

# Cloud functions

module "cloud_function_meetup_api_to_bigquery" {
  source = "./modules/cloud_function"

  source_dir       = "${path.module}/cloud_functions/meetup-api-to-bigquery"
  source_zip_dir   = local.source_zip_dir
  func_description = "Requests data from Meetup API and inserts it into Google BigQuery"
  topic_name       = google_pubsub_topic.meetup-request.name
  project_name     = var.project_id
  bucket_name      = google_storage_bucket.functions.name
  func_environment_variables = {
    CLIENT_ID     = var.meetup_client_id
    CLIENT_SECRET = var.meetup_client_secret
    BUCKET_NAME   = google_storage_bucket.tokens.name
    BLOB_NAME     = var.meetup_blob_name
    PROJECT_ID    = var.project_id
    FORCE_RSVPS   = var.meetup_force_rsvps ? 1 : 0
  }
}

# App engine

resource "google_app_engine_application" "app" {
  project     = var.project_id
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
