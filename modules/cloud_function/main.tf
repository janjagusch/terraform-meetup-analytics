locals {
  func_name = basename(var.source_dir)
  file_name = "${local.func_name}.zip"
}

data "archive_file" "source_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${var.source_zip_dir}/${local.file_name}"
}

resource "google_storage_bucket_object" "archive_zip" {
  name   = local.file_name
  bucket = var.bucket_name
  source = data.archive_file.source_zip.output_path
}

resource "google_cloudfunctions_function" "function" {
  name                  = "${local.func_name}-${replace(replace(trim(google_storage_bucket_object.archive_zip.md5hash, "="), "+", "-"), "/", "_")}"
  region                = var.func_region
  description           = var.func_description
  available_memory_mb   = var.func_available_memory_mb
  source_archive_bucket = var.bucket_name
  source_archive_object = google_storage_bucket_object.archive_zip.name
  timeout               = var.func_timeout
  entry_point           = var.func_entry_point
  runtime               = "python37"
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "projects/${var.project_name}/topics/${var.topic_name}"
  }

  environment_variables = var.func_environment_variables
}
