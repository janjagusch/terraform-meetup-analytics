locals {
  source_zip_dir = "./.source_zip"
}

terraform {
  backend "gcs" {
    bucket = "meetup-analytics-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project
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

# Buckets

resource "google_storage_bucket" "tokens" {
  name          = "meetup-analytics-token"
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
  name     = "meetup-analytics-functions"
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

  schema = <<EOF
[
    {
        "name": "id",
        "type": "INTEGER",
        "mode": "REQUIRED"
    },
    {
        "name": "created_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "joined_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "updated_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "visited_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "role",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "location",
        "type": "RECORD",
        "mode": "REQUIRED",
        "fields": [
            {
                "name": "country",
                "type": "STRING",
                "mode": "REQUIRED"
            },
            {
                "name": "city",
                "type": "STRING",
                "mode": "REQUIRED"
            },
            {
                "name": "geo",
                "type": "RECORD",
                "mode": "REQUIRED",
                "fields": [
                    {
                        "name": "lon",
                        "type": "FLOAT",
                        "mode": "REQUIRED"
                    },
                    {
                        "name": "lat",
                        "type": "FLOAT",
                        "mode": "REQUIRED"
                    }
                ]
            }
        ]
    },
    {
        "name": "requested_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "inserted_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    }
]
EOF

}

resource "google_bigquery_table" "events" {
  dataset_id  = google_bigquery_dataset.meetup.dataset_id
  table_id    = "events"
  description = "Events of a meetup group"

  schema = <<EOF
[
    {
        "name": "id",
        "type": "INTEGER",
        "mode": "REQUIRED"
    },
    {
        "name": "name",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "group_id",
        "type": "INTEGER",
        "mode": "REQUIRED"
    },
    {
        "name": "started_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "duration",
        "type": "INTEGER",
        "mode": "REQUIRED",
        "description": "Duration in  seconds"
    },
    {
        "name": "rsvp_limit",
        "type": "INTEGER",
        "mode": "NULLABLE"
    },
    {
        "name": "status",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "yes_rsvp_count",
        "type": "INTEGER",
        "mode": "REQUIRED"
    },
    {
        "name": "waitlist_count",
        "type": "INTEGER",
        "mode": "REQUIRED"
    },
    {
        "name": "venue",
        "type": "RECORD",
        "mode": "REQUIRED",
        "fields": [
            {
                "name": "name",
                "type": "STRING",
                "mode": "REQUIRED"
            },
            {
                "name": "location",
                "type": "RECORD",
                "mode": "REQUIRED",
                "fields": [
                    {
                        "name": "country",
                        "type": "STRING",
                        "mode": "REQUIRED"
                    },
                    {
                        "name": "city",
                        "type": "STRING",
                        "mode": "REQUIRED"
                    },
                    {
                        "name": "geo",
                        "type": "RECORD",
                        "mode": "REQUIRED",
                        "fields": [
                            {
                                "name": "lon",
                                "type": "FLOAT",
                                "mode": "REQUIRED"
                            },
                            {
                                "name": "lat",
                                "type": "FLOAT",
                                "mode": "REQUIRED"
                            }
                        ]
                    }
                ]
            }
        ]
    },
    {
        "name": "is_online_event",
        "type": "BOOLEAN",
        "mode": "REQUIRED"
    },
    {
        "name": "visibility",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "pro_is_email_shared",
        "type": "BOOLEAN",
        "mode": "REQUIRED"
    },
    {
        "name": "member_pay_fee",
        "type": "BOOLEAN",
        "mode": "REQUIRED"
    },
    {
        "name": "created_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "updated_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "requested_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "inserted_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    }
]
EOF

}


resource "google_bigquery_table" "rsvps" {
  dataset_id  = google_bigquery_dataset.meetup.dataset_id
  table_id    = "rsvps"
  description = "RSVPs of a meetup event"

  schema = <<EOF
[
    {
        "name": "member_id",
        "type": "INTEGER",
        "mode": "REQUIRED"
    },
    {
        "name": "event_id",
        "type": "INTEGER",
        "mode": "REQUIRED"
    },
    {
        "name": "group_id",
        "type": "INTEGER",
        "mode": "REQUIRED"
    },
    {
        "name": "response",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "guests",
        "type": "INTEGER",
        "mode": "REQUIRED"
    },
    {
        "name": "created_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "updated_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "requested_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    },
    {
        "name": "inserted_at",
        "type": "DATETIME",
        "mode": "REQUIRED"
    }
]
EOF

}

resource "google_pubsub_topic" "meetup-request" {
  name = "meetup-request"
}

# Cloud functions

# Functions.
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
    BUCKET_NAME   = var.meetup_bucket_name
    BLOB_NAME     = var.meetup_blob_name
    PROJECT_ID    = var.project
    FORCE_RSVPS   = var.meetup_force_rsvps ? 1 : 0
  }
}
