import "controllers";
import "channels";
import "@hotwired/turbo";
import "../js/hotkeys";
import "../js/mrujs";
import "../js/matomo";
import "../js/moment";

import bigDecimal from "js-big-decimal";
window.bigDecimal = bigDecimal;

import debounced from "debounced";
debounced.initialize({ input: { wait: 300 } });

import Trix from "trix";

document.addEventListener("trix-file-accept", (event) => {
  event.preventDefault();
});

// todo: install gem properly
console.log('init hotwire-debug');

var turboEvents = [
  "turbo:before-cache",
  "turbo:before-render",
  "turbo:before-visit",
  "turbo:visit",
  "turbo:click",
  "turbo:load",
  "turbo:render",
  "turbo:submit-end",
  "turbo:submit-start",
  "turbo:morph",
  "turbo:before-morph-element",
  "turbo:morph-element",
  "turbo:before-morph-attribute",
  "turbo:before-frame-render",
  "turbo:frame-render",
  "turbo:frame-load",
  "turbo:frame-missing",
  "turbo:before-stream-render",
  "turbo:before-fetch-request",
  "turbo:before-fetch-response",
  "turbo:before-prefetch",
  "turbo:fetch-request-error",
]

turboEvents.forEach(function(turboEvent) {
  document.addEventListener(turboEvent, function() {
    // if (showChanges()) {
      console.log("⚡️ " + turboEvent);
      // handleChange();
    // }
  });
})

function showChanges () {
  return true //document.documentElement.hasAttribute('data-hotwire-debug')
}

function handleChange() {
  document.querySelectorAll('turbo-frame:first-child').forEach(function(target) {
    target.setAttribute('data-turbo-frame-id', target.closest('turbo-frame').id);
  });
}

window.addEventListener("turbo:load", () => {
  let hotwireToggle = document.getElementById('hotwire-toggle');

  if (hotwireToggle == null) {
    hotwireToggle = document.createElement("div");
    hotwireToggle.innerHTML = '<svg viewBox="0 0 196 196" xmlns="http://www.w3.org/2000/svg"> <style> path { fill: #000000; } @media (prefers-color-scheme: dark) { path { fill: #ffffff; } } </style> <path d="m16.38 184.8 109.46-44.72-35.27-3.31 76.73-66.59-44.33-4.16 53.9-55.53-136.52 70.03 54.89 6.44-67.32 54.38 30.07 2.97z"/> </svg>';
    hotwireToggle.id = "hotwire-toggle";
    document.body.append(hotwireToggle);

    hotwireToggle.addEventListener("click", function() {
      document.documentElement.toggleAttribute("data-hotwire-debug");
      handleChange();
    });
  }
});
