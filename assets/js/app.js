// SWARM change: the fonts of the Swarm Style Guide v2 are bundled from npm and
// emitted into priv/static by webpack, so the browser never requests anything
// from a third party. Upstream linked fonts.googleapis.com from the layout.
import "@fontsource/sora/400.css"
import "@fontsource/sora/600.css"
import "@fontsource/sora/700.css"
import "@fontsource/manrope/400.css"
import "@fontsource/manrope/500.css"
import "@fontsource/manrope/600.css"
import "@fontsource/jetbrains-mono/400.css"
import "@fontsource/jetbrains-mono/500.css"

import "../css/app.scss"

import "phoenix_html"
import 'alpinejs'
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

// SWARM change: the light/dark toggle and its localStorage entry are gone.
// The design system is one dark theme, and the explorer now stores nothing in
// the browser beyond the session cookie Phoenix needs.
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken } })
liveSocket.connect()
window.liveSocket = liveSocket

import "../css/explorer.scss"

// Native links/forms stay usable without JavaScript.
const route = window.location.pathname
for (const link of document.querySelectorAll('.sw-nav a')) {
  if (link.getAttribute('href') === route) link.setAttribute('aria-current', 'page')
}
document.addEventListener('keydown', (event) => {
  const editing = event.target.closest('input, textarea, select, [contenteditable]')
  if (event.key === '/' && !editing && !event.ctrlKey && !event.metaKey && !event.altKey) {
    const input = document.getElementById('hero-search') || document.getElementById('search')
    if (input) { event.preventDefault(); input.focus() }
  }
})
for (const dd of document.querySelectorAll('dd')) {
  const value = dd.textContent.trim()
  if (/^[a-fA-F0-9]{64}$/.test(value) && navigator.clipboard) {
    const button = document.createElement('button')
    button.type = 'button'; button.className = 'sw-copy'; button.textContent = 'Copy'
    button.setAttribute('aria-label', 'Copy ' + (dd.previousElementSibling?.textContent.trim() || 'hash'))
    button.addEventListener('click', () => {
      navigator.clipboard.writeText(value).then(() => {
        button.textContent = 'Copied'
      }).catch(() => { button.textContent = 'Select to copy' }).finally(() => {
        setTimeout(() => { button.textContent = 'Copy' }, 2200)
      })
    })
    dd.append(button)
  }
}
const connectionNote = document.createElement('div')
connectionNote.className = 'sw-connection-note'; connectionNote.setAttribute('role', 'status')
connectionNote.textContent = 'Live updates interrupted. Displayed readings may be out of date.'
document.body.append(connectionNote)
function updateConnection() {
  const disconnected = !navigator.onLine || Boolean(document.querySelector('.phx-disconnected, .phx-error'))
  document.body.classList.toggle('sw-offline', disconnected)
}
window.addEventListener('online', updateConnection)
window.addEventListener('offline', updateConnection)
new MutationObserver(updateConnection).observe(document.getElementById('explorer-content') || document.body, {attributes:true, subtree:true, attributeFilter:['class']})
updateConnection()
