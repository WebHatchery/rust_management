/*
 * Shared "Report a Bug" widget for WebHatchery Rust games.
 *
 * Self-contained, no dependencies. Include on a game page with:
 *   <link rel="stylesheet" href="../bug-report.css">
 *   <div id="roost-bug-report" data-roost-slug="rust_<game>"></div>
 *   <script src="../bug-report.js"></script>
 *
 * Config via data-* on the mount element:
 *   data-roost-slug    project slug in Project Roost (default: derived from the URL path).
 *   data-roost-api     API base (default: /project_roost/api/v1, same host as the game).
 *   data-roost-version optional game version string, attached to the report.
 *
 * Submissions are moderated in Project Roost before they ever reach the Fix Queue,
 * and the backend re-validates everything — this file only handles UX.
 */
(function () {
  "use strict";

  var mount = document.getElementById("roost-bug-report");
  if (!mount) {
    return;
  }

  var apiBase = (mount.getAttribute("data-roost-api") || "/project_roost/api/v1").replace(/\/$/, "");
  var slug = mount.getAttribute("data-roost-slug") || deriveSlug();
  var version = mount.getAttribute("data-roost-version") || "";

  var challenge = null;
  var loadingChallenge = false;

  var trigger = document.createElement("button");
  trigger.type = "button";
  trigger.className = "roost-br-trigger";
  trigger.setAttribute("aria-haspopup", "dialog");
  trigger.textContent = "🐛 Report a Bug";

  var overlay = document.createElement("div");
  overlay.className = "roost-br-overlay";
  overlay.setAttribute("role", "dialog");
  overlay.setAttribute("aria-modal", "true");
  overlay.setAttribute("aria-label", "Report a bug");
  overlay.innerHTML =
    '<div class="roost-br-modal">' +
    '  <div class="roost-br-head">' +
    "    <h2>Report a Bug</h2>" +
    '    <button type="button" class="roost-br-close" aria-label="Close">&times;</button>' +
    "  </div>" +
    '  <div class="roost-br-body">' +
    '    <p class="roost-br-note">Thanks for helping improve this game. Reports are reviewed before anything is acted on.</p>' +
    '    <form class="roost-br-form" novalidate>' +
    '      <div class="roost-br-field">' +
    '        <label for="roost-br-summary">Summary <span aria-hidden="true">*</span></label>' +
    '        <input id="roost-br-summary" name="summary" type="text" maxlength="140" required autocomplete="off">' +
    "      </div>" +
    '      <div class="roost-br-field">' +
    '        <label for="roost-br-desc">What happened? <span aria-hidden="true">*</span></label>' +
    '        <textarea id="roost-br-desc" name="description" rows="5" maxlength="4000" required></textarea>' +
    "      </div>" +
    '      <div class="roost-br-field">' +
    '        <label for="roost-br-contact">Contact (optional)</label>' +
    '        <input id="roost-br-contact" name="contact" type="text" maxlength="190" autocomplete="off" placeholder="email or handle, if you want a reply">' +
    "      </div>" +
    '      <div class="roost-br-field roost-br-hp" aria-hidden="true">' +
    '        <label for="roost-br-website">Leave this field empty</label>' +
    '        <input id="roost-br-website" name="website" type="text" tabindex="-1" autocomplete="off">' +
    "      </div>" +
    '      <div class="roost-br-actions">' +
    '        <button type="submit" class="roost-br-submit">Send report</button>' +
    "      </div>" +
    '      <div class="roost-br-status" role="status" aria-live="polite"></div>' +
    "    </form>" +
    "  </div>" +
    "</div>";

  document.body.appendChild(trigger);
  document.body.appendChild(overlay);

  var form = overlay.querySelector(".roost-br-form");
  var statusEl = overlay.querySelector(".roost-br-status");
  var submitBtn = overlay.querySelector(".roost-br-submit");
  var closeBtn = overlay.querySelector(".roost-br-close");
  var summaryInput = overlay.querySelector("#roost-br-summary");

  trigger.addEventListener("click", openModal);
  closeBtn.addEventListener("click", closeModal);
  overlay.addEventListener("click", function (event) {
    if (event.target === overlay) {
      closeModal();
    }
  });
  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && overlay.classList.contains("roost-br-open")) {
      closeModal();
    }
  });
  form.addEventListener("submit", onSubmit);

  function openModal() {
    overlay.classList.add("roost-br-open");
    setStatus("", "");
    fetchChallenge();
    window.setTimeout(function () {
      summaryInput.focus();
    }, 30);
  }

  function closeModal() {
    overlay.classList.remove("roost-br-open");
  }

  function fetchChallenge() {
    if (challenge || loadingChallenge) {
      return;
    }
    loadingChallenge = true;
    fetch(apiBase + "/bug-reports/challenge", { method: "GET", credentials: "omit" })
      .then(function (res) {
        return res.json();
      })
      .then(function (body) {
        if (body && body.success && body.data && body.data.challenge) {
          challenge = body.data.challenge;
        }
      })
      .catch(function () {
        /* Non-fatal: submit will surface a friendly retry message. */
      })
      .finally(function () {
        loadingChallenge = false;
      });
  }

  function onSubmit(event) {
    event.preventDefault();

    var summary = form.summary.value.trim();
    var description = form.description.value.trim();

    if (summary.length === 0 || description.length < 10) {
      setStatus("Please add a short summary and a bit more detail.", "err");
      return;
    }

    if (!challenge) {
      setStatus("Still preparing the form — please try again in a moment.", "err");
      fetchChallenge();
      return;
    }

    var payload = {
      project_slug: slug,
      summary: summary,
      description: description,
      contact: form.contact.value.trim(),
      website: form.website.value, // honeypot
      challenge: challenge,
      game_version: version,
      page_url: window.location.href.slice(0, 500)
    };

    submitBtn.disabled = true;
    setStatus("Sending…", "");

    fetch(apiBase + "/bug-reports", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "omit",
      body: JSON.stringify(payload)
    })
      .then(function (res) {
        return res.json().then(function (body) {
          return { ok: res.ok, body: body };
        });
      })
      .then(function (result) {
        if (result.ok && result.body && result.body.success) {
          setStatus("Thanks! Your report was received.", "ok");
          form.reset();
          challenge = null; // one challenge per submission
          window.setTimeout(closeModal, 1500);
        } else {
          var message = (result.body && result.body.message) || "Something went wrong. Please try again.";
          setStatus(message, "err");
          challenge = null;
          fetchChallenge();
        }
      })
      .catch(function () {
        setStatus("Could not reach the server. Please try again later.", "err");
      })
      .finally(function () {
        submitBtn.disabled = false;
      });
  }

  function setStatus(message, kind) {
    statusEl.textContent = message;
    statusEl.className = "roost-br-status" + (kind ? " roost-br-" + kind : "");
  }

  // Derive a Rust game slug from the URL when data-roost-slug is absent, e.g.
  // https://webhatchery.au/games/ai_defense/ -> rust_ai_defense.
  function deriveSlug() {
    var parts = window.location.pathname.split("/").filter(Boolean);
    var dir = parts.length ? parts[parts.length - 1] : "";
    if (/\.[a-z0-9]+$/i.test(dir) && parts.length >= 2) {
      dir = parts[parts.length - 2]; // strip a trailing index.html
    }
    dir = dir.replace(/[^a-z0-9_]/gi, "_").toLowerCase();
    return dir ? "rust_" + dir : "rust_unknown";
  }
})();
