// Progressive enhancement: the pages work without JavaScript, and this file
// adds the PayMongo checkout redirect and the purchase-status polling.

(function () {
  "use strict";

  function setStatus(form, message, kind) {
    const target = form.querySelector("#checkout-status");
    if (!target) return;
    target.textContent = message || "";
    target.className = "form-status" + (kind ? ` is-${kind}` : "");
  }

  function setupCheckout() {
    const form = document.getElementById("checkout-form");
    if (!form || form.dataset.paymentsConfigured !== "true") return;

    const button = form.querySelector('button[type="submit"]');

    form.addEventListener("submit", async (event) => {
      event.preventDefault();

      if (!form.checkValidity()) {
        form.reportValidity();
        return;
      }

      const data = new FormData(form);
      const plan = data.get("plan");
      const email = String(data.get("email") || "").trim();

      if (!plan) {
        setStatus(form, "Choose a Premium pass first.", "error");
        return;
      }
      if (!email) {
        setStatus(form, "Enter the email you use for Locmate.", "error");
        return;
      }

      const originalLabel = button.textContent;
      button.disabled = true;
      button.textContent = "Starting secure checkout…";
      setStatus(form, "Opening PayMongo…", "info");

      try {
        const response = await fetch("/api/checkout", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ plan, email }),
        });

        const result = await response.json().catch(() => ({}));

        if (!response.ok || !result.checkoutUrl) {
          throw new Error(
            result.message ||
              "We could not start checkout. Please try again in a moment.",
          );
        }

        window.location.assign(result.checkoutUrl);
      } catch (error) {
        setStatus(form, error.message, "error");
        button.disabled = false;
        button.textContent = originalLabel;
      }
    });
  }

  function formatPlan(plan) {
    return plan === "annual" ? "Annual Premium" : "Monthly Premium";
  }

  function setupStatusPolling() {
    const card = document.getElementById("status-card");
    if (!card) return;

    const reference = card.dataset.ref;
    const initial = card.dataset.status;
    if (!reference || initial === "granted") return;

    const title = document.getElementById("status-title");
    const body = document.getElementById("status-body");
    let attempts = 0;
    const maxAttempts = 30;

    const timer = setInterval(async () => {
      attempts += 1;

      try {
        const response = await fetch(
          `/api/purchase-status?ref=${encodeURIComponent(reference)}`,
          { headers: { Accept: "application/json" } },
        );
        if (response.ok) {
          const result = await response.json();
          if (result.status === "granted" && title && body) {
            clearInterval(timer);
            card.dataset.status = "granted";
            card.classList.remove("status-pending", "status-unknown");
            card.classList.add("status-granted");
            title.textContent = "Premium is active";
            body.textContent = `Your ${formatPlan(result.plan)} pass (${
              result.days
            } days) has been applied to your Locmate account. Open the app and sign in to see it.`;
            return;
          }
        }
      } catch {
        // Keep polling; a transient network error is not a failed payment.
      }

      if (attempts >= maxAttempts) {
        clearInterval(timer);
        setStatusText(
          body,
          "We are still confirming this payment. PayMongo will keep retrying, and Premium will appear automatically once it is confirmed.",
        );
      }
    }, 4000);
  }

  function setStatusText(element, message) {
    if (!element) return;
    const paragraph = element.querySelector("p");
    if (paragraph) {
      paragraph.textContent = message;
    } else {
      element.textContent = message;
    }
  }

  function setupFaq() {
    // Details elements already work natively; this just keeps only one open at
    // a time for a calmer reading experience.
    const items = Array.from(document.querySelectorAll(".faq-item"));
    for (const item of items) {
      item.addEventListener("toggle", () => {
        if (!item.open) return;
        for (const other of items) {
          if (other !== item) other.open = false;
        }
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => {
      setupCheckout();
      setupStatusPolling();
      setupFaq();
    });
  } else {
    setupCheckout();
    setupStatusPolling();
    setupFaq();
  }
})();
