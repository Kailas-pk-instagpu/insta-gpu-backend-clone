/*
 * DEV ONLY. "Sign in as" picker on the login page: fills a seeded demo user's credentials and signs in, so each role can be tried without typing.
 * Part of the dev-only theme "instagpu-dev" (used by infra/keycloak/realm-instagpu.dev.json). Real realms use the theme "instagpu",
 * which does not contain this file. These accounts and their shared password exist only in the dev realm file.
 */
(function () {
  var USERS = [
    { label: "Super admin - Farah Aziz", user: "farah@instagpu.my" },
    { label: "Sales manager (admin) - Sara Tan", user: "sara.tan@instagpu.my" },
    { label: "Cafe owner - Jason Wong", user: "jason@klgamingarena.my" },
    { label: "Floor manager (manager) - Priya Nair", user: "priya@klgamingarena.my" }
  ];
  var PASSWORD = "Instagpu-dev-2026!";
  function init() {
    var u = document.getElementById("username"), p = document.getElementById("password");
    if (!u || !p || !u.form || document.getElementById("ig-dev-picker")) return;
    var box = document.createElement("div");
    box.id = "ig-dev-picker";
    box.className = "ig-dev-picker";
    var label = document.createElement("label");
    label.htmlFor = "ig-dev-select";
    label.textContent = "Dev only: sign in as";
    var sel = document.createElement("select");
    sel.id = "ig-dev-select";
    var first = document.createElement("option");
    first.value = ""; first.textContent = "Choose a role...";
    sel.appendChild(first);
    USERS.forEach(function (x) { var o = document.createElement("option"); o.value = x.user; o.textContent = x.label; sel.appendChild(o); });
    sel.addEventListener("change", function () {
      if (!sel.value) return;
      u.value = sel.value; p.value = PASSWORD;
      ["input", "change"].forEach(function (t) { u.dispatchEvent(new Event(t, { bubbles: true })); p.dispatchEvent(new Event(t, { bubbles: true })); });
      u.form.requestSubmit();
    });
    box.appendChild(label); box.appendChild(sel);
    u.form.insertBefore(box, u.form.firstChild);
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
