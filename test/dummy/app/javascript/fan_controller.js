import { Controller } from "@hotwired/stimulus"

// Deals the rays a new order every time the pointer arrives, so the fan never
// opens the same way twice. It only changes which beat each ray waits for: the
// CSS still does the opening, and without this the rays simply open in order.
export default class extends Controller {
  shuffle() {
    const rays = [ ...this.element.querySelectorAll(".ray") ]
    const order = rays.map((_ray, index) => index)

    // Fisher and Yates: every order is as likely as any other, which a sort
    // with a random comparator does not promise.
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[ order[i], order[j] ] = [ order[j], order[i] ]
    }

    // Set before the hover styles resolve, so the transition that is about to
    // start reads the new delays rather than the last ones.
    rays.forEach((ray, index) => ray.style.setProperty("--ray", order[index]))
  }
}
