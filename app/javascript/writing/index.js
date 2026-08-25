// The writing room's entry: everything the public site loads, plus the editor and the
// controllers only the author's pages wear. Readers never import this module, which is
// what keeps Lexxy off every public page.
import "application"
import "lexxy"
import "lexxy_embed_frames"
import "lexxy_kg_cards"

import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("writing", application)
