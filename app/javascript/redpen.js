// The red pen's entry: pulled in by the rail alone, so a reader's page never asks for it.
// Imports Turbo itself because on a verbatim HTML page the site's own entry never runs.
import "@hotwired/turbo-rails"
import { application } from "controllers/application"
import RedpenController from "redpen_controller"

application.register("redpen", RedpenController)
