(function () {
  document.documentElement.classList.remove("no-js");

  // Nav border on scroll and mobile menu
  var nav = document.querySelector(".nav");
  var onScroll = function () { nav && nav.classList.toggle("scrolled", window.scrollY > 8); };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });
  var menuBtn = document.querySelector(".menu-btn");
  if (menuBtn) {
    menuBtn.addEventListener("click", function () {
      var open = nav.classList.toggle("open");
      menuBtn.setAttribute("aria-expanded", open ? "true" : "false");
    });
  }

  // Scroll reveal
  var els = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
      });
    }, { rootMargin: "0px 0px -10% 0px", threshold: 0.12 });
    els.forEach(function (el) { io.observe(el); });
  } else {
    els.forEach(function (el) { el.classList.add("in"); });
  }

  // Billing toggle on pricing
  var toggle = document.querySelector(".billing-toggle");
  if (toggle) {
    var pill = toggle.querySelector(".pill");
    var buttons = toggle.querySelectorAll("button");
    var setPill = function (btn) {
      pill.style.width = btn.offsetWidth + "px";
      pill.style.transform = "translateX(" + (btn.offsetLeft - 4) + "px)";
    };
    var select = function (btn) {
      buttons.forEach(function (b) { b.setAttribute("aria-pressed", b === btn ? "true" : "false"); });
      setPill(btn);
      var mode = btn.dataset.mode;
      document.querySelectorAll("[data-weekly][data-yearly]").forEach(function (el) {
        el.textContent = el.dataset[mode];
      });
    };
    buttons.forEach(function (b) { b.addEventListener("click", function () { select(b); }); });
    var start = toggle.querySelector('[aria-pressed="true"]') || buttons[0];
    select(start);
    window.addEventListener("resize", function () {
      setPill(toggle.querySelector('[aria-pressed="true"]'));
    });
  }

  // Netlify form submit without leaving the page
  var form = document.querySelector("form[data-netlify]");
  if (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var data = new URLSearchParams(new FormData(form)).toString();
      var btn = form.querySelector("button[type=submit]");
      btn.disabled = true; btn.textContent = "Sending…";
      fetch("/", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: data })
        .then(function (r) {
          if (!r.ok) throw new Error(r.status);
          form.style.display = "none";
          document.querySelector(".form-success").style.display = "block";
        })
        .catch(function () {
          btn.disabled = false; btn.textContent = "Send message";
          alert("Something went wrong. Please email us directly instead.");
        });
    });
  }

  var y = document.querySelector("[data-year]");
  if (y) y.textContent = new Date().getFullYear();
})();
