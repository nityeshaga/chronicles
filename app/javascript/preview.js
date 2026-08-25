// The preview page wears the public layout — and so the public entry, which is what makes
// it an honest preview — but its strip needs one controller the public never does. Pulled
// in by the strip alone, so no reader's page asks for it.
import { application } from "controllers/application"
import PreviewController from "writing/preview_controller"

application.register("preview", PreviewController)
